## Purpose

Docker ComposeによるVaultwarden+Caddyのデプロイ、カスタムドメイン(`vaultwarden.u-rei.com`)でのTLS終端、公開環境向けハードニング設定(招待制サインアップ、ADMIN_TOKENによる管理パネル保護、専用ディスクへのデータ永続化)を提供する。

## Requirements

### Requirement: Docker ComposeによるVaultwarden+Caddyのデプロイ
システムは、VaultwardenとCaddy(リバースプロキシ/TLS終端)をDocker Composeで構成し、VM上で稼働させなければならない(SHALL)。

#### Scenario: docker composeでサービスが起動する
- **WHEN** VM上で`docker compose up -d`が実行される
- **THEN** vaultwardenコンテナとcaddyコンテナがともに起動し、正常稼働状態になる

### Requirement: カスタムドメインでの自動TLS終端
システムは、`vaultwarden.u-rei.com`宛のHTTPSリクエストに対し、Let's Encryptから自動取得した証明書でTLSを終端しなければならない(SHALL)。

#### Scenario: 有効なTLS証明書で応答する
- **WHEN** ブラウザが`https://vaultwarden.u-rei.com`にアクセスする
- **THEN** Let's Encrypt発行の有効な証明書が提示され、警告なく接続できる

### Requirement: サインアップは招待制のみ
システムは、一般ユーザーによる自己サインアップを無効化し、管理者が発行した招待経由でのみ新規アカウント作成を許可しなければならない(SHALL)。SMTPが設定されている場合、管理者が`/admin`パネルでメールアドレスを入力すると招待メールが自動送信されなければならない(SHALL)。SMTPが未設定の場合は、従来通り招待リンクが画面に表示され、管理者が手動で共有しなければならない(SHALL)。

#### Scenario: 自己サインアップは拒否される
- **WHEN** 未認証のユーザーが公開のサインアップ画面から新規アカウント作成を試みる
- **THEN** サインアップが無効化されており、アカウントは作成されない

#### Scenario: SMTP設定済みの場合、招待メールが自動送信される
- **WHEN** SMTPが設定された状態で、管理者が`/admin`パネルからメールアドレスを入力して招待する
- **THEN** 当該メールアドレス宛に招待メールが自動送信され、ユーザーはメール内のリンクから登録できる

#### Scenario: 招待メール経由の登録は成功する
- **WHEN** ユーザーが招待メール内のリンク(またはSMTP未設定時に手動共有された招待リンク)を使って登録する
- **THEN** アカウントが正常に作成される

### Requirement: データは専用ディスク上に永続化
システムは、Vaultwardenのデータ(SQLiteデータベース、RSA鍵、添付ファイル)をgcp-infrastructureで定義された専用永続ディスクのマウントパスに書き込まなければならない(SHALL)。

#### Scenario: コンテナ再起動後もデータが保持される
- **WHEN** vaultwardenコンテナが再起動される
- **THEN** 専用ディスクのマウントパスに保存されていたデータベースと添付ファイルがそのまま読み込まれる

### Requirement: ADMIN_TOKENによる管理パネル保護
システムは、Vaultwardenの`/admin`パネルへのアクセスに、Secret Manager由来のADMIN_TOKENの提示を要求しなければならない(SHALL)。コンテナに渡す`ADMIN_TOKEN`は平文ではなく、Argon2id PHC文字列としてハッシュ化された値でなければならない(SHALL)。Secret Manager上の値は運用者がログインに使う平文のまま保持し、平文からPHC文字列への変換はVM起動時に行わなければならない(SHALL)。

#### Scenario: 誤ったトークンでのアクセスは拒否される
- **WHEN** 誤った、または未指定のトークンで`/admin`にアクセスする
- **THEN** アクセスが拒否される

#### Scenario: 正しい平文トークンでのアクセスが許可される
- **WHEN** Secret Managerに保存されている平文トークンを`/admin`のログイン画面に入力する
- **THEN** コンテナ側ではArgon2ハッシュとの照合によって認証が成功し、管理パネルにアクセスできる

#### Scenario: コンテナ環境変数には平文トークンが存在しない
- **WHEN** vaultwardenコンテナの`ADMIN_TOKEN`環境変数を確認する
- **THEN** その値は平文ではなく`$argon2id$`から始まるPHC文字列である

### Requirement: 選択可能な2段階認証手段の制限
システムは、ユーザーが2段階認証(2FA)の手段として「メールアドレス」を選択できないようにしなければならない(SHALL)。ユーザーは「認証アプリ(TOTP)」「FIDO2 WebAuthn」「Duo Security」のいずれかを2段階認証の手段として選択できなければならない(SHALL)。

#### Scenario: メールアドレスは2FA手段として選択できない
- **WHEN** ユーザーがアカウント設定の2段階認証画面を開く
- **THEN** 「メールアドレス」は新規に有効化できる選択肢として表示されない

#### Scenario: TOTPは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「認証アプリ(TOTP)」を有効化する
- **THEN** TOTPが2段階認証の手段として正常に設定される

#### Scenario: FIDO2 WebAuthnは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「FIDO2 WebAuthn」を有効化する
- **THEN** FIDO2 WebAuthnが2段階認証の手段として正常に設定される

#### Scenario: Duo Securityは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「Duo Security」を有効化する(自分のDuoアカウントの認証情報を入力する)
- **THEN** Duo Securityが2段階認証の手段として正常に設定される

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

### Requirement: WebSocketによるライブ同期通知の正しい転送
システムは、`/notifications/hub`宛のWebSocket接続を、Vaultwardenのメインポート(80)を経由して転送しなければならない(SHALL)。Vaultwarden 1.29.0以降で廃止された専用WebSocketポート(3012)宛には転送してはならない(SHALL NOT)。

#### Scenario: ライブ同期通知が届く
- **WHEN** ログイン済みのクライアントが公開ドメイン経由でVaultwardenに接続し、Vault内のアイテムが別クライアントから変更される
- **THEN** WebSocket接続(`/notifications/hub`)経由でプッシュ通知が届き、変更中のクライアントが即座に同期される

#### Scenario: 廃止されたポートへは転送されない
- **WHEN** Caddyfileの設定を確認する
- **THEN** `vaultwarden:3012`(廃止された専用WebSocketポート)への`reverse_proxy`指定は存在しない
