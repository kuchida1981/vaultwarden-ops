## 1. 事前確認

- [x] 1.1 家族のうちメールアドレスを2FA手段として設定済みの人がいないか確認する(いる場合はTOTPまたはWebAuthnへの切り替えを依頼する) — 該当者なしを確認済み

## 2. 設定ファイルの変更

- [x] 2.1 `vaultwarden/docker-compose.yml` の `vaultwarden.environment` に `_ENABLE_EMAIL_2FA: "false"` と `_ENABLE_DUO: "false"` を追加する
- [x] 2.2 `vaultwarden/.env.example` にコメント等で今回の2FA制限方針を明記する(必要なら) — 不要と判断: `SIGNUPS_ALLOWED`/`WEBSOCKET_ENABLED`と同じく、この2値は環境に依存しない固定フラグなので`.env`経由ではなく`docker-compose.yml`に直接リテラルで書く既存パターンに合わせた

## 3. Terraform起動スクリプトの変更

- [x] 3.1 `terraform/main/templates/startup-script.sh.tftpl` が生成する `/opt/vaultwarden/.env` のヒアドキュメントに `_ENABLE_EMAIL_2FA=false` と `_ENABLE_DUO=false` を追加する — 不要と判断: 上記の通り`docker-compose.yml`に直接リテラルで書いたため、Terraform生成`.env`側の変更は不要(`SIGNUPS_ALLOWED`もこの`.env`には登場しない)

## 4. デプロイと検証

- [ ] 4.1 変更をコミットし、CI/CD経由(またはTerraform適用・VM再起動)でVMに反映する
- [ ] 4.2 一般ユーザーの2段階認証設定画面を開き、「メールアドレス」「Duo Security」が選択肢に表示されないことを確認する
- [ ] 4.3 TOTPとFIDO2 WebAuthnがそれぞれ問題なく新規設定できることを確認する
- [ ] 4.4 既存でTOTP/WebAuthnを使っているユーザーがログインできることを確認する(regressionがないか)

## 5. ドキュメント更新

- [ ] 5.1 `openspec/specs/vaultwarden-service/spec.md` に本変更の要件がsyncされることを確認する(`/opsx:archive`実行時)
