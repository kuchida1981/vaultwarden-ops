## Context

`terraform/main/secrets.tf`は`random_password`で生成した48桁の平文トークンをそのままGoogle Secret Managerに保存しており、コメントで「Vaultwardenはargon2 PHC文字列も受け付けるが、シンプルさのため平文を使っている。ハードニングしたければ検討を」と明記されている。`/admin`アクセス時にVaultwardenがこの平文利用を警告するようになったため、この先送りにしていた判断を今回解消する。

現状の配線(`terraform/main/templates/startup-script.sh.tftpl`):
1. `fetch_secret()`でSecret Managerから平文`ADMIN_TOKEN`を取得
2. `/opt/vaultwarden/.env`に平文のまま書き込み(`chmod 600`)
3. `docker compose --env-file /opt/vaultwarden/.env up -d`が`vaultwarden/docker-compose.yml`の`ADMIN_TOKEN: ${ADMIN_TOKEN}`を通じてコンテナに渡す

`/admin`自体はすでに`route-admin-via-tailscale-serve`によりtailnet経由でしか到達できない(多層防御の1層目)。今回の変更は、その防御を突破された場合や`.env`/Secret Manager/state経由でトークンが単体で漏れた場合に、即座の不正ログインを防ぐ2層目の追加。

## Goals / Non-Goals

**Goals:**
- コンテナに渡す`ADMIN_TOKEN`をArgon2id PHC文字列にし、Vaultwardenの警告を解消する
- 既存の「1 secret = 1 value」パターン(design.md各所で踏襲されているSecret Manager運用)を崩さない
- 運用者が`/admin`にログインする手順(Secret Managerから値を取得して入力)を変えない

**Non-Goals:**
- Secret Manager側に保存する値そのものをハッシュ化すること(→運用者がログインに使う平文の入手経路が別途必要になり、secret構成が複雑化するため見送り。詳細はDecisionsを参照)
- ADMIN_TOKEN自体のローテーション運用の変更
- `/admin`への到達経路(tailscale serve)自体の見直し

## Decisions

### 1. ハッシュ化はTerraform側ではなくVM起動時(boot-time)に行う

**採用**: `startup-script.sh.tftpl`内で、Secret Managerから取得した平文をVM上でその場でargon2ハッシュ化し、`.env`にはハッシュ済みの値だけを書く。Secret Manager自体は平文のまま変更しない。

**却下した代替案**: Terraform apply時(またはCI)にハッシュ化し、Secret Managerにはハッシュ済みの値だけを保存する。
- 却下理由: この場合、運用者が`/admin`にログインするための平文をどこかに残す必要があり、`vaultwarden-admin-token`(ハッシュ)とは別に`vaultwarden-admin-token-plaintext`のような2本目のsecretを作ることになる。既存の「1 secret = 1 value」という前提(SMTP認証情報などで踏襲済み)から外れ、secrets.tf/iam.tfの構成が煩雑になる。boot-time案なら平文はSecret Manager 1本のままで、ハッシュ化は完全にVM内で完結する使い捨て処理として扱える。

### 2. ハッシュ化ツールは`vaultwarden hash`ではなく`argon2` CLIパッケージを使う

**採用**: `apt-get install`に`argon2`(Debianパッケージ)を追加し、`echo -n "$ADMIN_TOKEN" | argon2 "$SALT" -e -id -m 16 -t 3 -p 4`のような非対話コマンドでPHC文字列を生成する。

**却下した代替案**: `docker run --rm -i vaultwarden/server:1.36.0 /vaultwarden hash`
- 却下理由: `vaultwarden hash`はパスワード入力・確認を対話プロンプト(rpassword経由)で要求する設計で、非対話実行(パイプ経由の標準入力)を前提にしていない。無理に動かそうとすると`vaultwarden`イメージの内部実装の非公式な挙動に依存することになり、`startup-script.sh.tftpl`が冪等・非対話であるという既存の設計原則(他のfetch_secret呼び出しと同様)に合わない。

