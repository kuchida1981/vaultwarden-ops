## Context

vaultwarden は現在 asia-northeast1-b の e2-micro 1台 + 専用データディスク(10GB pd-balanced、`prevent_destroy`)+ 静的IP で稼働している。n8n-ops が e2-small に変更されるため、GCP 常時無料枠の e2-micro(us-west1/us-central1/us-east1 限定)を vaultwarden 側で使うべく、us-west1-b へ移す。レイテンシ増加は承知済み(proposal 参照)。

制約:
- GCE の VM・ゾーナルディスクはリージョン/ゾーンをまたいで移動できない。静的IPもリージョン固有。変更は destroy & create になる
- データディスクは `prevent_destroy = true` で、リージョン変更は replace を要求するため Terraform が止まる
- DNS (`vaultwarden.u-rei.com`) は手動管理
- データ(SQLite DB・RSA鍵・添付)は唯一の正で、毎日 NAS にもバックアップされている
- 無料枠は **請求アカウント単位**(e2-micro 1台/月、pd-standard 30GB、北米発の egress 1GB)

## Goals / Non-Goals

**Goals:**
- vaultwarden を us-west1-b で稼働させ、データを損失なく引き継ぐ
- Terraform のコードと state を新リージョンの状態と一致させる
- ダウンタイムと手作業を最小化し、ロールバック可能にする

**Non-Goals:**
- マルチリージョン/無停止移行(単一VM構成を維持)
- DNS の Terraform 化
- n8n-ops 側の変更そのもの(README 記述の更新のみ後続作業として扱う)
- アプリ層(docker-compose.yml / Caddyfile)の変更

## Decisions

### D1: データ移行は「停止 → スナップショット → 新ディスク作成」
旧VMを停止して DB を静止させ、データディスクのスナップショットを取り、そこから us-west1-b に新ディスクを作る。スナップショットはグローバルリソースなのでリージョン越えが可能。
- 代替: NAS バックアップから復元 → 手順が実機未検証で最大1日分の欠落があり得るため不採用(スナップショット取得後のフォールバックとして保持)
- 代替: rsync で VM 間コピー → 追加の経路・認証が必要で、ディスクを丸ごと運ぶ方が単純

### D2: ディスク作成は module の `snapshot` 変数で行い、旧ディスクは state から外す
`gcp-disk` module にオプション変数 `source_snapshot`(デフォルト null)を追加し、設定時は `google_compute_disk.snapshot` として復元する。旧ディスクは `terraform state rm` で Terraform の管理から外したうえで、移行確認後に `gcloud` で手動削除する(`prevent_destroy` を迂回するために `lifecycle` を書き換えるより、意図が明示的で安全)。移行完了後、`source_snapshot` は null に戻す(既存ディスクの `snapshot` 属性変更は replace を誘発するため、戻す前に `ignore_changes = [snapshot]` を入れて安全にする)。

### D3: ディスクは pd-standard に変更
無料枠に収めるためデータディスク・ブートディスクとも pd-standard とする。ただし SQLite の fsync で応答性が落ちる可能性があるため、移行後に実測し、許容できなければ pd-balanced に戻す(コスト月数十セント〜数ドル)。
- 注意: 無料枠の 30GB は請求アカウント合計。n8n 側のディスクと合算して超過する可能性があり、超過分は少額課金される。許容する前提とする(Open Questions 参照)

### D4: 静的IPは新規払い出しとし、DNS を手動切替
旧IPは移行できない。TTL を事前に短縮(300秒)し、新VM起動後に A レコードを新IPへ更新する。Caddy の証明書(ディスク上に保存)はそのまま持ち越されるが、DNS 切替前は新IPで ACME 更新が通らない点に留意する。
- 注: 使用中の標準外部IPv4 は無料枠外で課金される(旧リージョンと同額で変化なし)

