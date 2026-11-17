## Why

姉妹プロジェクト n8n-ops (../n8n-ops) の VM を e2-small に変更するため、n8n 側は GCP Compute Engine 常時無料枠 (e2-micro) を使わなくなる。無料枠は us-west1 / us-central1 / us-east1 の e2-micro 1台(請求アカウント単位)とpd-standard 30GB に限られるため、vaultwarden を現在の asia-northeast1 から us-west1 へ移し、無料枠を vaultwarden 側で使う。レイテンシの増加は承知済み。

## What Changes

- `terraform/main/variables.tf` の `region` / `zone` デフォルトを `us-west1` / `us-west1-b` に変更する
- 静的外部IPはリージョン固有のため、新リージョンで新しいIPが払い出される。DNS A レコード (`vaultwarden.u-rei.com`、`u-rei-infra` リポジトリで Terraform 管理) の更新が必要
- データディスクはゾーナルでリージョンをまたげないため、旧VM停止 → スナップショット → us-west1-b に新ディスク作成 → 新VMにアタッチ、の手順で移行する(手動手順 + Terraform の state 付け替え)
- データディスクを `pd-balanced` から `pd-standard` に変更し、ブートディスクも `pd-standard` にして、ディスク合計 30GB 以内(無料枠内)に収める。**BREAKING**: SQLite の fsync に対する IOPS が下がり、応答性が悪化する可能性がある
- `.github/workflows/vaultwarden-deploy.yml` にハードコードされた `--zone=asia-northeast1-b` を `us-west1-b` に変更する
- `README.md` / `README.ja.md` / `docs/CUSTOMIZATION.md` のリージョン記述と移行・DNS 手順を更新する
- n8n-ops 側 README の「vaultwarden は asia-northeast1」記述の更新を、別リポジトリでの後続作業として明記する
- 旧リージョンの VM・ディスク・静的IP・旧 Tailscale ノードの削除と、ロールバック手順を定める
- 無料枠は e2-micro 1台までのため、n8n 側の e2-small 化(旧 e2-micro 廃止)との順序依存を管理する

## Capabilities

### New Capabilities
(なし)

### Modified Capabilities
- `gcp-infrastructure`: 「東京リージョンの最安スペックVM」要件を us-west1(無料枠対象リージョン)に変更し、データディスク/ブートディスクを pd-standard とする

## Impact

- **影響コード**: `terraform/main/variables.tf`、`terraform/modules/gcp-disk/main.tf`、`terraform/modules/gcp-compute/main.tf`(ブートディスク種別)、`.github/workflows/vaultwarden-deploy.yml`、`README.md`、`README.ja.md`、`docs/CUSTOMIZATION.md`、`openspec/specs/gcp-infrastructure/spec.md`
- **影響リソース**: VM、データディスク、静的IP は旧リージョンのものが destroy され新リージョンで作成される。ファイアウォール、Secret Manager、IAM、Tailscale ACL は影響なし
- **ダウンタイム**: 旧VM停止から DNS 切替・伝播完了まで(数十分〜数時間見込み)。その間 vaultwarden は利用不可
- **外部影響**: `u-rei-infra` への DNS 更新 PR、Tailscale の旧ノード削除、NAS バックアップ(Tailscale 経由)の疎通再確認、n8n-ops の README 更新と e2-small 化との前後関係
