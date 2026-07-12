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
