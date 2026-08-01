## Why

Vaultwardenは2段階認証の手段としてメールアドレス・認証アプリ(TOTP)・FIDO2 WebAuthn・Duo Securityの4つを提供しているが、このうちメールアドレスはセキュリティ強度が他の手段より弱い(受信メールボックス自体が攻撃対象になりうる)。これを選択肢から外し、TOTP・FIDO2 WebAuthn・Duo Securityの3手段に絞ることで、家族が選べる2FA手段からセキュリティ強度の劣る選択肢を除く。

Duo Securityについても当初は選択肢から除外する方向で検討したが、実装過程でVaultwarden(v1.37.0)の`_ENABLE_DUO`環境変数は管理者が全ユーザー共有で設定する「グローバルDuo認証情報」の有効/無効のみを制御し、ユーザーが自分のDuoアカウントを個別に紐付けるセルフサービス経路(`activate_duo`エンドポイント)は一切ゲートしないことが判明した(ソース: `src/api/core/two_factor/duo.rs`、`src/config.rs`のコメント「Global Duo settings (Note that users can override them)」)。Vaultwarden単体の設定だけではDuoを選択肢から完全に排除できないため、Duo Securityの除外は本changeのスコープから取り下げる。

## What Changes

- Vaultwardenコンテナの環境変数に `_ENABLE_EMAIL_2FA=false` を追加し、メールアドレスを2FA手段の選択肢から除外する
- `vaultwarden/docker-compose.yml` に反映する(固定フラグのためTerraform生成`.env`や`.env.example`への追加は不要)
- **スコープ外(取り下げ)**: Duo Securityの無効化。Vaultwarden側にセルフサービスDuoを完全に無効化する設定手段が存在しないため。完全にブロックするにはCaddyで`/api/two-factor/duo*`ルートを遮断する必要があるが、今回はそこまでは行わない

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `vaultwarden-service`: 選択可能な2段階認証手段を制限する要件を追加する(メールアドレスのみ無効化し、TOTP・FIDO2 WebAuthn・Duo Securityは引き続き選択可能)

## Impact

- **設定ファイル**: `vaultwarden/docker-compose.yml`(environment追加、既存の`_ENABLE_DUO: "false"`は削除)
- **既存ユーザーへの影響**: 既にメールアドレスを2FA手段として設定済みのユーザーはいないことを確認済み
- **破壊的変更ではない**: `docker compose up -d` の再適用で反映される
- **本番環境の状態**: 本changeは既に一度(メール・Duo両方の無効化として)マージ・デプロイ済み。本更新はDuo無効化部分のみを取り消すフォローアップ
