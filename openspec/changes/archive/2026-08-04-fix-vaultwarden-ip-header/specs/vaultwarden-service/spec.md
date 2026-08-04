## ADDED Requirements

### Requirement: 実クライアントIPの取得
システムは、CaddyがVaultwardenへ転送するリクエストにおいて、実際のクライアントIP(Caddyより手前のインターネット側の接続元)を判別できなければならない(SHALL)。判別されたIPは、ログイン試行のレート制限判定キーおよびイベント/監査ログのIP記録に用いられなければならない(SHALL)。

#### Scenario: admin diagnosticsでIP Header checkが成功する
- **WHEN** 管理者が`/admin`パネルのdiagnosticsページを開く
- **THEN** `IP Header check`が成功と表示される

#### Scenario: ログインイベントに実クライアントIPが記録される
- **WHEN** ユーザーが公開ドメイン(`https://vaultwarden.u-rei.com`)経由でログインを試みる
- **THEN** イベント/監査ログに、Caddyコンテナのdocker内部IPではなく、ユーザーの実際の接続元IPが記録される

#### Scenario: クライアントが送信したヘッダー値では実クライアントIPを偽装できない
- **WHEN** 悪意のあるクライアントが、リクエストに任意の`X-Forwarded-For`ヘッダーを付与して公開ドメインへ送信する
- **THEN** Caddyがこのヘッダーを自身が観測した実際の接続元IPで上書きするため、Vaultwardenが記録・レート制限判定に用いるIPはクライアントが指定した値ではなく実際の接続元IPになる
