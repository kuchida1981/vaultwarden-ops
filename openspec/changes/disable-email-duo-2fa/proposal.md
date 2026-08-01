## Why

Vaultwardenは2段階認証の手段としてメールアドレス・認証アプリ(TOTP)・FIDO2 WebAuthn・Duo Securityの4つを提供しているが、このうちメールアドレスはセキュリティ強度が他の手段より弱く(受信メールボックス自体が攻撃対象になりうる)、Duo Securityは外部サービスへの登録が必要な上に本インスタンスでは運用する予定がない。この2つを選択肢から外し、TOTPとFIDO2 WebAuthnのみに絞ることで、家族が選べる2FA手段を実際に運用する手段だけに限定する。

## What Changes

- Vaultwardenコンテナの環境変数に `_ENABLE_EMAIL_2FA=false` を追加し、メールアドレスを2FA手段の選択肢から除外する
- Vaultwardenコンテナの環境変数に `_ENABLE_DUO=false` を追加し、Duo Securityを2FA手段の選択肢から除外する(ユーザーが個人のDuoアカウントを自分で紐付けるセルフサービス経路も含めて無効化)
- `vaultwarden/docker-compose.yml`、`terraform/main/templates/startup-script.sh.tftpl` が生成する `.env`、`vaultwarden/.env.example` の3箇所に反映する

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `vaultwarden-service`: 選択可能な2段階認証手段を制限する要件を追加する(メールアドレスとDuo Securityを無効化し、TOTPとFIDO2 WebAuthnのみ選択可能にする)

## Impact

- **設定ファイル**: `vaultwarden/docker-compose.yml`(environment追加)、`vaultwarden/.env.example`(ドキュメント更新)
- **Terraform**: `terraform/main/templates/startup-script.sh.tftpl`(生成する`.env`に環境変数追加)
- **既存ユーザーへの影響**: 既にメールアドレスを2FA手段として設定済みのユーザーがいる場合、設定自体は残る(新規選択のみ不可になる)。対象者がいれば事前確認が必要
- **破壊的変更ではない**: 新規デプロイ・既存デプロイともに `docker compose up -d` の再適用(またはTerraform経由のVM再起動)で反映される
