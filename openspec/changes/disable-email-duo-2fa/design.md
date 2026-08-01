## Context

Vaultwardenは2段階認証(2FA)の手段としてメールアドレス・TOTP・FIDO2 WebAuthn・Duo Securityの4つをサポートしている。このうちメールアドレスとDuo Securityの有効/無効は、それぞれ独立した環境変数(先頭にアンダースコアが付く命名: `_ENABLE_EMAIL_2FA`, `_ENABLE_DUO`)で制御でき、TOTPとFIDO2 WebAuthnには個別の無効化トグルが存在しない(常に選択可能)。

本インスタンスは自分+家族用のセルフホスト環境で、Duo Securityの外部連携(DUO_IKEY等)は現状一切設定されておらず、運用予定もない。メールアドレスはメールボックス自体が攻撃対象になりうるため、他の2手段より強度が劣ると判断している。

## Goals / Non-Goals

**Goals:**
- メールアドレスとDuo Securityを、ユーザーが新規に2FA手段として選択できないようにする
- TOTPとFIDO2 WebAuthnは引き続き問題なく選択・利用できる状態を維持する
- 変更をdocker-compose.yml・Terraform起動スクリプト・.env.exampleの3箇所に一貫して反映する

**Non-Goals:**
- 2FA設定自体をユーザーに強制すること(別途検討済み、今回のスコープ外)
- 既にメールアドレスを2FA手段として設定済みのユーザーの設定を強制的に解除すること(Vaultwarden側の挙動として、無効化後も既存設定は残る)
- Organization機能の導入(本リポジトリでは別スコープとして扱われている)

## Decisions

### 環境変数による無効化(admin panel経由の設定変更ではなくIaCに反映)
`_ENABLE_EMAIL_2FA=false` と `_ENABLE_DUO=false` を、Vaultwardenの `/admin` パネルから都度設定するのではなく、`docker-compose.yml` の `environment:` とTerraformが生成する `.env` に直接書き込む。

理由: このリポジトリは全てのVaultwarden設定をIaC(Terraform + docker-compose.yml)で管理する方針を既に取っており(`SIGNUPS_ALLOWED`, `ADMIN_TOKEN`等も同様)、admin panel経由の手動設定はVM再作成時に失われる。設定の一貫性・再現性のため既存パターンに合わせる。

代替案として検討したが採用しなかったもの: admin panelの「Settings」から都度トグルする方式。VM再作成(ディスクは永続化されるが、config.jsonがdataディレクトリに保存されるかは別途確認が必要)のたびに手動操作が必要になるリスクがあり却下。

### Duoは`_ENABLE_DUO`のみで十分(DUO_*シークレットの追加不要)
Duo Securityのグローバル連携用シークレット(`DUO_IKEY`, `DUO_SKEY`, `DUO_HOST`)は元々設定されていない。`_ENABLE_DUO=false` を設定するだけで、管理者側の連携有無に関わらずユーザー個人のDuoアカウント紐付け(セルフサービス経路)も含めて無効化される。

## Risks / Trade-offs

- [既存ユーザーがメールアドレスを2FA手段として設定済みの場合、無効化後も設定は残る] → 実装前に家族に「メールアドレスを2FA手段にしているか」確認する。該当者がいれば、無効化後に本人にTOTPまたはWebAuthnへの切り替えを依頼する
- [Vaultwardenコンテナの再起動が必要] → `docker compose up -d` の再適用(またはTerraform経由のVM再起動時に自動生成される`.env`経由)で反映されるため、ダウンタイムは通常のデプロイと同程度で収まる
- [将来Duoを使いたくなった場合、再度有効化が必要] → 環境変数を戻すだけで復旧可能なため、可逆性は高い

## Migration Plan

1. 家族に現在の2FA設定状況(特にメールアドレスを使っているか)を確認する
2. `vaultwarden/docker-compose.yml` と `vaultwarden/.env.example` に環境変数を追加する
3. `terraform/main/templates/startup-script.sh.tftpl` の生成する`.env`に環境変数を追加する
4. Terraform適用(またはVM再起動によるstartup-script再実行)でVM側の`.env`を更新し、`docker compose up -d`でコンテナに反映する
5. `/admin`パネルまたは一般ユーザーの2FA設定画面で、メールアドレス・Duo Securityが選択肢から消えていることを確認する

ロールバックは環境変数を削除(またはtrueに戻す)して再デプロイするだけで完了する。