### 3. Argon2パラメータはVaultwarden公式の"bitwardenプリセット"に揃える

`m=65540`(約64MiB), `t=3`, `p=4`を使う。これは`vaultwarden hash`が生成するデフォルト値と同じで、Vaultwarden側で追加のドキュメントや検証なしに「公式推奨と同等」と判断できる。e2-micro(共有vCPU, 1GBメモリ)でも、起動時に1回・ログイン試行ごとに1回発生するだけの処理であり、64MiBのメモリコストは許容範囲。

### 4. saltは起動のたびにランダム生成する(固定・永続化しない)

`openssl rand -hex 16`などでVMブート毎に新しいsaltを生成し、ハッシュ文字列自体も毎回変わる。Vaultwardenはユーザーが入力した平文をこのPHC文字列に対して都度検証するだけなので、ハッシュ文字列が再起動のたびに変わっても機能的な問題はない。

**トレードオフ**: `.env`の内容が再起動のたびに変化するため、`docker compose up -d`が(値の変化を検知して)vaultwardenコンテナを再作成する可能性がある。数秒のコンテナ再作成程度で実害はないため許容する。

## Risks / Trade-offs

- [Risk] `docker-compose.yml`の`ADMIN_TOKEN: ${ADMIN_TOKEN}`という変数参照とdocker composeの`$`展開処理の組み合わせで、PHC文字列内の複数の`$`(`$argon2id$v=19$m=...$salt$hash`)が壊れる可能性がある → **実機(ローカルdocker compose)で再現・確認済み**: `--env-file`読み込み時にcomposeが値側の`$`も展開してしまい、無エスケープだと`ADMIN_TOKEN`が`=19=65536,t=3,p=4`のように破壊される。Mitigation: `.env`に書き込む直前に`sed 's/\$/\$\$/g'`で`$`を`$$`に二重化する(startup-script.sh.tftplに実装済み、`docker compose run`でコンテナ内の値が元のPHC文字列と一致することを確認済み)。`${VAR//pattern/repl}`形式のbash brace展開は`.tftpl`がTerraformの`${...}`補間構文と衝突するため使えない。
- [Risk] saltを毎回使い捨てにする設計のため、`.env`の差分だけを見て「意図しない変更が起きていないか」を監視する運用がしづらくなる(ハッシュ値は毎回変わるのが正常) → Mitigation: 特に対策は不要(元々`.env`はgit管理外でチェックしていない)だが、tasks.mdの動作確認手順にその旨を記録しておく。
- [Risk] `argon2`パッケージのインストールが何らかの理由で失敗すると、`.env`生成そのものが止まり得る(`set -euxo pipefail`のため) → Mitigation: 他の`apt-get install`と同じ扱いとし、特別なフォールバックは設けない(他の依存パッケージ取得失敗時と同様、起動失敗として検知・対応する)。

## Migration Plan

1. `terraform/main/templates/startup-script.sh.tftpl`と関連ファイルを変更し、PRを作成・`terraform plan`で差分確認(既存リソースの再作成が発生しないこと=`compute.tf`のmetadataのみが変わることを確認)
2. マージ後`terraform apply`
3. 稼働中のVMに対しては再起動ではなく`gcloud compute instances add-metadata`反映後、`google_metadata_script_runner startup`でstartup-scriptを再実行する(既存の`add-smtp-support`と同じ手順)
4. `/admin`にアクセスし、警告が消えていること・平文トークンで実際にログインできることを確認する

**ロールバック**: `startup-script.sh.tftpl`の変更前バージョンに戻して同じ手順(apply → script再実行)を踏めば、コンテナが平文ADMIN_TOKENで再起動され元の状態に戻る。Secret Manager側は変更していないため、ロールバックはVM側の設定のみで完結する。

## Open Questions

- (なし。実装時に`$`エスケープの実機検証で問題が出た場合のみ、docker-compose.yml側の対応を追加検討する)
