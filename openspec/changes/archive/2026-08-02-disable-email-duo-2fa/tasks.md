## 1. 事前確認

- [x] 1.1 家族のうちメールアドレスを2FA手段として設定済みの人がいないか確認する(いる場合はTOTPまたはWebAuthnへの切り替えを依頼する) — 該当者なしを確認済み

## 2. 設定ファイルの変更

- [x] 2.1 `vaultwarden/docker-compose.yml` の `vaultwarden.environment` に `_ENABLE_EMAIL_2FA: "false"` と `_ENABLE_DUO: "false"` を追加する
- [x] 2.2 `vaultwarden/.env.example` にコメント等で今回の2FA制限方針を明記する(必要なら) — 不要と判断: `SIGNUPS_ALLOWED`/`WEBSOCKET_ENABLED`と同じく、この2値は環境に依存しない固定フラグなので`.env`経由ではなく`docker-compose.yml`に直接リテラルで書く既存パターンに合わせた

## 3. Terraform起動スクリプトの変更

- [x] 3.1 `terraform/main/templates/startup-script.sh.tftpl` が生成する `/opt/vaultwarden/.env` のヒアドキュメントに `_ENABLE_EMAIL_2FA=false` と `_ENABLE_DUO=false` を追加する — 不要と判断: 上記の通り`docker-compose.yml`に直接リテラルで書いたため、Terraform生成`.env`側の変更は不要(`SIGNUPS_ALLOWED`もこの`.env`には登場しない)

## 4. デプロイと検証(初回: メール+Duo無効化)

- [x] 4.1 変更をコミットし、PR #55経由でCI/CDでVMに反映する
- [x] 4.2 一般ユーザーの2段階認証設定画面を確認 — メールアドレスは選択肢から消えたが、Duo Securityは消えなかった(セルフサービス経路が塞がれないため)
- [x] 4.3 TOTPとFIDO2 WebAuthnがそれぞれ問題なく新規設定できることを確認する — 利用者により確認済み
- [x] 4.4 既存でTOTP/WebAuthnを使っているユーザーがログインできることを確認する(regressionがないか) — 利用者により確認済み

## 5. ドキュメント更新

- [x] 5.1 `openspec/specs/vaultwarden-service/spec.md` に本変更の要件がsyncされることを確認する(`/opsx:archive`実行時)

## 6. フォローアップ: Duo無効化のスコープ取り下げ

- [x] 6.1 `vaultwarden/docker-compose.yml` から `_ENABLE_DUO: "false"` を削除し、コメントをメールアドレスのみの説明に修正する
- [x] 6.2 proposal.md / design.md / specs/vaultwarden-service/spec.md をDuo取り下げに合わせて更新する
- [x] 6.3 変更をコミットし、PR #56を作成 — アーカイブ時点でPR #56はまだマージ待ち(利用者の判断でマージ状態に関わらずアーカイブを進める)
- [x] 6.4 一般ユーザーの2段階認証設定画面での最終確認 — 利用者により「動作確認はほぼできている」ことを確認済み
