## 1. コード変更(実装者が行う)

- [x] 1.1 `terraform/bootstrap/main.tf`の`terraform_ci_roles`(または専用リソース)に、`google_project_service.required`・WIF Pool/Provider・project IAMポリシーを読み取るための最小限のViewer系ロール(`roles/serviceusage.serviceUsageViewer`・`roles/iam.workloadIdentityPoolViewer`・`roles/iam.securityReviewer`)を追加する
- [x] 1.2 `terraform/bootstrap/main.tf`に、stateバケット(`google_storage_bucket.tfstate`)自体のメタデータ読み取り用の`roles/storage.legacyBucketReader`をバケットスコープ(`google_storage_bucket_iam_member`)で追加する
- [x] 1.3 `.github/workflows/terraform-plan.yml`に、`terraform/bootstrap`専用のjob(`plan-bootstrap`)を追加する。既存の`terraform/main`用`plan`ジョブの構造(actor判定・relevance-check・auth・init・plan・PRコメント)をテンプレートとして踏襲し、working-directoryと環境変数(`project_id`・`github_repo`のみ、tailscale/smtp/nas_backup系は不要)のみ差し替える
- [x] 1.4 追加した`plan-bootstrap`のrelevance-checkが`terraform/bootstrap`と自身のワークフローファイルのみを見ており、`terraform/main`用jobのrelevance-checkと独立していることを確認する
- [x] 1.5 既存の`terraform/main`用`plan`ジョブと新設`plan-bootstrap`ジョブの両方の`Terraform Plan`ステップに`set -o pipefail`を追加し、`terraform plan -no-color -out=tfplan 2>&1 | tee plan.txt`の形に修正する(terraform失敗時にteeがexit codeを握りつぶすバグの修正)
- [x] 1.6 README.md/README.ja.mdに、`terraform/bootstrap`はplanのみCI化されapplyは引き続き手動である旨を追記する
- [x] 1.7 `terraform fmt -check`(bootstrap)でコードの構文を確認する(YAML構文も`ruby -ryaml`で確認)

## 2. 権限反映 — [ユーザーが手動で実行する作業]

**注意**: `terraform/bootstrap`はCIからapplyできない設計を維持しているため、コード変更後の実際の権限付与は、認証情報を持つユーザー自身が手動で実行する。

- [ ] 2.1 [ユーザー作業] タスク1.1〜1.2のコード変更を取り込んだ上で、README記載の既存環境向け手順(`terraform init -backend-config="bucket=kuchida-devel-vaultwarden-tfstate"` → `terraform apply -var="project_id=..." -var="github_repo=..."`)で`terraform/bootstrap`を手動applyし、CI用SA(`terraform_ci`)に新しい読み取り専用ロールを付与する
- [ ] 2.2 [ユーザー作業] applyの差分が、追加したロールの付与のみであり、他のリソースに意図しない変更が無いことを確認する

## 3. 動作確認 — [ユーザーが手動で実行する作業]

- [ ] 3.1 [ユーザー作業] 本changeのPRで`plan-bootstrap` jobを実行し、CI上で`terraform plan`が正常終了(`No changes`または想定通りの差分)し、PRにplan結果がコメントされることを確認する。チェックが"pass"でも実際は`Planning failed`が握りつぶされている可能性があるため、PRコメントの中身まで確認する
- [ ] 3.2 [ユーザー作業] タスク3.1でrefreshエラー(権限不足)が出た場合、エラーメッセージから不足しているロールを特定し、タスク1.1/1.2に追加してタスク2を再実施する(設計のOpen Questions参照)
- [ ] 3.3 [ユーザー作業] 同じPR上で、`terraform-apply.yml`が起動していない(=applyが自動実行されていない)ことを確認する
