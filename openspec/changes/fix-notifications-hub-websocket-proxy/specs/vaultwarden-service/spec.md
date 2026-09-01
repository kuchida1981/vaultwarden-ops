## ADDED Requirements

### Requirement: WebSocketによるライブ同期通知の正しい転送
システムは、`/notifications/hub`宛のWebSocket接続を、Vaultwardenのメインポート(80)を経由して転送しなければならない(SHALL)。Vaultwarden 1.29.0以降で廃止された専用WebSocketポート(3012)宛には転送してはならない(SHALL NOT)。

#### Scenario: ライブ同期通知が届く
- **WHEN** ログイン済みのクライアントが公開ドメイン経由でVaultwardenに接続し、Vault内のアイテムが別クライアントから変更される
- **THEN** WebSocket接続(`/notifications/hub`)経由でプッシュ通知が届き、変更中のクライアントが即座に同期される

#### Scenario: 廃止されたポートへは転送されない
- **WHEN** Caddyfileの設定を確認する
- **THEN** `vaultwarden:3012`(廃止された専用WebSocketポート)への`reverse_proxy`指定は存在しない
