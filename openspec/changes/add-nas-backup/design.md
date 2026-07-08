## Context

VMのVaultwardenデータ(`/opt/vaultwarden/data`)は、`db.sqlite3`(WALモード。`-wal`/`-shm`が付随)、`attachments/`、`sends/`、署名鍵`rsa_key.pem`/`rsa_key.pub.pem`、`config.json`、そして再生成可能な`icon_cache/`から構成される。現状これらは専用永続ディスク1本にしか存在せず、ディスク障害・誤destroy等が復旧不能な単一障害点になっている。

自宅にSynology NAS(Btrfsファイルシステム)があり、Tailscale tailnetに参加済みで、VMからMagicDNSホスト名(`synology-nas`)で疎通確認済み(`tailscale ping`で到達、ただし現状はDERPリレー経由で直接接続は未確立)。

機密情報の扱いは確立済みのパターンがある: `ADMIN_TOKEN`・Tailscale認証キー・SMTP認証情報はGoogle Secret Managerに保管し、VM実行時サービスアカウントに該当シークレットのみの`secretAccessor`権限を与え、startup-scriptがメタデータサーバー経由の一時アクセストークンでSecret Manager APIから取得する(`terraform/main/secrets.tf`, `iam.tf`, `templates/startup-script.sh.tftpl`)。定期処理はcronではなくsystemdの仕組み(`unattended-upgrades`)に統一されている。

## Goals / Non-Goals

**Goals:**
- VM上のVaultwardenデータを毎日自動的に自宅NASへバックアップする
- バックアップ中もVaultwardenを停止せず、DBファイルは破損のない一貫性のあるスナップショットとして転送する
- NAS側の設定・運用負荷を最小化する(継続的なスクリプト保守や鍵管理を持ち込まない)
- 既存のSecret Manager最小権限パターン、systemdベースの定期実行パターンをそのまま踏襲する
- 実際に1回リストアを行い、手順として再現可能な形にドキュメント化する

**Non-Goals:**
- バックアップ失敗の監視・アラート(ロードマップ上「稼働監視」は別スコープ。本changeではsystemdのjournalへのログ出力に留める)
- 保管庫の復旧手段(Organization Account Recovery / Emergency Access)。これはゼロ知識暗号化に起因する別問題であり、バックアップでは解決しない
- Tailscaleの直接接続(DERPリレー回避)のトラブルシューティング。転送は機能するため、速度面の懸念があっても本changeのスコープには含めない

## Decisions

**1. 転送方式はrsyncデーモン(`rsync://`)。SSH鍵(`tailscale ssh`含む)は使わない**

代替案として(a) SSH鍵認証によるrsync over SSH、(b) restic/borgのようなdedup・暗号化・世代管理機能を持つ専用バックアップツール、(c) NFS/SMBマウント+単純コピー、を検討した。

- (a)は実績があるが、SSH鍵の発行・Secret Managerへの格納・失効という運用が新たに乗る。またNAS側で`tailscale ssh`のサーバ機能(PTYをroot権限で代行する必要がある)を使う場合、Synologyのコミュニティパッケージのサンドボックス内で確実に動作するか未検証というリスクがある
- (b)は世代管理機能が魅力だが、新しいバイナリの導入・リポジトリ初期化・暗号化パスワードという新しいシークレットが増え、シンプルな日次バックアップには過剰
- (c)はマウントの生存確認・タイムアウト処理が絡み、cron/timer駆動のジョブとしては壊れ方が予測しづらい(ネットワーク瞬断でハングする等)

選定した(rsyncデーモン)は、通信が元々Tailscale WireGuardトンネル内に閉じているため、rsyncプロトコル自体が暗号化を持たないという弱点が実害にならない。NAS側の設定はSynologyのコントロールパネルで「Rsyncサーバー」を有効化しアカウントを1つ作るだけで完結し、SSH鍵のライフサイクル管理そのものが不要になる。

**2. Push型(VM主導)。NAS側からのPullは行わない**

このリポジトリは「起動時に必要な設定をすべてVM自身が完結させる」という設計思想(冪等なstartup-script)を徹底しており、バックアップもその流儀を延長する。NAS側に置くのは「rsyncdの設定」という受動的な待ち受けのみで、能動的なロジック(いつ・何を取りに行くか)は一切持たせない。

**3. スケジューリングはsystemd timer + service。cronは使わない**

このVMは`unattended-upgrades`をsystemdの仕組みで有効化しており、定期処理はsystemdに統一する。`backup.timer`(`OnCalendar=*-*-* 03:00:00`、`RandomizedDelaySec`で多少の分散を持たせる)が`backup.service`(`Type=oneshot`)を起動する。

