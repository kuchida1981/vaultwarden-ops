## Why

これまで「SMTPは導入しない」方針でVaultwardenを運用してきたが、家族間の運用を続ける中で、招待リンクの手動共有(LINE等)の手間や、パスワードヒント・新規デバイスログインなどのメール通知が使えないことの不便さが上回るようになった。BrevoでSMTPリレーのドメイン認証(DKIM/DMARC)まで済ませており、SMTP基盤を導入する土台は整っている。

なお、Vaultwardenはゼロ知識暗号化のため、SMTP導入だけでは「マスターパスワードを完全に忘れた場合の復旧」は解決しない。それは別途Organization復旧機能・Emergency Access機能を必要とし、別changeで扱う。本changeはメール配信基盤そのものと、それによって実現できる範囲(招待メールの自動送信・通知・パスワードヒント)に限定する。

## What Changes

- BrevoのSMTPリレーをVaultwardenに設定し、送信専用アドレス(`u-rei.com`配下)からメールを送信できるようにする
- SMTP認証情報(ログイン・SMTPキー)を既存の`admin_token`/`tailscale_authkey`と同じパターンでGoogle Secret Managerに保管し、VM実行時サービスアカウントに最小権限(該当シークレットのみ`secretAccessor`)で読み取りを許可する
- SMTP認証情報はTerraformが生成せず外部(Brevo)から持ち込む値のため、`tailscale_oauth_client_id`/`_secret`と同じ経路(GitHub Secrets → sensitive変数 → Secret Manager)で受け渡す
- `docker-compose.yml`のvaultwardenサービスにSMTP関連環境変数(`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_USERNAME`/`SMTP_PASSWORD`/`SMTP_FROM`/`SMTP_FROM_NAME`)を追加する
- startup-scriptで新シークレットをfetchし、`.env`に書き込む
- **招待フローの変更**: `/admin`パネルからの招待が、これまでの「リンクを発行して手動でLINE等に共有」から「メールアドレスを入力すると招待メールが自動送信される」に変わる(招待制サインアップという方針自体は変わらない)
- README更新: 「SMTPは導入しない」の記述を撤回。招待手順(セットアップ手順8)を自動送信の内容に書き換え

## Capabilities

### New Capabilities
- `email-delivery`: Brevo SMTPリレーを用いたVaultwardenからのメール送信基盤(認証情報の管理、Vaultwarden側のSMTP設定)

### Modified Capabilities
- `vaultwarden-service`: 招待リンクの配信方法が、管理者による手動共有から、メールアドレス入力による自動メール送信に変わる(招待制サインアップというポリシー自体は不変)

## Impact

- `terraform/main/secrets.tf`: SMTP認証情報用のSecret Manager secretを追加
- `terraform/main/iam.tf`: VM実行時サービスアカウントへの新シークレットの読み取り権限を追加
- `terraform/main/variables.tf`: SMTP関連のsensitive変数(ホスト/ポート/ユーザー名/パスワード/From)を追加
- `terraform/main/compute.tf`, `terraform/main/templates/startup-script.sh.tftpl`: 新シークレットのfetchと`.env`書き込みを追加
- `vaultwarden/docker-compose.yml`: SMTP関連環境変数を追加
- `README.md`: SMTP方針の記述撤回、SPFレコード追加の前提作業の明記、招待手順の書き換え
- GitHub Actions Secrets: `BREVO_SMTP_USERNAME`・`BREVO_SMTP_PASSWORD`の新規登録が必要(ユーザーの手動作業)
- 前提作業(ユーザー側): BrevoでSMTP用ログイン/キーを発行し、送信元アドレス`vaultwarden@u-rei.com`をBrevoのsenderとして登録済み。DKIM(CNAME委任)・DMARC(`p=none`)も設定済みで確認済み。SPFはBrevoがEnvelope Fromに自社ドメイン(`bounces.brevo.com`等)を使うためu-rei.com側への追加は不要と判明(Brevoのドメイン認証画面にSPFの項目が表示されないのはこのため)
