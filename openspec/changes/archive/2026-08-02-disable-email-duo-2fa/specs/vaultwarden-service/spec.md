## ADDED Requirements

### Requirement: 選択可能な2段階認証手段の制限
システムは、ユーザーが2段階認証(2FA)の手段として「メールアドレス」を選択できないようにしなければならない(SHALL)。ユーザーは「認証アプリ(TOTP)」「FIDO2 WebAuthn」「Duo Security」のいずれかを2段階認証の手段として選択できなければならない(SHALL)。

#### Scenario: メールアドレスは2FA手段として選択できない
- **WHEN** ユーザーがアカウント設定の2段階認証画面を開く
- **THEN** 「メールアドレス」は新規に有効化できる選択肢として表示されない

#### Scenario: TOTPは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「認証アプリ(TOTP)」を有効化する
- **THEN** TOTPが2段階認証の手段として正常に設定される

#### Scenario: FIDO2 WebAuthnは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「FIDO2 WebAuthn」を有効化する
- **THEN** FIDO2 WebAuthnが2段階認証の手段として正常に設定される

#### Scenario: Duo Securityは引き続き選択できる
- **WHEN** ユーザーがアカウント設定の2段階認証画面から「Duo Security」を有効化する(自分のDuoアカウントの認証情報を入力する)
- **THEN** Duo Securityが2段階認証の手段として正常に設定される
