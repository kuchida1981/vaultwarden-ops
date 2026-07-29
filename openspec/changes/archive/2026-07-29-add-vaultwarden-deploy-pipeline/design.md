## Context

`terraform-apply.yml`は`terraform/main/**`のpathフィルタで発火するため、`vaultwarden/**`(docker-compose.yml等)の変更では起動しない。VM上のstartup-scriptは起動(boot/reboot)時にしか`git pull`・`docker compose up -d`を実行しないため、Dependabotが作成したvaultwardenイメージバージョンPR(#46)をマージしても、実VMには一切反映されないというギャップが判明した。

姉妹プロジェクトのn8n-opsは`add-n8n-deploy-pipeline`changeで全く同じ構造のギャップに対処済みで、専用デプロイワークフロー・GCP IAP tunnel経由のVMアクセス・既存`production` Environmentによる承認ゲートという設計が実運用されている。本designはこのパターンをvaultwarden-opsに移植する前提で書く。

vaultwarden-opsとn8n-opsは同一GCPプロジェクト・同一Tailscaleアカウントを共有しており、`tailscale_acl`リソースは両リポジトリのstateから触られる共有リソースであることがIssue #12として既知(未解決)。この結合を悪化させない設計であることが必須条件。

## Goals / Non-Goals

**Goals:**
- Dependabotが作成したvaultwardenイメージバージョンPRをマージした後、明示的な承認操作を経て安全に本番VMへ反映できるパイプラインを用意する
- 反映作業がGitHub Actions上に実行履歴として残り、可視化される
- 既存のTailscale ACL(vaultwarden-ops/n8n-ops共有state)には一切変更を加えない

**Non-Goals:**
- リアルタイム/自動即時反映(承認を挟まない自動反映は目指さない)
- Tailscale ACLの2リポジトリ間所有権問題の解決(Issue #12で別途追跡)
- 既存の`default-allow-ssh`レガシーファイアウォールルールの是正(スコープ外、n8n-opsと同じ扱い)
- caddyイメージなど、docker-compose.yml内のvaultwarden以外のイメージ更新の扱いを区別すること(image:行の差分検知という仕組み自体はn8n-opsのtraefik同様、サービスを問わず同一の仕組みで機能する)

## Decisions

### 1. `vaultwarden-deploy.yml`という専用ワークフローを新設し、`terraform-apply.yml`とは独立させる

`terraform-apply.yml`のpathフィルタを`vaultwarden/**`まで広げる案も検討したが、Terraformを一切実行しない`docker compose pull/up`のためだけに`terraform apply`ジョブを流用するのは意味的に誤りであり、n8n-opsも同じ理由で専用ワークフローを選んでいる。既存の`production` Environmentは流用する(新しいEnvironmentは作らない)。個人プロジェクトの運用規模ではインフラ変更承認とアプリバージョン反映承認を分離するメリットが薄いとユーザーとの探索で合意済み。

### 2. VMへの接続はGCP IAP tunnel経由の`gcloud compute ssh`を使い、Tailscaleには一切触れない

Tailscale ACLはvaultwarden-ops/n8n-ops双方のstateから触られる共有リソース(Issue #12)であり、CI用に新しいノード/ACLルールを追加するとこの結合をさらに深める。GCP側で完結するIAP tunnelであれば、vaultwarden-opsのTerraform stateだけで完結し、Tailscale側に一切変更が要らない。n8n-opsで同じ理由により採用され、実運用済みの経路でもある。

代替案として「CIランナーをephemeral Tailscaleノードとしてtailnetに参加させ`tailscale ssh`を使う」ことも検討したが、ACLの`ssh`ルールに新しいsrc(CIノード用のtag)を追加する必要があり、Issue #12の課題を拡大させるため不採用(n8n-opsのdesign.mdで下された判断と同一)。

**トレードオフとして明記する点**: vaultwarden-opsのREADMEには「SSHはtailscale sshのみ(公開ファイアウォールで22番は非公開)」という運用開始時からのセキュリティ上の不変条件が明記されている。本changeはこの不変条件を「Tailscale + IAP tunnel(CI用SA限定)」へ変更する。vaultwardenは実際のパスワード保管庫データを扱うため、n8nより一段重い判断だが、以下の理由でリスクは許容範囲と判断した(ユーザーとの探索で合意済み):
- IAP tunnelを実際に確立できるのは、GCP IAM上`roles/iap.tunnelResourceAccessor`と`roles/compute.osAdminLogin`を両方持つ`terraform-ci`サービスアカウントの認証情報を保持する主体のみ(=GitHub Actionsの`production` Environment、WIF経由でのみ発行される一時credential)
- ファイアウォールもIAPの専用ソースレンジ(`35.235.240.0/20`)のみに限定し、他の送信元からのtcp:22到達は変わらず不可能なまま
- 承認ゲートを経ない限りこの経路は使われない(デプロイジョブ自体が`production` Environmentの承認待ちで一時停止する)

### 3. `terraform_ci`への`osAdminLogin`付与(`osLogin`ではなく)

`/opt/vaultwarden/app`・`/opt/vaultwarden/.env`(mode 600)・dockerソケットがすべてroot所有であり、デプロイコマンド(`docker compose pull/up`)の実行にsudo権限が必須なため、sudoersグループ付与を伴う`osAdminLogin`が必要(n8n-opsと同一の理由)。

### 4. デプロイ内容はVM再起動を伴わない`git pull --ff-only && docker compose pull && docker compose up -d`のみ

`gcloud compute ssh`経由で実行し、VM自体のreboot/resetは行わない。`docker compose up -d`は変更のあったサービス(通常はvaultwardenコンテナのみ)だけを再作成するため、caddyの`caddy_data`/`caddy_config`(named volume、証明書等)は触れられない。startup-scriptの`git pull`と異なり`|| echo WARNING`のフォールバックは行わない: デプロイ処理は「反映されたかどうか」が明確であるべきで、承認を経た明示的操作の結果を黙って握りつぶすべきではないため(n8n-opsと同一の理由)。

なお、このデプロイ経路は`/opt/vaultwarden/.env`を再生成しない(ADMIN_TOKENのハッシュ再生成はstartup-script起動時のみ)。既存の`.env`をそのまま使い回すため、SMTP/ADMIN_TOKEN等の設定に影響はない。

### 5. `vaultwarden-last-deploy`タグで承認済みデプロイの基準点を管理する

rejectされたrunがコミットとしてmainに残っても、次回runのimage差分表示が正しく機能するよう、デプロイ成功時に`git tag -f vaultwarden-last-deploy && git push -f origin vaultwarden-last-deploy`を実行する。差分計算はこのタグ(無ければ`HEAD^`)を基準にする。n8n-opsの`n8n-last-deploy`と同一の仕組み。

## Risks / Trade-offs

- [Tailscale専用というREADME記載の不変条件が崩れる] → 上記Decision 2のトレードオフ欄参照。CI用SA限定・承認ゲート必須という条件でリスクを許容
- [IAP tunnel確立の失敗(ネットワーク一時障害等)] → ワークフローはジョブ失敗として明示的にActions上に残り、再実行(re-run)で対応可能。無人リトライは行わない
- [`git pull --ff-only`がfast-forwardできない状態] → 失敗時はコマンド全体が非ゼロ終了し、ジョブが失敗として可視化される
- [OS Login有効化によるVMへのSSH経路の意図しない拡大] → `roles/compute.osAdminLogin`は`terraform-ci`のみに付与。ファイアウォールもIAPの専用レンジのみに限定するため、実質的にIAP経由・CI用SAの認証情報を持つ主体のみがSSH可能

## Migration Plan

1. `terraform/bootstrap/main.tf`にIAM変更(`iap.tunnelResourceAccessor`・`compute.osAdminLogin`・`iap.googleapis.com`)を加え、**ユーザーが手動で**`terraform apply`(bootstrap)を実行
2. `terraform/main/compute.tf`(OS Login metadata)・`terraform/main/network.tf`(IAPファイアウォール)をPR経由でmainに反映、既存の`terraform-apply.yml`経由(`production` Environment承認込み)でVMへ反映
3. `.github/workflows/vaultwarden-deploy.yml`をPR経由でmainに反映
4. README/README.jaにbootstrap手動apply手順とデプロイフローの説明を追記
5. 次にDependabotがvaultwardenのバージョンPRを作成した際(あるいはPR #46をこの経路が整った後にマージした際)に、マージ→Environment承認→実際のデプロイ、という一連の流れを**ユーザーが実地で確認する**

ロールバックは、`vaultwarden-deploy.yml`・IAM追加・ファイアウォールルールをそれぞれ独立にrevert可能。VM上のアプリケーション状態(データディスク・SQLite DB)には触れない変更のため、ロールバックによるデータ影響はない。

## Open Questions

(なし。ユーザーとの探索で主要な論点は決着済み)
