## Context

Vaultwardenは2段階認証(2FA)の手段としてメールアドレス・TOTP・FIDO2 WebAuthn・Duo Securityの4つをサポートしている。メールアドレスの有効/無効は環境変数`_ENABLE_EMAIL_2FA`で制御でき、サーバー側の有効化エンドポイント(`send_email_login`/`send_email`)がこのフラグを直接チェックして拒否するため、確実に無効化できる。

Duo Securityにも同様に`_ENABLE_DUO`という環境変数が存在するが、実装過程で調査した結果(v1.37.0のソースコード)、これは管理者が全ユーザー共有で設定する「グローバルDuo認証情報」の有効/無効のみを制御するものだった。`src/config.rs`のduo設定ブロックには`/// Global Duo settings (Note that users can override them)`というコメントがあり、実際の有効化エンドポイント`activate_duo`(`src/api/core/two_factor/duo.rs`)はこのフラグを一切参照せず、ユーザーが自分のDuoアカウントの`host`/`client_id`/`client_secret`を入力すれば無条件で有効化を受け付ける。つまりVaultwarden単体の設定ではDuo Securityを選択肢から完全に排除できない。この事実が判明した時点で、Duo Securityの無効化はスコープから取り下げた。

本インスタンスは自分+家族用のセルフホスト環境。メールアドレスはメールボックス自体が攻撃対象になりうるため、他の手段より強度が劣ると判断している。

## Goals / Non-Goals

**Goals:**
- メールアドレスを、ユーザーが新規に2FA手段として選択できないようにする
- TOTP・FIDO2 WebAuthn・Duo Securityは引き続き問題なく選択・利用できる状態を維持する
- 変更を`docker-compose.yml`に一貫して反映する

**Non-Goals:**
- Duo Securityを2FA手段の選択肢から排除すること(Vaultwarden側にその手段がないため取り下げ。将来やる場合はCaddyで`/api/two-factor/duo*`ルートを遮断する設計が必要になる — 別changeで検討)
- 2FA設定自体をユーザーに強制すること(別途検討済み、今回のスコープ外)
- 既にメールアドレスを2FA手段として設定済みのユーザーの設定を強制的に解除すること(該当者なしを確認済みだが、仮にいた場合も無効化後に既存設定は残る仕様)
- Organization機能の導入(本リポジトリでは別スコープとして扱われている)

## Decisions

### 環境変数による無効化(admin panel経由の設定変更ではなくIaCに反映)
`_ENABLE_EMAIL_2FA=false` を、Vaultwardenの `/admin` パネルから都度設定するのではなく、`docker-compose.yml` の `environment:` に直接書き込む。

理由: このリポジトリは全てのVaultwarden設定をIaC(Terraform + docker-compose.yml)で管理する方針を既に取っており、admin panel経由の手動設定はVM再作成時に失われる。`SIGNUPS_ALLOWED`/`WEBSOCKET_ENABLED`と同じく、環境に依存しない固定フラグは`docker-compose.yml`に直接リテラルで書く既存パターンに合わせているため、Terraform生成`.env`や`.env.example`への追加は不要。

### Duo Securityの無効化は取り下げ(Vaultwardenにセルフサービス経路を塞ぐ手段がない)
`_ENABLE_DUO=false`はグローバルDuo認証情報の無効化にしかならず、ユーザー個人のDuoアカウント紐付け(セルフサービス経路)は塞げないことがソースコード調査で判明した。完全に無効化するにはCaddyで`POST /api/two-factor/get-duo`・`POST /api/two-factor/duo`・`PUT /api/two-factor/duo`を403にする必要があり(`vaultwarden/Caddyfile`の`/admin*`ブロックと同じパターンで実装可能)、技術的には可能だが、今回はこの追加実装までは行わない判断とした。

## Risks / Trade-offs

- [Duo Securityは引き続き選択可能なまま] → セキュリティ上の懸念自体は残るが、有効化には外部のDuoアカウント取得と個人でのアプリケーション登録が必要なため、家族が偶発的に有効化するリスクは低いと判断
- [Vaultwardenコンテナの再起動が必要] → `docker compose up -d` の再適用で反映されるため、ダウンタイムは通常のデプロイと同程度で収まる
- [将来メールアドレスを使いたくなった場合、再度有効化が必要] → 環境変数を戻すだけで復旧可能なため、可逆性は高い

## Migration Plan

1. `vaultwarden/docker-compose.yml` から `_ENABLE_DUO: "false"` を削除し、コメントをメールアドレスのみの説明に修正する
2. `vaultwarden-deploy.yml`(承認ゲート付き)経由でVMに反映する
3. 一般ユーザーの2段階認証設定画面で、メールアドレスが選択肢から消えたまま・Duo Securityが選択肢に戻っていることを確認する

ロールバックは`_ENABLE_EMAIL_2FA`を削除(またはtrueに戻す)して再デプロイするだけで完了する。
