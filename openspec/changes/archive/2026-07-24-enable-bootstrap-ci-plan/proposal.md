## Why

`.github/dependabot.yml`は`terraform/bootstrap`にも週次更新エントリを持つが、CI側(`terraform-plan.yml`/`terraform-apply.yml`)は`terraform/main`のみを対象にしており、bootstrap向けのdependabot PRはplanが空振りし、マージしてもapplyが一切走らない。issue #28の対応でbootstrap自身のstateがGCSリモートバックエンドに移行済みのため、CIからのplan読み取りが技術的に可能になった。まずplanだけでもCI化し、bootstrap向けPRのレビューを人間がターミナルレスで行えるようにする(issue #44)。

## What Changes

- `terraform-plan.yml`に`terraform/bootstrap`専用のjob(`plan-bootstrap`)を追加し、bootstrap配下の変更をdiff対象に含め、`terraform plan`結果をPRにコメントする(既存の`terraform/main`用jobは変更せず、専用の分離した構成にする — 変数セットが異なるため)。
- `terraform/bootstrap/main.tf`の`terraform_ci_roles`に、bootstrapが管理するリソース(project services / WIF Pool・Provider / project IAMポリシー)を`plan`(refresh)するために必要な読み取り専用ロールを追加する。また、stateバケット自体のメタデータ読み取り(`storage.buckets.get`)に必要な`roles/storage.legacyBucketReader`をバケットスコープで追加する(既存の`roles/storage.objectAdmin`はオブジェクトレベル権限のみでこれを含まないため)。
- **BREAKING**: `terraform_ci`サービスアカウントの権限セットが拡張される(読み取り専用ロールの追加)。これは`terraform/bootstrap`のコード変更であり、CIはbootstrapをapplyできない設計を維持するため、**人間が手動で`terraform apply`する**必要がある(README記載の既存の手動apply手順に従う)。
- `terraform-plan.yml`の既存`plan`ジョブ(`terraform/main`用)と新設`plan-bootstrap`ジョブの両方で、`terraform plan -no-color -out=tfplan | tee plan.txt`に`set -o pipefail`が無く、terraform自体が失敗してもステップが成功扱いになるバグを修正する。
- `terraform-apply.yml`は変更しない(`terraform/bootstrap/**`は引き続きpathフィルタ対象外。CIからのbootstrap自動applyは意図的にスコープ外のまま)。
- READMEに、bootstrapはplanのみCI化され、applyは引き続き手動である非対称性を明記する。

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `deployment-pipeline`: 既存の要件「PRでplan、mainマージ後は承認を経てapply」の対象範囲を`terraform/bootstrap`のplanにも拡張する(ただしbootstrapはapplyの対象外)。新しい要件として「bootstrapのdependabot PRに対するCI plan」を追加する。

## Impact

- `.github/workflows/terraform-plan.yml`: bootstrap用job追加、既存job・新設jobともpipefailバグ修正
- `terraform/bootstrap/main.tf`: `terraform_ci_roles`に読み取り専用ロール追加、バケットスコープの`storage.legacyBucketReader`追加
- `terraform/bootstrap`のIAM状態: 追加ロールの反映に人間の手動apply作業が必要(既存の`kuchida-devel`環境に対して)
- `README.md` / `README.ja.md`: plan/apply非対称性の記載を追加
- `terraform-apply.yml`は変更なし。本番VM・vaultwardenサービス・`terraform/main`のCIパイプラインには影響しない