**4. SQLiteの一貫性は`sqlite3 .backup`によるオンラインバックアップで確保する。サービス停止は行わない**

稼働中の`db.sqlite3`・`-wal`・`-shm`をそのままrsync対象にすると、WALモードでの書き込み最中のファイルを掴み、破損したスナップショットを転送するリスクがある。`sqlite3 db.sqlite3 ".backup 'staging/db.sqlite3'"`はSQLiteのオンラインバックアップAPIを使い、稼働中の書き込みと衝突しない一貫性のあるコピーを1コマンドで作れる。これはsystemdサービスに1ステップ追加する程度の複雑さであり、Vaultwardenを毎日停止する運用より優れる。

**5. バックアップ対象は`/opt/vaultwarden/data`ディレクトリ全体(`icon_cache/`・Vaultwarden自身が作る手動バックアップファイルは除外)**

当初「`db.sqlite3`・`attachments/`・`sends/`」という書き方で考えていたが、`rsa_key.pem`/`rsa_key.pub.pem`(署名鍵)と`config.json`(管理パネル設定)も復旧に必須であり、見落とすと復元後にVaultwardenが正しく起動しない、または既存セッション・組織関連の暗号操作に支障が出るおそれがある。`icon_cache/`はサイトアイコンのキャッシュのみで消えても自動再生成されるため、転送量削減のため除外する。

実地確認で、Vaultwardenの管理パネル「データベースをバックアップ」ボタンが`db_<timestamp>.sqlite3`という名前のファイルをデータディレクトリ直下に作ることが判明した。これは`db.sqlite3`という完全一致名しか除外していなかった当初の除外パターンをすり抜けて転送されてしまう。この手動バックアップ機構と、本changeが提供する自動バックアップは役割が重複するため、`db_*.sqlite3`パターンで除外する。

処理フローは以下の2段階:
```
1. sqlite3 db.sqlite3 ".backup 'staging/db.sqlite3'"     # 一貫性スナップショット作成
2. rsync -a --delete \
     --exclude 'db.sqlite3*' --exclude 'db_*.sqlite3' \
     --exclude 'icon_cache/' \
     /opt/vaultwarden/data/ staging/                       # DB以外をステージングへミラー
3. RSYNC_PASSWORD=$(cat rsync-backup.secret) \
     rsync -a --no-owner --no-group --delete \
       --exclude '#recycle' --exclude '@eaDir' --exclude 'lost+found' \
       staging/ rsync://<user>@<nas-host>/<module>/        # NASへpush
```

手順3は初回の実地検証で`chgrp: Operation not permitted`(NASのrsyncdアカウントにchgrp権限がない)と`#recycle`/`lost+found`の削除失敗(Synology管理下の特殊ディレクトリで、バックアップアカウントには削除権限がない)により失敗することが判明した。`--no-owner --no-group`でowner/group保持を諦め(VMとNASは別のUID/GID名前空間なので保持する意味自体がない)、Synology管理下のディレクトリを`--exclude`で`--delete`の対象から外すことで解消した。

**6. 世代管理はNAS側のBtrfsスナップショットへ完全委譲。VM側はハードリンク世代等を持たない**

代替案として、VM側で`rsync --link-dest`によるハードリンク世代管理、あるいはresticの`forget`/`prune`によるretentionも検討したが、いずれもVM側に「世代を判断し古いものを消す」ロジックを持ち込むことになる。NASのBtrfsスナップショットはファイルシステムレベルでこれを提供しており、VM側は常に「最新状態への上書き同期」だけを行えばよい。設定はNAS側のGUI(スナップショットスケジュール)のみで完結し、コード変更なしに後から保持期間・世代数を調整できる。初期値としてGFS方式(daily×7, weekly×4, monthly×3)を提案する。

**7. 接続先(NASホスト名・モジュール名・rsyncdユーザー名)は非機密のデフォルト値付き変数、パスワードのみsensitive変数**

`smtp_host`/`smtp_from`等の既存パターンと同様、機密性のない識別子(NASのMagicDNSホスト名`synology-nas`、rsyncモジュール名、rsyncdユーザー名)はデフォルト値付きの非sensitive変数として`variables.tf`に定義し、公開リポジトリにコミットして問題ない情報として扱う。rsyncdパスワードのみ、`ADMIN_TOKEN`と同水準の秘匿性としてSecret Manager経由で管理する。

## Risks / Trade-offs

