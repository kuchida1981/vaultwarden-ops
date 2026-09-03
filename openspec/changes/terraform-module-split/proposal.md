## Why

`terraform/main/`・`terraform/bootstrap/` は全リソース定義がディレクトリ直下にフラットに配置されており、他環境への流用や部品単位の再利用がしづらい構造になっている（例: `tailscale.tf` に姉妹プロジェクト用の `tag:n8n-server` が同居）。マイルストーン0.2でGCPからOracle Cloud (OCI)への移行を検討しており、その前段としてまずGCP実装をコンポーネント単位のTerraform moduleへ分割し、`terraform/main`・`terraform/bootstrap` を「moduleを呼び出す薄いroot module」にしておく必要がある（GCPとOCIはリソース形状が大きく異なるため、同一moduleでのprovider切替は狙わない）。本番稼働中のVaultwardenインフラを壊さずに移行することが必須要件。

## What Changes

- `terraform/main/` の6ファイル（`network.tf`, `disk.tf`, `secrets.tf`, `iam.tf`, `tailscale.tf`, `compute.tf` + `templates/`）を `terraform/modules/gcp-{network,disk,secrets,iam,tailscale,compute}/` の6モジュールへ分割し、`terraform/main/*.tf` を各moduleを呼び出す薄いroot moduleに書き換える
- `terraform/bootstrap/` を `terraform/modules/gcp-{project-apis,state-bucket,wif,ci-service-account}/` の4モジュールへ分割する（`vaultwarden_vm_monitoring_writer`/`vaultwarden_vm_logging_writer`の2リソースはモジュール化せず`terraform/bootstrap/main.tf`に直置きのまま残す）
- 両ディレクトリに `moved.tf` を新規作成し、`moved`ブロックで旧アドレス→新アドレス（`module.gcp_xxx.<既存ローカル名>`）を対応させる。モジュール内のリソースローカル名は変更しない
- `terraform/main/versions.tf` の `required_version` を `>= 1.7.0` に引き上げる（`data.google_compute_network.default` の`moved`対応がTerraform 1.7以降の機能のため）
- `.github/workflows/lint.yml` のshellcheckパスを `terraform/main/templates/startup-script.sh.tftpl` から `terraform/modules/gcp-compute/templates/startup-script.sh.tftpl` へ更新し、tflintに `--call-module-type=all` を追加する
- `.github/workflows/terraform-apply.yml`・`.github/workflows/terraform-plan.yml` の変更検知対象パスに `terraform/modules` を追加する
- 実際のGCPリソース（VM、ディスク、Secret Manager、Tailscale ACL、静的IP等）は一切再作成・変更しない。`terraform plan` が両ディレクトリで `No changes` になることが本変更の受け入れ条件

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
(なし — `gcp-infrastructure`他の既存specはインフラの振る舞い・要件を定義しており、今回はTerraformコードのファイル配置・内部構造のみを変更する。プロビジョニングされるリソースの種類・設定・権限は変更しないため、spec-level requirementの変更はない)

## Impact

- **影響コード**: `terraform/main/*.tf`（6ファイル）、`terraform/bootstrap/main.tf`、新規 `terraform/modules/gcp-*/`（10モジュール）、新規 `terraform/main/moved.tf`・`terraform/bootstrap/moved.tf`、`terraform/main/versions.tf`
- **影響CI**: `.github/workflows/lint.yml`（shellcheckパス、tflint呼び出し）、`.github/workflows/terraform-plan.yml`・`.github/workflows/terraform-apply.yml`（パストリガー・差分検知対象）
- **影響なし**: 実際にプロビジョニングされるGCPリソース（VM/ディスク/Secret Manager/ファイアウォール/静的IP/Tailscale ACL）、`vaultwarden-deploy.yml`、アプリケーション層（`vaultwarden/`, `docker-compose.yml`, `Caddyfile`）
- **PR分割**: `terraform/main`のmodule化（PR #1）と`terraform/bootstrap`のmodule化（PR #2）は別PR。PR #1のマージ・apply・実リソース確認が完了してからPR #2に着手する
- **関連issue**: #89
