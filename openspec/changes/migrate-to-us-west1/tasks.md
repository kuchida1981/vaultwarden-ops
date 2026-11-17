## 1. コード変更(PR 作成まで)

- [x] 1.1 `terraform/main/variables.tf` の `region` / `zone` デフォルトを `us-west1` / `us-west1-b` に変更する
- [x] 1.2 `terraform/modules/gcp-disk` に `source_snapshot`(デフォルト null)変数を追加し、データディスクの type を `pd-standard` に変更する。`terraform/main/disk.tf` から変数を受け渡す
- [x] 1.3 `terraform/modules/gcp-compute/main.tf` のブートディスク type を `pd-standard` に変更する
- [x] 1.4 `.github/workflows/vaultwarden-deploy.yml` の `--zone=asia-northeast1-b` を `us-west1-b` に変更する
- [x] 1.5 `README.md` / `README.ja.md` のアーキテクチャ図(`asia-northeast1`)と、リージョン・ディスク種別の記述を更新する
- [x] 1.6 `docs/CUSTOMIZATION.md` の `region` / `zone` デフォルト値の記述を更新する
- [x] 1.7 `terraform fmt -check` / `terraform validate` / lint ワークフロー相当のチェックが通ることを確認する

## 2. 切替時間短縮のための事前準備(切替の1時間以上前)

- [ ] 2.1 NAS バックアップの直近成功を確認する
- [ ] 2.2 `u-rei-infra` で vaultwarden の A レコード専用 TTL(60秒)を設定する PR を作成し、マージ・apply する。旧TTL(3600秒)が切れるまで待つ
- [ ] 2.3 `gcloud compute addresses create vaultwarden-static-ip --region us-west1` で新IPを確保し、旧アドレスを `terraform state rm`、新アドレスを `terraform import` する。`terraform plan` で静的IPに差分が出ないことを確認する
- [ ] 2.4 新IPを `vaultwarden_ip` に設定する `u-rei-infra` の PR を作成する(マージはしない)
- [ ] 2.5 利用の少ない時間帯に作業枠を確保する

## 3. データ移行(手動・ダウンタイム開始)

- [ ] 3.1 旧VMで `systemctl start backup.service` を実行し、NAS へ最新バックアップを取る
- [ ] 3.2 旧VMを停止する(`gcloud compute instances stop vaultwarden --zone asia-northeast1-b`)
- [ ] 3.3 データディスク `vaultwarden-data` のスナップショットを取得する(`gcloud compute disks snapshot`)
- [ ] 3.4 Tailscale admin で旧ノード `vaultwarden` を削除する
- [ ] 3.5 `terraform state rm module.gcp_disk.google_compute_disk.vaultwarden_data` を実行する
- [ ] 3.6 `data_disk_source_snapshot` に 3.3 のスナップショットを指定して `terraform plan` を実行し、旧VMの destroy と新ディスク・新VMの create のみであること(旧ディスク・旧IPが destroy 対象に出ないこと)を確認する
- [ ] 3.7 `terraform apply` を実行する(PR マージ経由の場合は terraform-apply ワークフロー)

## 4. 切替と検証

- [ ] 4.1 手順 3.7 の apply と並行して、タスク 2.4 の DNS PR をマージし、production 環境の承認を行って apply する。TTL が 60 秒のため、反映は1〜数分で完了する
- [ ] 4.2 `https://vaultwarden.u-rei.com` でログインでき、Vault・添付・Send が移行前と同じであることを確認する
- [ ] 4.3 `tailscale ssh vaultwarden` で接続でき、ホスト名が `vaultwarden`(`vaultwarden-1` でない)であることを確認する。ずれていれば `tailscale set --hostname=vaultwarden`
- [ ] 4.4 tailnet 経由の `/admin` と、公開ドメインでの `/admin` が 403 であることを確認する
- [ ] 4.5 メール送信(SMTP)が機能することを確認する
- [ ] 4.6 VM 上で `systemctl start backup.service` を実行し、NAS への転送が成功することを確認する
- [ ] 4.7 `vaultwarden-deploy.yml` を手動実行(workflow_dispatch)し、新ゾーンへのデプロイが成功することを確認する
- [ ] 4.8 応答性を確認し、pd-standard で許容できなければ pd-balanced に戻すか判断する

## 5. 後始末

- [ ] 5.0 `u-rei-infra` の vaultwarden 専用 TTL を継続するか、共通値に戻すか決める

- [ ] 5.1 数日間の安定稼働を確認後、旧IP(asia-northeast1)と旧ディスク `vaultwarden-data`(asia-northeast1-b)を `gcloud compute disks delete` で削除する
- [ ] 5.2 `data_disk_source_snapshot` を null に戻し(`ignore_changes = [snapshot]` は追加済み)、`terraform plan` が `No changes` になることを確認する
- [ ] 5.3 スナップショットを一定期間(例: 2週間)保持した後に削除する
- [ ] 5.5 旧リージョンに残リソース(VM・ディスク・静的IP)がないことを `gcloud` で確認する
- [ ] 5.6 `openspec/specs/gcp-infrastructure/spec.md` の Purpose の「東京リージョン」記述を us-west1 に更新する(archive 時の spec sync 後)

## 6. 他リポジトリ・順序依存

- [ ] 6.1 n8n-ops の README(`README.md` / `README.ja.md`)の「vaultwarden は asia-northeast1」記述を更新する(別リポジトリでの作業)
- [ ] 6.2 n8n 側の e2-small 化が完了し、無料枠の e2-micro が vaultwarden のみになっていることを GCP Billing で確認する
