## 1. 事前確認

- [ ] 1.1 VM上で`journalctl`、`/var/log/auth.log`の有無、Ops Agentの現在の`config.yaml`、`daemon.json`、メモリの空きを確認する（`config.yaml`に独自の設定があれば、上書きしない方法にする）
- [ ] 1.2 NASバックアップの直近の成功を確認する

## 2. 実装

- [ ] 2.1 `vaultwarden/Caddyfile`の両サイトブロックに`log`（`format filter`でクエリのトークンを削除、JSON、stdout）を追加し、`caddy validate`で確認する
- [ ] 2.2 ローカルでCaddyを起動し、`access_token`付きリクエストと`Authorization`/`Cookie`ヘッダが、ログに値を残さないことを確認する
- [ ] 2.3 startup-scriptの`daemon.json`にローテーションとlabelを追加する（`userland-proxy: false`を維持）
- [ ] 2.4 startup-scriptでOps Agentの`config.yaml`を生成する（`n8n-ops`と同じreceiver id、収集パスは`/var/lib/docker/containers`）
- [ ] 2.5 CIのshellcheck・terraform validate・planを通し、PRを作成する

## 3. 反映と確認

- [ ] 3.1 マージして反映し、caddyとvaultwardenの両コンテナを`--force-recreate`で作り直す
- [ ] 3.2 `docker inspect`で両コンテナのログ設定を確認する
- [ ] 3.3 Vaultwardenにログインと同期ができ、管理画面がtailnetから開けることを確認する
- [ ] 3.4 Cloud Loggingで`docker_containers`と`host_journal`（sshdを含む）が検索でき、`security-logs`にも複製されることを確認する
- [ ] 3.5 アクセスログの送信元が実IPであることを確認する
- [ ] 3.6 実ログを検索し、トークン（`access_token`、`eyJ`で始まる文字列など）が残っていないことを、Vaultwarden本体のログも含めて確認する
- [ ] 3.7 1週間後に、ログ量とVMのメモリを確認する

## 4. ドキュメント

- [ ] 4.1 README.md/README.ja.mdに、ログの見方と注意点を追記する
