## Context

- Caddy 2.11 + Vaultwarden（Docker Compose）、e2-micro、us-west1。Ops Agentは導入済み。
- Dockerのdata-rootは既定（ブートディスクの`/var/lib/docker`）。`daemon.json`は`{"userland-proxy": false}`で、これは実IPを保つために必須。
- `n8n-ops`が作ったsinkは`log_id("docker_containers") OR log_id("host_journal") OR log_id("cloudaudit.googleapis.com/data_access")`で、VMを限定していない。

## Goals / Non-Goals

**Goals:** 攻撃の痕跡をVM外に残す。ログに秘密情報を残さない。無料枠に収める。
**Non-Goals:** アラート、自動遮断、ファイアウォールの変更、Vaultwardenのバージョンや設定の変更。

## Decisions

### D1: receiver idをn8nと同じにする
`docker_containers`と`host_journal`にすれば、既存のsinkがそのまま`security-logs`（90日）へ複製する。名前を変える場合は、`n8n-ops`のsinkのフィルタも変える必要がある。

### D2: クエリのトークンはCaddyの`format filter`で除去する
通知用WebSocket（`/notifications/hub`）は、`access_token`をクエリで渡すと理解している（実装時にログで確認する）。パスは攻撃の分析に必要なので残し、`request>uri`のクエリのうち秘密になりうるキー（`access_token`、`token`など）を削除する。n8nのTraefikではこれができず許容したが、Vaultwardenは扱う情報の性質上、許容しない。
- `Authorization`/`Cookie`ヘッダは、Caddyが既定でredactすると理解している。実装時に確認する。

### D2a: Vaultwarden本体のrequestログは止める
ローカル検証（1.37.5）で、本体の`[request][INFO]`行がクエリを含むURI全体（`access_token`、`token`、`Token`、`t`）を出すことを確認した。`LOG_LEVEL=info,request=off`でこの行だけを止める。ログイン失敗（IPとユーザー名）と、`<token>`のような雛形で出る応答行は残る。要求の内容はCaddyのアクセスログで追える。

### D2b: Caddyはヘッダを丸ごと落とし、エラーログにも同じフィルタをかける
Caddyは既定で全リクエストヘッダを出すため、`request>headers`と`resp_headers`を削除し、User-Agentだけを`log_append`で残す。プロキシのエラー（502）は既定のloggerにリクエストつきで出るので、グローバルの`log default`にも同じフィルタをかける。ローカル検証で、アクセスログ・エラーログとも秘密が残らないことを確認した。

### D2c: Ops Agentの設定はコンテナ作り直しの後に置く
作り直す前のコンテナのログファイルにはトークンが含まれうる。`daemon.json`が変わった起動では`--force-recreate`で作り直して古いログを消し、その後にOps Agentを設定する。

### D3: journaldを収集する
sshdの認証ログがCloud Loggingに見当たらない（Debianのrsyslogが`auth,authpriv`を`/var/log/syslog`に出さないためと推測、未確認）。journaldのreceiverで解消する。

### D4: ローテーションとlabelは`daemon.json`で指定する
`{"userland-proxy": false, "log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "5", "labels": "com.docker.compose.service"}}`。収集パスは`/var/lib/docker/containers/*/*-json.log`。

### D5: コンテナは明示的に再作成し、確認する
`log-opts`は新規のコンテナにだけ適用される。n8nでは、1つのコンテナに適用されず個別の再作成が必要だった。`vaultwarden-deploy.yml`の`--force-recreate`はcaddyだけなので、vaultwardenは別に作り直し、`docker inspect`で両方を確認する。

## Risks / Trade-offs

- [ログにトークンや秘密が残る] → D2。反映直後に実ログを検索して確認する。残っていたら、該当ログを削除してからフィルタを直す。
- [Vaultwarden本体のログにメールアドレスやURLが出る] → ログイン失敗の分析に必要なため、メールアドレスは許容する。URLにトークンが出ないかは実ログで確認する。
- [Dockerの再起動で停止し、パスワードの参照ができなくなる] → 利用の少ない時間に反映する。クライアントはキャッシュを持つ。事前にNASバックアップが成功していることを確認する。
- [`userland-proxy`の設定が失われ、クライアントIPが壊れる] → `daemon.json`の内容を確認し、反映後にログの送信元IPが実IPであることを確認する。
- [e2-microのメモリ不足] → 反映後にメモリを監視し、問題があればOps Agentの収集対象を減らす。

## Migration Plan

1. PRをマージすると、startup-scriptのメタデータ変更が`terraform-apply`で反映される（ワークフローがstartup-scriptを再実行する）。
2. 両コンテナを再作成して確認する。
3. ロールバック: PRをrevertして同じ手順で反映する。

## Open Questions

- クエリで除去すべきキーの一覧（実ログで確認する）。
- Caddyfileはbind mountなので、内容が変わっても`up -d`ではcaddyが再読み込みしない。D5の`--force-recreate`で反映する（startup-scriptは再実行時に`git pull --ff-only`する）。
