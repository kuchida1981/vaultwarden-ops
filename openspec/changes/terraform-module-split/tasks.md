## 1. PR #1: terraform/main のモジュール化

- [x] 1.1 `terraform/modules/gcp-network/`を作成し、`network.tf`の内容（`data.google_compute_network.default`、`google_compute_firewall`x2、`google_compute_address`）を`variables.tf`/`main.tf`/`outputs.tf`に分割して移動する
- [x] 1.2 `terraform/modules/gcp-disk/`を作成し、`disk.tf`の内容（`google_compute_disk.vaultwarden_data`、`prevent_destroy`込み）を移動する
- [x] 1.3 `terraform/modules/tailscale/`（`gcp-`プレフィックスなし。Tailscaleはクラウド非依存のため）を作成し、`tailscale.tf`の内容（`tailscale_tailnet_key.vm`、`tailscale_acl.this`）を移動する
- [x] 1.4 `terraform/modules/gcp-secrets/`を作成し、`secrets.tf`の内容（`random_password`+5組のsecret/version）を移動する。`tailscale_authkey`用の`secret_data`は`tailscale`モジュールの出力（tailnet keyの値、sensitive）を入力変数として受け取るようにする
- [x] 1.5 `terraform/modules/gcp-iam/`を作成し、`iam.tf`の内容（`google_service_account.vm_runtime`、`google_secret_manager_secret_iam_member`x5）を移動する。`account_id = "vaultwarden-vm"`は一字一句変えないこと（bootstrap側が文字列決め打ちで参照しているため）。secret_idは`gcp-secrets`モジュールの出力を入力変数として受け取る
- [x] 1.6 `terraform/modules/gcp-compute/`を作成し、`compute.tf`と`templates/startup-script.sh.tftpl`を移動する。`gcp-network`（network self_link, address）、`gcp-disk`（disk self_link）、`gcp-iam`（SA email）、`gcp-secrets`（5x secret_id、および`depends_on`用のsecret_version/iam_memberリソース参照）を入力変数として受け取る
- [x] 1.7 各モジュールに`variables.tf`（入力）・`outputs.tf`（他モジュールが参照する値）を用意する
- [x] 1.8 `terraform/main/*.tf`をmodule呼び出しのみの薄いファイルに書き換える（`gcp-network`→`gcp-disk`→`tailscale`→`gcp-secrets`→`gcp-iam`→`gcp-compute`の依存順で呼び出す）
- [x] 1.9 `terraform/main/outputs.tf`を`module.gcp_network`・`module.gcp_compute`の出力を参照する形に書き換える
- [x] 1.10 `terraform/main/moved.tf`を新規作成し、25個の旧アドレス→`module.gcp_xxx.<旧リソース名>`の`moved`ブロックを列挙する
- [x] 1.11 `terraform/main/versions.tf`の`required_version`を`>= 1.7.0`に更新する
- [x] 1.12 `.github/workflows/lint.yml`のshellcheckパスを`terraform/modules/gcp-compute/templates/startup-script.sh.tftpl`に更新する
- [x] 1.13 ローカルで`terraform fmt -recursive`・`terraform init -backend=false`・`terraform validate`を実行し、エラーがないことを確認する（`terraform fmt`成功、`terraform validate`成功。`terraform plan`はローカルの`.terraform/`に残っていた実GCSバックエンド設定を再利用してしまい本番stateを参照する形になったため、ダミー値でのローカルplanは中止し、実stateに対する差分確認はCIのPR planに委ねる）
- [x] 1.14 PR #1（#110）を作成し、CIのplanコメントが「No changes」であることを確認する（tailscaleモジュールのgcp-プレフィックス除去のリネーム後も再確認済み）
- [x] 1.15 PR #1をマージし、mainブランチへのマージによる自動apply（productionのGitHub Environment承認ゲートを人手承認後）が成功することを確認する（`Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`）
- [x] 1.16 `gcloud compute instances describe vaultwarden`・`gcloud compute disks describe vaultwarden-data`の`creationTimestamp`が移行前後で変わっていないことを確認する（VM: 2026-07-07T06:45:25.680-07:00、disk: 2026-07-07T06:35:43.690-07:00、いずれも変化なし）
- [x] 1.17 `gcloud secrets versions list`で各secretのバージョン数が増えていないこと（再生成されていないこと）を確認する（5secretすべて1 versionのまま）
- [x] 1.18 `https://vaultwarden.u-rei.com`への実ログインを確認する（HTTP 200応答確認済み、ユーザーによる実ログインも確認済み）
- [x] 1.19 Tailscale管理画面でACL（tagOwners、sshルール）が変わっていないことを目視確認する（ユーザー確認済み）

## 2. PR #2: terraform/bootstrap のモジュール化（PR #1完了後に着手）

- [x] 2.1 `terraform/modules/gcp-project-apis/`を作成し、`google_project_service.required`（8 API有効化）を移動する
- [x] 2.2 `terraform/modules/gcp-state-bucket/`を作成し、`google_storage_bucket.tfstate`を移動する
- [x] 2.3 `terraform/modules/gcp-wif/`を作成し、WIF Pool+Providerを移動する
- [x] 2.4 `terraform/modules/gcp-ci-service-account/`を作成し、CI SA+付与ロール一式（`terraform_ci_roles`、state bucket IAM 2件を含む）を移動する
- [x] 2.5 `google_project_iam_member.vaultwarden_vm_monitoring_writer`/`vaultwarden_vm_logging_writer`はモジュール化せず`terraform/bootstrap/main.tf`に直置きのまま残す
- [x] 2.6 各モジュールに`variables.tf`・`outputs.tf`を用意する
- [x] 2.7 `terraform/bootstrap/main.tf`をmodule呼び出し＋直置き2リソースの薄いファイルに書き換える
- [x] 2.8 `terraform/bootstrap/outputs.tf`をmodule参照に書き換える
- [x] 2.9 `terraform/bootstrap/moved.tf`を新規作成し、9個の旧アドレス→`module.gcp_xxx.<旧リソース名>`の`moved`ブロックを列挙する
- [x] 2.10 `.github/workflows/terraform-plan.yml`の`plan`・`plan-bootstrap`両ジョブの変更検知（`git diff`対象パス）に`terraform/modules`を追加する
- [x] 2.11 `.github/workflows/terraform-apply.yml`のパストリガー（`paths:`）に`terraform/modules`を追加する
- [x] 2.12 `.github/workflows/lint.yml`のtflint呼び出しに`--call-module-type=all`を追加する
- [x] 2.13 ローカルで`terraform fmt -recursive`・`terraform init -backend=false`・`terraform validate`を実行し、エラーがないことを確認する（bootstrap側で成功。mainは前セッションのローカルキャッシュ不整合のみで今回の変更とは無関係）
- [x] 2.14 PR #2（#112）を作成し、CIのplanコメント（bootstrap）が「No changes」であることを確認する
- [x] 2.15 PR #2をマージする（bootstrapは自動applyされない）
- [x] 2.16 README記載の手順に従い、`terraform plan`で再度No changesを確認してから手動`apply`を実行する（`Apply complete! Resources: 0 added, 0 changed, 0 destroyed.`、apply後の再plan結果は`No changes. Your infrastructure matches the configuration.`で確認）