### D5: Tailscale ノードの重複を避ける
同名ホスト `vaultwarden` が tailnet に残っていると、新ノードは `vaultwarden-1` になり、NAS バックアップ・`tailscale serve` の MagicDNS 名・`tailscale ssh` の宛先が変わってしまう。旧VM停止後・新VM起動前に Tailscale admin で旧ノードを削除する。起動後にホスト名がずれた場合は `tailscale set --hostname=vaultwarden` で修正する。

### D6: 実行順序は「旧VM停止 → スナップショット → state rm → apply(旧VM/IP破棄+新規作成)→ DNS → 検証 → 旧ディスク削除」
`terraform apply` で VM・静的IP は自動的に destroy & create される(zone/region 変更による replace)。旧ディスクのみ事前に state から外す。

### D7: デプロイワークフローのゾーン固定をやめる
`vaultwarden-deploy.yml` の `--zone=asia-northeast1-b` を `us-west1-b` に修正する。今後の再移行で同じ取りこぼしが起きないよう、リポジトリの変数/`gcloud compute instances list --filter` からの解決は過剰として今回は固定値の置換に留める。

## Risks / Trade-offs

- [移行中の DB 破損・欠落] → 旧VMで `systemctl start backup.service` を実行して NAS に最新バックアップを取り、その後 VM を停止してからスナップショットを取る。スナップショットと NAS の両方が復元元になる
- [ダウンタイム] → 旧VM停止から DNS 反映までサービス不可。TTL 短縮と、作業を利用の少ない時間帯に行うことで最小化する。ダウンタイム中はクライアントのオフラインキャッシュ(Bitwarden のローカル Vault)で閲覧は可能
- [pd-standard で応答性悪化] → 移行後に実測し、必要なら pd-balanced に戻す
- [無料枠の合算超過] → 少額課金として許容。GCP Billing でラベル `app=vaultwarden` 別に確認する
- [apply が旧ディスクで止まる / 誤って旧ディスクを destroy] → 事前に state rm を実施し、`terraform plan` で旧ディスクが destroy 対象に出ないことを確認してから apply する
- [Tailscale ホスト名のずれ] → D5 のとおり
- [WebAuthn(Titan キー)等のオリジン依存認証] → ドメインは変わらないため影響なし(既知の別件 #67 とは独立)
- [n8n 側との順序] → n8n 側の e2-micro 廃止前は 2 台が無料枠を超えて少額課金されるが、機能上の問題はない

## Migration Plan

1. 事前: DNS の TTL を 300 秒へ短縮、NAS バックアップの直近成功を確認
2. 旧VMで `systemctl start backup.service` → NAS へ最新バックアップ
3. 旧VMを停止(`gcloud compute instances stop`)し、データディスクのスナップショットを取得
4. Tailscale admin で旧ノード `vaultwarden` を削除
5. `terraform state rm module.gcp_disk.google_compute_disk.vaultwarden_data`
6. コード変更(region/zone、pd-standard、`source_snapshot`)を反映し `terraform plan` で想定どおり(旧VM・旧IP destroy、新ディスク・新VM・新IP create)であることを確認して apply
7. `vm_external_ip` の出力値で DNS A レコードを更新
8. 検証: `https://vaultwarden.u-rei.com` ログイン、Vault 内容、添付、`tailscale ssh vaultwarden`、`/admin`(tailnet 経由)、メール送信、`systemctl start backup.service` による NAS 疎通
9. 数日間観察後、旧ディスクを `gcloud compute disks delete` で削除、スナップショットも期間を置いて削除。TTL を元に戻す
10. n8n-ops の README を更新

**ロールバック**(手順 8 の検証前): コードを元に戻し、旧ディスクを `terraform import` し直すか、旧ディスクから旧ゾーンに VM を作り直して DNS を旧IPに戻す(旧静的IPは apply で解放されるため、旧IPが確保できない場合は新IPで DNS を更新)。手順 9 で旧ディスクを削除した後は、スナップショットまたは NAS バックアップからの復元になる。

## Open Questions

- n8n 側のディスク構成を含めた 30GB 無料枠の超過許容(超過しても少額なら許容する前提で進める)
- 移行作業の時間帯(利用の少ない時間帯を希望するか)
