## Context

`terraform/main/`（VM/ディスク/ネットワーク/IAM/Secret Manager/Tailscale ACLをGitHub ActionsがGCSリモートステートに対してPRごとに`plan`→mainマージで自動`apply`する完全GitOps運用）と`terraform/bootstrap/`（CI用WIF/SA/tfstateバケット、手動apply）は、現状どちらもディレクトリ直下に全リソースがフラットに置かれている。マイルストーン0.2でのOCI移行に先立ち、GCP実装をコンポーネント単位のmoduleへ分割し、`terraform/main`・`terraform/bootstrap`を「moduleを呼び出す薄いroot module」にする。本番稼働中のVaultwarden（`https://vaultwarden.u-rei.com`、n8n-opsと共有するTailscale tailnetのsole owner）を一切壊さずに移行することが最優先制約。

## Goals / Non-Goals

**Goals:**
- `terraform/main`を6モジュール（`gcp-network`, `gcp-disk`, `gcp-secrets`, `gcp-iam`, `tailscale`, `gcp-compute`）、`terraform/bootstrap`を4モジュール（`gcp-project-apis`, `gcp-state-bucket`, `gcp-wif`, `gcp-ci-service-account`）に分割する
- `moved`ブロックによる無停止・ゼロdiffのstate移行（`terraform plan`が`No changes`になることを機械的な正しさの証拠とする）
- モジュール境界を「将来`terraform/modules/oci-*`を並べて追加する」前提の`gcp-`プレフィックスで設計する。ただし`tailscale`モジュールのみ例外（下記Decisions参照）

**Non-Goals:**
- GCPとOCIを同一moduleでprovider切替する設計は狙わない（リソース形状が大きく異なるため）
- 実際のリソース設定・権限・ネットワーク構成の変更（挙動は一切変えない、純粋な構造リファクタ）
- OCI移行そのもの（別issue/spike。本変更はその前段のみ）

## Decisions

### モジュール境界: ファイル単位に対応させ、diskはcomputeに統合しない
`network.tf`→`gcp-network`、`disk.tf`→`gcp-disk`、`secrets.tf`→`gcp-secrets`、`iam.tf`→`gcp-iam`、`tailscale.tf`→`tailscale`、`compute.tf`+`templates/`→`gcp-compute`の1:1対応とする。diskを独立モジュールにするのは、`disk.tf`の既存コメントにある「VMのライフサイクルと意図的に独立させている」という設計意図をモジュール境界でも表現するため。computeとのやり取りは`disk.self_link`の1入力のみで完結する。

`tailscale`モジュールだけ`gcp-`プレフィックスを付けない: TailscaleはGCPのサービスではなく、`tailscale_tailnet_key`・`tailscale_acl`はGCPプロジェクトからもVMからも独立した別providerのリソースなので、プレフィックスを付けると誤解を招く。他の5モジュールと違ってクラウド非依存のため、将来OCI移行時も`oci-tailscale`を新設せず、この`tailscale`モジュールをそのまま再利用できる可能性が高い。

### モジュール間依存グラフ
```
gcp-network      gcp-disk         tailscale
(standalone)    (standalone)    (standalone)
                                       │ tailnet_key.key (sensitive output)
                                       ▼
                                 gcp-secrets
                                       │ 5x secret_id output
                                       ▼
                                 gcp-iam (SA + secretAccessor x5)
                                       │ SA.email output
     └──────────────┬────────────────┘
                     ▼
               gcp-compute
   (network self_link/address, disk self_link, SA.email,
    5x secret_id for templatefile, depends_on: secret_version x5 + iam_member x5)
```
`gcp-secrets`の`tailscale_authkey`シークレット値は現状`secrets.tf`内で`tailscale_tailnet_key.vm.key`（`tailscale.tf`）を直接参照している。分割後は`gcp-secrets`が`tailscale`モジュールの出力(sensitive)を入力に取る、という依存の向きを明示する。`gcp-compute`は他5モジュール全ての出力を集約するハブになるため、配線ミスが最も起きやすい箇所として実装時に注意する。

### state移行方法: `moved`ブロック（`terraform state mv`は使わない）
本リポジトリはPRごとの`plan`→mainマージで自動`apply`する完全GitOps運用のため、`moved`ブロックは通常のPR・plan/applyフローにそのまま乗り、追加の手作業やCIステップが不要。`terraform state mv`は実stateへの一回限りのコマンド実行が必要で、長期鍵なしの認証方針（WIF経由の一時credential）と衝突しうる上、git履歴に残らずPRレビューできない。`moved`ブロックはPRのplanコメントで「No changes」を確認できることが、移行が正しいことの機械的な証拠になる。

`terraform/main/moved.tf`・`terraform/bootstrap/moved.tf`をルートモジュールに新規作成し、旧アドレス→`module.gcp_xxx.<旧リソース名>`のペアを列挙する（main側25個、bootstrap側9個）。モジュール内のリソースローカル名は今回一切変更しない。

`data.google_compute_network.default`の`moved`対応はTerraform 1.7以降の機能のため、`terraform/main/versions.tf`の`required_version`を`>= 1.7.0`に上げる。

