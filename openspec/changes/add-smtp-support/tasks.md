## 1. 事前準備(ユーザー作業)

- [x] 1.1 BrevoでSMTP用のログイン/SMTPキーを発行する(ホスト`smtp-relay.brevo.com`・ポート`587`を確認済み)
- [x] 1.2 送信専用の`SMTP_FROM`アドレス(`vaultwarden@u-rei.com`)と`SMTP_FROM_NAME`(`vaultwarden`)を決め、Brevoのsenderとして登録する
- [x] 1.3 SPFレコードの要否を確認する → Brevo利用時はEnvelope Fromに自社ドメインを使うため、u-rei.com側への追加は不要と判明(対応不要)

## 2. Terraform: 変数とSecret Manager

- [ ] 2.1 `terraform/main/variables.tf`にSMTP関連の変数を追加する: host/port/security/from/from_nameはデフォルト値付きの非sensitive変数(`smtp-relay.brevo.com`/`587`/`starttls`/`vaultwarden@u-rei.com`/`vaultwarden`)、username/passwordはデフォルトなしのsensitive変数
- [ ] 2.2 `terraform/main/secrets.tf`にSMTPユーザー名・パスワード用のSecret Manager secret(`vaultwarden-smtp-username`, `vaultwarden-smtp-password`)を追加する
- [ ] 2.3 `terraform/main/iam.tf`にVM実行時サービスアカウントへの新シークレット読み取り権限(`secretAccessor`)を追加する

## 3. Terraform: VM起動時の設定反映

- [ ] 3.1 `terraform/main/compute.tf`のstartup-script呼び出しに、SMTPホスト/ポート/セキュリティ方式/Fromアドレス/From表示名(非機密)と、新シークレットID(username/password)を渡す
- [ ] 3.2 `terraform/main/templates/startup-script.sh.tftpl`で新シークレットをfetchし、`.env`にSMTP関連の環境変数を追記する
- [ ] 3.3 `compute.tf`の`depends_on`に新しいSecret Managerリソースを追加する(既存のadmin_token/tailscale_authkeyと同様)

## 4. docker-compose

- [ ] 4.1 `vaultwarden/docker-compose.yml`のvaultwardenサービスにSMTP関連環境変数(`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_FROM_NAME`)を追加する

## 5. GitHub Secrets登録とapply

- [ ] 5.1 GitHub Actions SecretsにSMTPユーザー名・パスワードを登録する(ホスト/ポート/From等はterraform変数のデフォルト値で足りるため登録不要)
- [ ] 5.2 PRを作成し`terraform plan`で差分を確認する(新規リソースのみで既存リソースの破壊的変更が無いことを確認)
- [ ] 5.3 `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する
- [ ] 5.4 VM上でvaultwardenコンテナが新しい環境変数で再作成されたことを確認する

## 6. 動作確認

- [ ] 6.1 `/admin`パネルから自分宛にテスト招待を送り、招待メールが実際に届くことを確認する(迷惑フォルダに入っていないかも確認)
- [ ] 6.2 送信されたメールのヘッダーでSPF/DKIM/DMARCがすべてPASSしていることを確認する
- [ ] 6.3 パスワードヒントメール・新規デバイスログイン通知など、他のメール系機能が動作することを確認する

## 7. README更新

- [ ] 7.1 冒頭の「SMTPによるメール招待は導入しない方針」の記述を撤回する
- [ ] 7.2 セットアップ手順8(招待リンクの手動共有)を、メールアドレス入力による自動送信の内容に書き換える
- [ ] 7.3 ロードマップからの記述整合を確認する(Organization復旧/Emergency Accessは別changeである旨がわかるようにする)
