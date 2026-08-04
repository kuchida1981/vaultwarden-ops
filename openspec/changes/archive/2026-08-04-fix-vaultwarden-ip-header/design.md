## Context

Vaultwarden の `ClientIp::from_request`(`src/auth.rs`)は、設定された `IP_HEADER` の値を読み、カンマがあれば**先頭(左端)の値のみ**を信用する実装になっている。`IP_HEADER_TRUSTED_PROXIES`(デフォルト `local`)は、直接のTCP接続元(＝Caddy)がプライベートIPかどうかだけを見て、ヘッダー自体を信用するかを決める。ヘッダーの中身(複数ホップのリスト)そのものの検証は行わない。

一方、Caddy(`modules/caddyhttp/reverseproxy/reverseproxy.go` の `addForwardedHeaders`)は、直前のプロキシが `trusted_proxies` に含まれる場合のみ、受信した `X-Forwarded-For` を保持して自分のIPを追記する。信頼されていない場合(このリポジトリの `Caddyfile` は `trusted_proxies` を設定していないため常にこちら)は、**受信した値を完全に破棄し、自分が観測した実際のTCP接続元IP1つだけで上書きする**。

このリポジトリの構成では、Caddyはインターネットに直接面するエッジであり、`trusted_proxies` は未設定(＝空)。したがって、クライアントがどんな `X-Forwarded-For` を送っても、Caddyを通過した時点で単一の正しい値に上書きされる。この2つの実装の組み合わせにより、`IP_HEADER=X-Forwarded-For` は本構成においてなりすまし不可能である。

## Goals / Non-Goals

**Goals:**
- Vaultwardenが実クライアントIPを正しく取得できるようにする(admin diagnosticsの`IP Header check`が成功する状態にする)
- ログイン試行のレート制限とイベント/監査ログのIP記録を、ユーザーごとに正しく機能させる
- `Caddyfile`の`trusted_proxies`未設定という、この安全性が依存する前提を明文化し、将来の変更で暗黙のうちに壊れないようにする

**Non-Goals:**
- tailnet専用admin listener(`http://:8080`)経由のリクエストのIP記録精度向上は対象外(tailscale serveがループバック経由で接続するため、修正後も実tailnet端末IPにはならない。運用者本人のみが使う経路であり、issue #58の指摘・確認方法の範囲外)
- Caddy側の`trusted_proxies`設定の追加(現状の「未設定=常に上書き」という単純な安全性に依拠する方が、複数ホップを正しく扱う複雑な設定より、このシングルホップ構成には適している)

## Decisions

### Decision 1: `IP_HEADER_TRUSTED_PROXIES` はデフォルト(`local`)のまま変更しない
Caddyコンテナは`internal`というdocker composeネットワーク上のプライベートIPアドレス(docker割り当てのRFC1918範囲)からvaultwardenコンテナへ接続する。`local`は接続元がグローバルIPでないことのみを条件とするため、追加設定なしでこのまま機能する。

### Decision 2: `Caddyfile`は変更せず、安全性の前提をコメントとして明文化する
`Caddyfile`自体に動作変更は不要(Caddyのデフォルト動作が既に安全)。ただし、この安全性は「`trusted_proxies`が未設定であること」という非自明な前提に依存しており、コードを読むだけでは分からない。将来誰か(自分を含む)が「複数プロキシ構成に対応するため」等の理由で`trusted_proxies`を追加すると、Vaultwarden側は依然として先頭の値のみを信用する実装のため、クライアントによるIPなりすましが可能になってしまう。この落とし穴を`Caddyfile`にコメントとして残す。

### Decision 3: `X-Real-IP`ではなく`X-Forwarded-For`を採用する
代替案として、`Caddyfile`に`header_up X-Real-IP {remote_host}`を追加し、Vaultwarden側のデフォルト(`X-Real-IP`)をそのまま使う方法も検討した。この方法は`Caddyfile`側の変更が必要になる分、変更範囲が広がる。`IP_HEADER`環境変数1行の追加で完結する現方式の方が変更が小さく、Caddyの`X-Forwarded-For`付与はreverse_proxyのデフォルト動作でありCaddyfile側の追加設定が不要な点でも優位なため、こちらを採用する。

## Risks / Trade-offs

- [Risk] 将来`Caddyfile`に`trusted_proxies`(または別のプロキシを前段に追加する構成変更)が入ると、`X-Forwarded-For`の先頭値信用ロジックが悪用可能になり、IPなりすましが成立する → Mitigation: Decision 2のコメントで前提を明文化。将来的な多段プロキシ対応が必要になった場合は、この設計そのものを見直す(例: Vaultwardenのバージョンアップで先頭ではなく信頼できるホップ数分をスキップする実装に変わっていないか等も含めて再検証する)
- [Risk] admin listener(`:8080`)経由のリクエストは修正後も実tailnet端末IPを取得できない → Mitigation: Non-Goalsに明記。影響は運用者本人のadmin操作のみで、issue #58の確認方法(admin diagnostics・ログインイベント)はいずれも公開ドメイン経由の一般ユーザーフローを指しており、この制約とは独立に確認可能

## Migration Plan

1. `vaultwarden/docker-compose.yml`に`IP_HEADER`を追加、`Caddyfile`にコメントを追加してPRを作成・マージ
2. README「Vaultwardenのバージョン更新」節と同じ`vaultwarden-deploy.yml`の承認ゲート経由で本番反映(`docker compose up -d`でコンテナ再作成、VM再起動は不要)
3. ロールバックは`IP_HEADER`行を削除した状態への再デプロイで即座に可能(データ移行なし)
