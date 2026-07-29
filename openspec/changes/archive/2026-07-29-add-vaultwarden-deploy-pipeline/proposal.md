## Why

`terraform-apply.yml`は`terraform/main/**`のpathフィルタでのみ起動するため、`vaultwarden/**`配下(docker-compose.ymlのイメージタグ等)の変更をmainにマージしても本番VMには一切反映されない。実際、Dependabotが作成したvaultwardenイメージバージョンアップPR(#46)を調査した際、マージ・ワークフロー承認・terraform applyという想定していた経路そのものが存在しないことが判明した。VM上のstartup-scriptは起動(boot/reboot)時にしか実行されず、`git pull`や`docker compose up -d`を自動で行う仕組みが無いため、現状は運用者が都度手動でVMにSSHし反映する以外に手段がない。運用開始後初めてのVaultwardenバージョンアップ(1.36.0→1.37.0)を機に、承認ゲート付きの明示的なデプロイパイプラインを整備する。

姉妹プロジェクトのn8n-opsは同種のギャップに既に対処済みで(`add-n8n-deploy-pipeline`change)、専用デプロイワークフロー・GCP IAP tunnel経由のVMアクセス・承認ゲートという設計が実運用されている。本changeはこの実証済みパターンをvaultwarden-opsに移植する。

## What Changes

- `.github/workflows/vaultwarden-deploy.yml`を新設。`push: main`かつ`paths: ["vaultwarden/**"]`で起動し、`summary`(image差分をjob summaryへ出力)→`deploy`(`production` Environmentの人間承認を経てVMへ反映)の2ジョブ構成とする。VM再起動は行わず、`docker compose pull && up -d`で変更のあるコンテナのみ再作成する。
- デプロイ成功後、`vaultwarden-last-deploy`タグをforce-pushし、次回実行時の差分基準点とする。
- **BREAKING(セキュリティ上の前提変更)**: VMへのSSH経路として、既存の「Tailscale tailnet経由のみ」という不変条件に加えて、GCP IAP tunnel(`gcloud compute ssh --tunnel-through-iap`)経由の新しいアクセス経路をCI用サービスアカウント限定で追加する。これに伴い以下のインフラ変更が発生する:
  - `terraform/bootstrap`: CI用SA(`terraform-ci`)に`roles/iap.tunnelResourceAccessor`・`roles/compute.osAdminLogin`を追加、`iap.googleapis.com`を有効化(**ユーザーによる手動apply必須**)
  - `terraform/main/compute.tf`: VM metadataに`enable-oslogin = "TRUE"`を追加
  - `terraform/main/network.tf`: IAPの専用ソースレンジ(`35.235.240.0/20`)からtcp:22を許可する新規ファイアウォールルール(`vaultwarden-allow-iap-ssh`)を追加、`target_tags = ["vaultwarden-server"]`にのみ適用
- `.github/dependabot.yml`・イメージ参照形式は変更不要(既にDocker Hub暗黙参照`vaultwarden/server:x.y.z`のため)。

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `deployment-pipeline`: `vaultwarden/**`配下の変更に対する承認ゲート付きデプロイパイプライン(新規ワークフロー・IAP tunnel経由のVMアクセス・承認前のバージョン差分可視化)を追加する要件を追加する

## Impact

- 新規ファイル: `.github/workflows/vaultwarden-deploy.yml`
- 変更ファイル: `terraform/bootstrap/main.tf`(IAM追加、手動apply対象)、`terraform/main/compute.tf`(OS Login有効化)、`terraform/main/network.tf`(IAPファイアウォール)、`README.md`/`README.ja.md`(bootstrap手動apply手順・デプロイフローの追記)
- セキュリティ影響: VMへのSSH到達経路が「Tailscaleのみ」から「Tailscale + IAP tunnel(CI用SA限定)」に拡大する。影響範囲はCI用サービスアカウントの認証情報を保持する主体(GitHub Actionsのproduction Environment)に限定される
- 運用影響: `terraform/bootstrap`の手動apply、GitHub Environmentでの承認操作という新たな運用ステップが発生する
