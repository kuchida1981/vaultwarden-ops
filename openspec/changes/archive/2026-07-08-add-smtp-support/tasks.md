## 1. 事前準備(ユーザー作業)

- [x] 1.1 BrevoでSMTP用のログイン/SMTPキーを発行する(ホスト`smtp-relay.brevo.com`・ポート`587`を確認済み)
- [x] 1.2 送信専用の`SMTP_FROM`アドレス(`vaultwarden@u-rei.com`)と`SMTP_FROM_NAME`(`vaultwarden`)を決め、Brevoのsenderとして登録する
- [x] 1.3 SPFレコードの要否を確認する → Brevo利用時はEnvelope Fromに自社ドメインを使うため、u-rei.com側への追加は不要と判明(対応不要)
- [x] 1.4 (推奨・後回し) BrevoのSecurity → Authorized IPsに`terraform output vm_external_ip`の値を登録し、SMTPキーの送信元IP制限を有効化する。VMの静的IPと相性が良い追加の防御層(このchangeの必須要件ではない)(`34.84.31.142`を登録し有効化。設定後のメール送信も成功を確認済み)

## 2. Terraform: 変数とSecret Manager

- [x] 2.1 `terraform/main/variables.tf`にSMTP関連の変数を追加する: host/port/security/from/from_nameはデフォルト値付きの非sensitive変数(`smtp-relay.brevo.com`/`587`/`starttls`/`vaultwarden@u-rei.com`/`vaultwarden`)、username/passwordはデフォルトなしのsensitive変数
- [x] 2.2 `terraform/main/secrets.tf`にSMTPユーザー名・パスワード用のSecret Manager secret(`vaultwarden-smtp-username`, `vaultwarden-smtp-password`)を追加する
- [x] 2.3 `terraform/main/iam.tf`にVM実行時サービスアカウントへの新シークレット読み取り権限(`secretAccessor`)を追加する

## 3. Terraform: VM起動時の設定反映

- [x] 3.1 `terraform/main/compute.tf`のstartup-script呼び出しに、SMTPホスト/ポート/セキュリティ方式/Fromアドレス/From表示名(非機密)と、新シークレットID(username/password)を渡す
- [x] 3.2 `terraform/main/templates/startup-script.sh.tftpl`で新シークレットをfetchし、`.env`にSMTP関連の環境変数を追記する
- [x] 3.3 `compute.tf`の`depends_on`に新しいSecret Managerリソースを追加する(既存のadmin_token/tailscale_authkeyと同様)

## 4. docker-compose

- [x] 4.1 `vaultwarden/docker-compose.yml`のvaultwardenサービスにSMTP関連環境変数(`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_FROM_NAME`)を追加する

## 5. GitHub Secrets登録とapply

- [x] 5.1 `.github/workflows/terraform-plan.yml`・`terraform-apply.yml`に`TF_VAR_smtp_username`/`TF_VAR_smtp_password`を追加し、既存の`tailscale_oauth_client_id/secret`と同じ配線でGitHub Secretsから渡す(tasks.md未記載だった抜けを実装時に発見・追加)
- [x] 5.2 GitHub Actions Secretsに`BREVO_SMTP_USERNAME`・`BREVO_SMTP_PASSWORD`を登録する(ホスト/ポート/From等はterraform変数のデフォルト値で足りるため登録不要)
- [x] 5.3 PRを作成し`terraform plan`で差分を確認する(6 to add, 1 to change, 0 to destroyで想定通り。新規リソースのみで既存リソースの破壊的変更なしを確認)
- [x] 5.4 `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する
- [x] 5.5 VM上でvaultwardenコンテナが新しい環境変数で再作成されたことを確認する(`google_metadata_script_runner startup`でstartup-script再実行、`/admin`のSMTP設定欄に値が反映されていることを確認済み)

## 6. 動作確認

- [x] 6.1 `/admin`パネルから自分宛にテスト招待を送り、招待メールが実際に届くことを確認する(迷惑フォルダに入っていないかも確認)
- [x] 6.2 送信されたメールのヘッダーでSPF/DKIM/DMARCがすべてPASSしていることを確認する(dkim=pass header.s=brevo2, spf=pass(Brevo側ドメイン), dmarc=pass header.from=u-rei.comを確認済み)
- [x] 6.3 パスワードヒントメール・新規デバイスログイン通知など、他のメール系機能が動作することを確認する(いずれも確認済み)

## 7. README更新

- [x] 7.1 冒頭の「SMTPによるメール招待は導入しない方針」の記述を撤回する
- [x] 7.2 セットアップ手順(招待リンクの手動共有)を、メールアドレス入力による自動送信の内容に書き換える(番号は9に繰り下げ、BrevoでのSMTP設定を新たに手順3として追加したため後続を1つずつ繰り下げた)
- [x] 7.3 ロードマップからの記述整合を確認する(Organization復旧/Emergency Accessは別changeである旨を明記)
