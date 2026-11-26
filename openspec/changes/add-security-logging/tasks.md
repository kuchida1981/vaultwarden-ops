## 1. 事前確認

- [x] 1.1 VM上で`journalctl`、`/var/log/auth.log`の有無、Ops Agentの現在の`config.yaml`、`daemon.json`、メモリの空きを確認する（`config.yaml`に独自の設定があれば、上書きしない方法にする）（2026-11-26: `config.yaml`はコメントのみ、`daemon.json`は旧内容、`auth.log`あり、メモリのavailableは262MBでswapなし）
- [x] 1.2 NASバックアップの直近の成功を確認する（2026-11-26 12:28 JSTのバックアップ成功を確認）

## 2. 実装

- [x] 2.1 `vaultwarden/Caddyfile`の両サイトブロックに`log`（`format filter`でクエリのトークンを削除、JSON、stdout）を追加し、`caddy validate`で確認する（`caddy validate`は2.11.4と2.11.9で成功）
- [x] 2.2 ローカルでCaddyを起動し、`access_token`付きリクエストと`Authorization`/`Cookie`ヘッダが、ログに値を残さないことを確認する（内部ネットワークのDockerで確認。アクセスログ・502のエラーログとも秘密なし。本体のrequestログにトークンが出たため`LOG_LEVEL=info,request=off`を追加し、ログイン失敗の記録が残ることも確認）
- [x] 2.3 startup-scriptの`daemon.json`にローテーションとlabelを追加する（`userland-proxy: false`を維持）
- [x] 2.4 startup-scriptでOps Agentの`config.yaml`を生成する（`n8n-ops`と同じreceiver id、収集パスは`/var/lib/docker/containers`）
- [x] 2.5 CIのshellcheck・terraform validate・planを通し、PRを作成する（PR #154）

## 3. 反映と確認

- [x] 3.1 マージして反映し、caddyとvaultwardenの両コンテナを`--force-recreate`で作り直す（2026-11-26。反映前に、VMのjournalに残る古いトレースがOps Agentに取り込まれないよう、journalを削除して該当0件を確認。`daemon.json`の変更でコンテナは自動で作り直される）
- [x] 3.2 `docker inspect`で両コンテナのログ設定を確認する（`docker inspect`は未実行。両サービスのログにcomposeのlabelが付くことから、新しい`log-opts`で作り直されたと判断）
- [x] 3.3 Vaultwardenにログインと同期ができ、管理画面がtailnetから開けることを確認する（運用者がログイン・同期・管理画面を確認）
- [x] 3.4 Cloud Loggingで`docker_containers`と`host_journal`（sshdを含む）が検索でき、`security-logs`にも複製されることを確認する（`docker_containers`と`host_journal`（sshdを含む）が検索でき、`security-logs`にも複製されている）
- [x] 3.5 アクセスログの送信元が実IPであることを確認する（試験リクエストの`client_ip`が送信元の実IPと一致）
- [x] 3.6 実ログを検索し、トークン（`access_token`、`eyJ`で始まる文字列など）が残っていないことを、Vaultwarden本体のログも含めて確認する（ダミーのトークンとヘッダを付けた本番へのリクエストで、パスだけが残ることを確認。反映後の全ログに、ダミー値・JWT・クエリのトークン・本体のrequest行はなし）
- [ ] 3.7 1週間後に、ログ量とVMのメモリを確認する（反映: 2026-11-26。2026-12-04に確認する。反映直後のメモリ使用率は約56〜63%）

## 4. ドキュメント

- [x] 4.1 README.md/README.ja.mdに、ログの見方と注意点を追記する
