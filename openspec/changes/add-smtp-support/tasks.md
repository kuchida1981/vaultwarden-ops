## 1. 事前準備(ユーザー作業、terraform適用前に完了させる)

- [ ] 1.1 BrevoでSMTP用のログイン/SMTPキーを発行する(アカウントログインとは別物であることを確認する)
- [ ] 1.2 BrevoのSPF指定値をu-rei.comのDNSにTXTレコードとして追加する(既存のSPFレコードがあれば上書きせずマージする)
- [ ] 1.3 送信専用の`SMTP_FROM`アドレス(u-rei.com配下)と`SMTP_FROM_NAME`の表示名を決める

## 2. Terraform: 変数とSecret Manager

- [ ] 2.1 `terraform/main/variables.tf`にSMTP関連のsensitive変数(host/port/security/username/password/from/from_name)を追加する
- [ ] 2.2 `terraform/main/secrets.tf`にSMTPユーザー名・パスワード用のSecret Manager secret(`vaultwarden-smtp-username`, `vaultwarden-smtp-password`)を追加する
- [ ] 2.3 `terraform/main/iam.tf`にVM実行時サービスアカウントへの新シークレット読み取り権限(`secretAccessor`)を追加する

## 3. Terraform: VM起動時の設定反映

- [ ] 3.1 `terraform/main/compute.tf`のstartup-script呼び出しに、SMTPホスト/ポート/セキュリティ方式/Fromアドレス/From表示名(非機密)と、新シークレットID(username/password)を渡す
- [ ] 3.2 `terraform/main/templates/startup-script.sh.tftpl`で新シークレットをfetchし、`.env`にSMTP関連の環境変数を追記する
- [ ] 3.3 `compute.tf`の`depends_on`に新しいSecret Managerリソースを追加する(既存のadmin_token/tailscale_authkeyと同様)

## 4. docker-compose

- [ ] 4.1 `vaultwarden/docker-compose.yml`のvaultwardenサービスにSMTP関連環境変数(`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_FROM_NAME`)を追加する

## 5. GitHub Secrets登録とapply

- [ ] 5.1 GitHub Actions SecretsにSMTP関連の新しい値を登録する
- [ ] 5.2 PRを作成し`terraform plan`で差分を確認する(新規リソースのみで既存リソースの破壊的変更が無いことを確認)
- [ ] 5.3 `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する
- [ ] 5.4 VM上でvaultwardenコンテナが新しい環境変数で再作成されたことを確認する

## 6. 動作確認

- [ ] 6.1 `/admin`パネルから自分宛にテスト招待を送り、招待メールが実際に届くことを確認する(迷惑フォルダに入っていないかも確認)
- [ ] 6.2 送信されたメールのヘッダーでSPF/DKIM/DMARCがすべてPASSしていることを確認する
- [ ] 6.3 パスワードヒントメール・新規デバイスログイン通知など、他のメール系機能が動作することを確認する

## 7. README更新

- [ ] 7.1 冒頭の「SMTPによるメール招待は導入しない方針」の記述を撤回する
- [ ] 7.2 SPFレコード追加を前提作業としてセットアップ手順に明記する
- [ ] 7.3 セットアップ手順8(招待リンクの手動共有)を、メールアドレス入力による自動送信の内容に書き換える
- [ ] 7.4 ロードマップからの記述整合を確認する(Organization復旧/Emergency Accessは別changeである旨がわかるようにする)