- [Tailscaleの直接接続が未確立でDERPリレー経由になっている] → 日次の差分転送であれば実害は小さいと想定。初回フルバックアップは相対的に時間がかかる可能性があるが、機能上のブロッカーではないため許容する。将来Tailscaleが自動的に直接接続へ再ネゴシエーションすれば自動的に改善する
- [rsyncデーモンの認証はパスワードのみで、SSH鍵より単純] → Tailscaleトンネル内に閉じた通信であるため、パスワードが平文でネットワーク上を流れても第三者に到達しない。Secret Manager経由で管理する限り、この単純さは許容可能なトレードオフとする
- [NAS側の設定(Rsyncサーバー有効化、スナップショットスケジュール)はコード管理外でドリフト・消失しうる] → README.mdに手動セットアップ手順を具体的に記載し、再現可能にする
- [バックアップ失敗が検知されない] → 監視は明示的にNon-Goal。systemdのjournalにログは残るため、手動確認は可能。将来の稼働監視の変更で拾えるよう、`backup.service`のexit codeが失敗時に非ゼロになることだけは保証する
- [復元時、rsync/cpの実行ユーザーによってはファイル所有者がroot等になり、Vaultwardenコンテナから読めなくなる] → リストア手順に権限確認ステップを明記する(下記Migration Plan参照)

## Migration Plan

1. (ユーザー作業・NAS側) コントロールパネル→ファイルサービスで「Rsyncサーバー」を有効化する
2. (ユーザー作業・NAS側) バックアップ受け入れ用の共有フォルダを新規作成する(Btrfs上であることを確認)
3. (ユーザー作業・NAS側) 専用アカウントを作成し、その共有フォルダへの読み書き権限のみを付与する。発行したパスワードを控える
4. (ユーザー作業・NAS側) 対象共有フォルダにスナップショットスケジュールを設定する(daily×7, weekly×4, monthly×3を初期値として提案)
5. (ユーザー作業) 手順3のパスワードをGitHub Actions Secretsに登録する
6. `terraform/main`への変更をPRで作成し、`terraform plan`で差分を確認する(新規リソースのみで既存リソースの破壊的変更がないこと)
7. `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する(新しいSecret Manager secret、IAM権限、startup-script更新が反映される)
8. VM再起動(または`google_metadata_script_runner startup`での再実行)で`backup.timer`が有効化される
9. `systemctl start backup.service`で初回バックアップを手動トリガーし、NAS側に想定通りのファイルが転送されることを確認する
10. リストア手順を1回実地検証する(下記手順)
11. ロールバック: `systemctl disable --now backup.timer`で新規バックアップの実行を止める。NAS上の既存バックアップ・スナップショットはそのまま残るため、ロールバックによるデータ損失は発生しない

### リストア手順(実地検証してREADMEに転記する)

1. NASのBtrfsスナップショット一覧(DSMスナップショットマネージャ、または共有フォルダの`@GMT-<timestamp>`隠しディレクトリ)から復元したい世代を選ぶ
2. VM上でVaultwardenを停止する: `docker compose -f /opt/vaultwarden/app/vaultwarden/docker-compose.yml --env-file /opt/vaultwarden/.env stop vaultwarden`(リストアは非常時作業のため、通常運用時と異なりここでは無停止化にこだわらない)
3. 現行データを退避する: `mv /opt/vaultwarden/data /opt/vaultwarden/data.bak.$(date +%s)`(誤操作時の戻し先を確保)
4. 選んだNASスナップショット世代から`/opt/vaultwarden/data`へrsyncまたはコピーする。この際、バックアップ時に`sqlite3 .backup`で作成した一貫性コピーを本来のファイル名`db.sqlite3`として配置し、古い`-wal`/`-shm`断片は復元先に含めない(Vaultwarden起動時に新規生成させる)
5. 復元後のファイル所有者・パーミッションがコンテナ実行ユーザーと一致することを確認する(rootが所有していると読み取れない事故になりうる)
6. `docker compose up -d`でVaultwardenを起動し、ログイン成功・既存添付ファイルが開けること・`/admin`のユーザー一覧が正しいことを確認する
7. 問題なければ手順3で退避した`data.bak.*`を削除する

## Open Questions

- NAS側のRsyncサーバーのモジュール名・共有フォルダ名・アカウント名の具体的な命名は、ユーザーがNAS設定時に決めて良い(Terraform変数のデフォルト値は暫定の提案値として置く)
- スナップショットの保持ポリシー(daily×7, weekly×4, monthly×3)はあくまで初期値であり、運用してみて調整する前提(NAS側GUI設定のみで変更可能、コード変更不要)
