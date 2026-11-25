## Why

Vaultwardenは公開環境で動き、パスワード保管庫という機密性の高いデータを持つが、攻撃の痕跡がほぼ残らない。Caddyにアクセスログがなく、コンテナログはローテーションなしでブートディスク上にあるだけ（VMの再作成で消える）。sshdの認証ログもCloud Loggingに見当たらない。同じプロジェクトのn8n（`n8n-ops`の`add-security-logging`）では、1週間の観察で多数の探索とSSH総当たりが記録でき、ログ量も無料枠に十分収まった（プロジェクト全体で30日換算1GiB未満）ため、同じ方式を適用する。

## What Changes

- Caddyの両サイトブロック（公開ドメインと`:8080`の管理用）でJSONアクセスログを標準出力へ出す。**URLのクエリに含まれるトークン（`access_token`など）は除去する。**
- Ops Agentで、コンテナログ（`docker_containers`）とjournald（`host_journal`）をCloud Loggingへ転送する。
- `daemon.json`にログローテーションとサービス名のlabelを追加する（既存の`userland-proxy: false`は維持する）。
- READMEに、ログの見方と注意点を追記する。
- 範囲外: アラート・通知、Cloud Armor/WAF、`default-allow-ssh`の削除（`n8n-ops`の`remove-default-allow-ssh`で扱う）。
- プロジェクト共通のリソース（Secret ManagerのData Access監査ログ、`security-logs` bucketとsink）は`n8n-ops`が所有しており、**このリポジトリでは定義しない**。

## Capabilities

### New Capabilities
- `security-logging`: 攻撃の痕跡の記録（アクセスログ、コンテナログとjournaldの転送、ローテーション、秘密情報の除去）。

### Modified Capabilities
（なし。既存の要件は変えない）

## Impact

- `vaultwarden/Caddyfile`、`terraform/modules/gcp-compute/templates/startup-script.sh.tftpl`、`README.md`、`README.ja.md`。
- 反映時にDockerが再起動し、VaultwardenとCaddyが短時間止まる。両コンテナの再作成が必要。
- e2-micro（1GB）でOps Agentのログ収集が増えるため、メモリを確認する。
- IAMの変更は不要（VMのサービスアカウントは`logging.logWriter`を持つ）。
