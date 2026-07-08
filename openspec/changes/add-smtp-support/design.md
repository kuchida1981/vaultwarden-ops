## Context

現在のVaultwardenは`SIGNUPS_ALLOWED=false`で、`/admin`パネルから発行した招待リンクを管理者が手動でLINE等に共有する運用になっている(SMTP完全未設定)。機密情報の扱いは既に確立したパターンがある: `ADMIN_TOKEN`とTailscale認証キーはGoogle Secret Managerに保管し、VM実行時サービスアカウントに該当シークレットのみの`secretAccessor`権限を与え、startup-scriptがメタデータサーバー経由の一時アクセストークンでSecret Manager APIから取得して`.env`に書き込む(`terraform/main/secrets.tf`, `iam.tf`, `templates/startup-script.sh.tftpl`)。一方、Terraform自体が生成しない外部発行の認証情報(Tailscale OAuthクライアント)は、GitHub Secrets → sensitiveなTerraform変数、という別経路で受け渡している。

BrevoではドメインのDKIM(CNAME委任方式、`brevo1._domainkey`/`brevo2._domainkey`)とDMARC(`p=none`)の認証が完了しており、CNAMEチェーンをたどってDKIM公開鍵が実際に解決できることを確認済み。SPFはu-rei.comのDNSには存在しないが、これは設定漏れではなく不要というのが正しい理解: BrevoはEnvelope From(Return-Path)に`bounces.brevo.com`等の自社ドメインを使うため、SPFチェックはBrevo側のドメインに対して行われ、送信元ドメイン(u-rei.com)側にSPFレコードを追加する必要がない。BrevoのDomain Configuration画面にSPFの項目自体が表示されないのはこのため。

SMTP用のログイン/キーはBrevo側で発行済み(ホスト`smtp-relay.brevo.com`、ポート`587`)。送信元アドレス`vaultwarden@u-rei.com`(表示名`vaultwarden`)はBrevoのsenderとして登録済み。

## Goals / Non-Goals

**Goals:**
- Brevo SMTPリレー経由でVaultwardenからメールを送信できるようにする
- 招待メールを`/admin`パネルからの自動送信に切り替える
- 既存のSecret Manager最小権限パターンをそのまま踏襲し、新しい信頼境界を作らない
- VMメタデータ(startup-script)に機密値を直接埋め込まない、という既存原則を維持する

**Non-Goals:**
- マスターパスワードを完全に忘れた場合の保管庫復旧(Organization Account Recovery / Emergency Access)は別changeで扱う。本changeはメール配信基盤のみ
- メール送達失敗の監視・アラートは範囲外(既存のロードマップ方針: 稼働監視は別スコープ)を踏襲する
- `SIGNUPS_ALLOWED`(自己サインアップ)は変更しない。招待制ポリシー自体は不変

## Decisions

**1. SMTP認証情報の受け渡し経路は`tailscale_oauth_client_id/secret`パターンを踏襲する**
Brevoが発行する値はTerraformが生成できないため、`random_password`で生成する`admin_token`とは異なる経路が必要。GitHub Secrets → sensitiveなTerraform変数、として受け取る。
代替案: Brevo APIをTerraformプロバイダ経由で叩いてSMTPキーを自動発行する案も検討したが、公式のBrevo Terraformプロバイダは存在せずAPI直叩きは複雑さに見合わないため却下。

**2. SMTP_USERNAME・SMTP_PASSWORDは両方ともSecret Manager経由にする(startup-scriptテンプレートへ直接埋め込まない)**
`SMTP_HOST`/`SMTP_PORT`/`SMTP_SECURITY`/`SMTP_FROM`/`SMTP_FROM_NAME`は機密性がないため`domain`/`github_repo`と同様にstartup-scriptテンプレート変数として直接埋め込む。値が既に確定しているため(`smtp-relay.brevo.com` / `587` / STARTTLS / `vaultwarden@u-rei.com` / `vaultwarden`)、`variables.tf`では`domain`変数と同様にこれらをデフォルト値付きの非sensitive変数として定義する(公開リポジトリにコミットして問題ない情報のため)。

一方`SMTP_USERNAME`(Brevoが発行するSMTPログイン)と`SMTP_PASSWORD`(SMTPキー)は資格情報のペアであり、`ADMIN_TOKEN`と同水準の秘匿性として扱う。ユーザー名単体の機密性は低いが、資格情報ペアを異なる信頼境界(平文メタデータとSecret Manager)に分割すると扱いが分かりづらくなるため、両方ともデフォルト値なしのsensitive変数とし、GitHub Secrets経由でSecret Managerに保管する(`vaultwarden-smtp-username`, `vaultwarden-smtp-password`の2つ、既存の1secret=1値パターンを踏襲)。

**3. 招待メール送信はVaultwarden標準機能をそのまま使う(追加のフラグ制御は不要)**
Vaultwardenは`SMTP_HOST`が設定されていれば、管理者が`/admin`パネルでユーザーを招待する際に自動的にメール送信する(未設定時はリンク表示のみ)。挙動を切り替えるための追加の環境変数は不要。`INVITATIONS_ALLOWED`はデフォルト(true)のまま変更しない。

## Risks / Trade-offs

- [Brevo無料枠のレート制限(目安: 300通/日)] → 家族数名規模の通知・招待メール量なら十分に収まる想定。監視は範囲外なので、上限到達に気づく仕組みは今回作らない(将来問題になれば別途対応)。
- [VMメタデータ(startup-script)はプロジェクトの読み取り権限を持つ全員が閲覧可能] → 既存原則通り、機密値(SMTP_USERNAME/PASSWORD)は絶対にテンプレート変数として埋め込まず、Secret Manager経由のfetchのみで扱う。
- [Terraform stateにsensitive変数の値が平文で残る] → 既存の`tailscale_oauth_client_secret`と同水準のリスクであり、GCSリモートバックエンド+アクセス制御という既存の緩和策の範囲内として許容する。新たな対策は追加しない。

## Migration Plan

1. (ユーザー作業・完了) BrevoでSMTP用ログイン/SMTPキーを発行し、送信元アドレスをsenderとして登録済み
2. (ユーザー作業) GitHub Actions SecretsにSMTPユーザー名・パスワードを登録する
3. terraform/mainへの変更をPRで作成し、`terraform plan`で差分を確認する
4. `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する
5. 既存VMは次回起動(またはstartup-script再実行)時に新しい`.env`を反映し、`docker compose up -d`が環境変数の変更を検知してvaultwardenコンテナを再作成する。VM自体の再作成やデータディスクへの影響はない
6. ロールバック: SMTP関連のTerraform変数を空にして再apply(またはPRをrevert)すれば、Vaultwarden側はSMTP未設定状態(招待は再びリンク表示のみ)に戻る。データの巻き戻しは発生しない

## Open Questions

- なし。`SMTP_FROM`/`SMTP_FROM_NAME`は`vaultwarden@u-rei.com`/`vaultwarden`に確定済み。Brevo無料枠超過時の挙動は「Non-Goals」の通り監視対象外として扱う
