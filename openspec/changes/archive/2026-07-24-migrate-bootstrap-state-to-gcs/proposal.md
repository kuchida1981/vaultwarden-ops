## Why

`terraform/bootstrap`は現在ローカルstate管理であり、マシンを跨ぐとstateが見えなくなる(gitで管理されないため)。実際に、Dependabotの`hashicorp/google` providerバージョンアップPRの内容を別マシンから`terraform plan`で確認しようとした際、そのマシンにローカルの`terraform.tfstate`が存在せず「17 to add」という誤った差分が表示される事故が発生した(幸い別のマシンにstateが残っていたため事なきを得た)。issue #28の対応として、bootstrap自身が作成するtfstateバケット(`kuchida-devel-vaultwarden-tfstate`)に`bootstrap`prefixを切り、GCSリモートバックエンドへ移行する。

## What Changes

- `terraform/bootstrap/versions.tf`に`backend "gcs" { prefix = "bootstrap" }`を常設する(bucket名は`terraform/main`と同じパターンで`-backend-config`により`terraform init`時に注入する部分設定とする)。新規バケットは作らず、bootstrap自身が作成する既存のtfstateバケット(`kuchida-devel-vaultwarden-tfstate`)を再利用する。`terraform/main`は既に`prefix = "vaultwarden/main"`を使用しているため、prefix分離により衝突しない。
- 既存環境(kuchida-devel、稼働中)のローカルstateを`terraform init -migrate-state`でGCSへ実際に移行する。**この操作はユーザーが手動で実行する**(認証情報・破壊的操作を伴うため)。
- README.md/README.ja.mdに、次の2パターンの運用手順を追記する:
  - 既存環境: リモートバックエンドで`-backend-config`を指定して`terraform init`する通常手順
  - 真にゼロから新規GCPプロジェクトでbootstrapを立ち上げる場合: バケットがまだ存在しないため、初回のみ一時的にlocal backendで`apply`し、バケット作成後に`backend "gcs"`を有効化して`-migrate-state`する、という一度きりの手順
- **BREAKING**: `terraform/bootstrap`を新規環境でゼロから使う際の初回手順が変わる(常設の`backend "gcs"`ブロックがあるため、最初の`terraform init`はbucketが存在せず失敗する。一時的な回避手順が必要になる)。既存環境(kuchida-devel)の運用フロー自体への影響はない。

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `deployment-pipeline`: 既存の要件「リモートstateはGCSに保管しリポジトリにコミットしない」の対象を`terraform/main`だけでなく`terraform/bootstrap`にも拡張する。また「bootstrapリソースの手動手順化」の内容を、真にゼロから新規環境を立ち上げる場合の一時local backend→migrate-state手順を含む形に更新する。

## Impact

- `terraform/bootstrap/versions.tf`: backendブロック追加
- `terraform/bootstrap`のstate: ローカルファイルからGCS(`kuchida-devel-vaultwarden-tfstate`バケット、`bootstrap`prefix)へ移行
- `README.md` / `README.ja.md`: bootstrapのセットアップ手順セクションを更新
- 影響を受けるのはbootstrapを手動実行する運用者本人のみ。`terraform/main`のCIパイプライン(GitHub Actions)や本番VM・vaultwardenサービスには影響しない
