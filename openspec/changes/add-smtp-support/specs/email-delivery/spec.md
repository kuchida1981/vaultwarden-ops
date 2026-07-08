## ADDED Requirements

### Requirement: Brevo SMTPリレー経由のメール送信
システムは、Brevoが提供するSMTPリレーを通じてVaultwardenからメール(招待・通知・パスワードヒント等)を送信できなければならない(SHALL)。送信元アドレスは送信専用として扱い、受信は想定しない。

#### Scenario: SMTP設定済みの状態でVaultwardenが起動する
- **WHEN** SMTP関連環境変数(`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_FROM_NAME`)が設定された状態でvaultwardenコンテナが起動する
- **THEN** VaultwardenはBrevoのSMTPリレーへの接続に成功し、以降のメール送信機能(招待・通知等)が有効になる

### Requirement: SMTP認証情報はSecret Managerで最小権限管理
システムは、SMTPのユーザー名・パスワード(Brevoが発行するSMTPキー)をGoogle Secret Managerに保管しなければならない(SHALL)。VM実行時サービスアカウントは、既存の`ADMIN_TOKEN`・Tailscale認証キーと同様に、これら該当シークレットに対する`roles/secretmanager.secretAccessor`のみを持ち、他のシークレットへのアクセスや書き込み権限を持ってはならない(SHALL NOT)。SMTPホスト・ポート・送信元アドレスなど機密性のない設定値は、Secret Manager経由にせずVM起動時のメタデータテンプレート変数として渡してよい。

#### Scenario: VM実行時SAがSMTP認証情報を読み取れる
- **WHEN** VMの実行時サービスアカウントがSMTPユーザー名・パスワードのシークレットバージョンにアクセスする
- **THEN** アクセスに成功し、平文の値が取得できる

#### Scenario: SMTP認証情報がVMメタデータに平文で残らない
- **WHEN** VMのstartup-scriptメタデータ(`gcloud compute instances describe`等で参照可能な内容)を確認する
- **THEN** SMTPユーザー名・パスワードの値はテンプレート変数として直接埋め込まれておらず、Secret Manager経由でのみ取得される

### Requirement: SMTP認証情報はTerraform変数として外部から受け渡す
システムは、Brevoが発行するSMTP認証情報をTerraformでは生成せず、GitHub Actions Secrets経由のsensitiveなTerraform変数として受け渡さなければならない(SHALL)。

#### Scenario: GitHub Secrets未設定のままではapplyが失敗する
- **WHEN** SMTPユーザー名・パスワードに対応するGitHub Actions Secretsが未設定のまま`terraform apply`が実行される
- **THEN** 必須変数が指定されていないためTerraformがエラーで停止し、不完全な状態のリソースは作成されない