### bootstrapのクロスモジュール依存2リソースはモジュール化しない
`google_project_iam_member.vaultwarden_vm_monitoring_writer`/`vaultwarden_vm_logging_writer`は、`terraform/bootstrap/main.tf`に直置きのまま残す。これらは「main側の`vaultwarden-vm` SA（別root module/state）を文字列決め打ちで参照する、bootstrapとmainの唯一の実質的クロスモジュール依存」という、bootstrap自身の構造に関する説明であり、専用モジュールを作っても再利用価値がなく、既存コメントの文脈が失われるため。

### PR分割: main→bootstrapの順で、間に検証を挟む
PR #1（`terraform/main`のmodule化）をマージ・apply・実リソース確認まで完了させてから、PR #2（`terraform/bootstrap`のmodule化）に着手する。理由: `terraform/bootstrap`はCI自身の権限（WIF・`terraform-ci` SA）を扱うモジュールで、ここで問題が起きると`terraform/main`側のCI（plan/apply）まで巻き添えで壊れうる非対称なリスクがあるため、影響範囲が広いPR #1を先に本番で安定確認してから、CI権限に触れるPR #2に進む。

## Migration Plan

1. **PR #1（`terraform/main`）**
   - `terraform/modules/gcp-{network,disk,secrets,iam,compute}/`と`terraform/modules/tailscale/`を作成し、各`.tf`の中身を移動、`templates/`ディレクトリごと`gcp-compute`へ移動
   - rootの各`.tf`をmodule呼び出しのみの薄いファイルに書き換え、`outputs.tf`をmodule参照に書き換え
   - `moved.tf`を作成（旧アドレス→新アドレス、25個）
   - `versions.tf`の`required_version`を`>= 1.7.0`に更新
   - `.github/workflows/lint.yml`のshellcheckパスを`terraform/modules/gcp-compute/templates/startup-script.sh.tftpl`に更新
   - ローカルで`terraform fmt -recursive` / `terraform validate`確認 → PR作成
   - PRのplanコメントが「No changes」であることを確認してからマージ
   - apply後、`gcloud compute instances describe vaultwarden`・`gcloud compute disks describe vaultwarden-data`の`creationTimestamp`が変わっていないこと、`gcloud secrets versions list`で各secretのバージョン数が増えていないこと、`https://vaultwarden.u-rei.com`への実ログイン、Tailscale管理画面でACL（tagOwners、sshルール）が変わっていないことを確認
2. **PR #2（`terraform/bootstrap`、PR #1とは別PR、PR #1の検証完了後に着手）**
   - `terraform/modules/gcp-{project-apis,state-bucket,wif,ci-service-account}/`を作成し、同様の手順で分割
   - `vaultwarden_vm_monitoring_writer`/`vaultwarden_vm_logging_writer`は`terraform/bootstrap/main.tf`に直置きのまま残す
   - `moved.tf`を作成（旧アドレス→新アドレス、9個）
   - `.github/workflows/terraform-plan.yml`・`.github/workflows/terraform-apply.yml`のパストリガー・diff検出対象パスに`terraform/modules`を追加
   - `.github/workflows/lint.yml`のtflintに`--call-module-type=all`を追加
   - PRのplanコメントが「No changes」であることを確認してからマージ
   - bootstrapは自動applyされないため、README記載の手順で手動apply（`terraform plan`で再度No changes確認後に`apply`）

**ロールバック方針**: 想定外の差分が出た場合は単にマージしない。誤ってマージ・applyしてしまった場合はrevert PRを出し、再度No changesを確認してから再マージする。

## Risks / Trade-offs

- [`vaultwarden-vm`のaccount_idをモジュール内で誤って変更してしまう] → `gcp-iam`モジュール内の`google_service_account.vm_runtime`の`account_id = "vaultwarden-vm"`は一字一句変えないことをレビュー時の必須チェック項目とする。bootstrap側が`"serviceAccount:vaultwarden-vm@${var.project_id}.iam.gserviceaccount.com"`という文字列決め打ちでこれを参照しており、`terraform_remote_state`を使わない設計（意図的）のため、account_idが変わってもTerraformは検知してくれない
- [`moved`ブロックの旧→新アドレス対応を書き間違え、意図しないdestroy&createが計画される] → PRのplanコメントで`No changes`（`0 added, 0 changed, 0 destroyed`）を確認できるまでマージしない。`prevent_destroy`のかかった`gcp-disk`は誤destroy計画時にTerraform自体がエラーで止まる安全弁としても機能する
- [`gcp-secrets`→`tailscale`の依存配線を見落とし、tailnet keyの値が渡らない] → design内の依存グラフを実装時のチェックリストとして使う。`terraform plan`が`No changes`にならなければ即座に検知できる
- [CI ワークフローのパス変更漏れ（`terraform/modules`未追加）で、モジュールのみの変更がCIに検知されず放置される] → PR #1・PR #2それぞれで対象ファイルへの変更を明示的にタスク化する
- [PR #2でbootstrap側のCI権限を壊し、main側のCIも巻き添えで止まる] → PR #1の本番検証完了を待ってからPR #2に着手する順序を守る（Migration Plan参照）

## Open Questions

(なし)
