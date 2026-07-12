## MODIFIED Requirements

### Requirement: ADMIN_TOKENによる管理パネル保護
システムは、Vaultwardenの`/admin`パネルへのアクセスに、Secret Manager由来のADMIN_TOKENの提示を要求しなければならない(SHALL)。コンテナに渡す`ADMIN_TOKEN`は平文ではなく、Argon2id PHC文字列としてハッシュ化された値でなければならない(SHALL)。Secret Manager上の値は運用者がログインに使う平文のまま保持し、平文からPHC文字列への変換はVM起動時に行わなければならない(SHALL)。

#### Scenario: 誤ったトークンでのアクセスは拒否される
- **WHEN** 誤った、または未指定のトークンで`/admin`にアクセスする
- **THEN** アクセスが拒否される

#### Scenario: 正しい平文トークンでのアクセスが許可される
- **WHEN** Secret Managerに保存されている平文トークンを`/admin`のログイン画面に入力する
- **THEN** コンテナ側ではArgon2ハッシュとの照合によって認証が成功し、管理パネルにアクセスできる

#### Scenario: コンテナ環境変数には平文トークンが存在しない
- **WHEN** vaultwardenコンテナの`ADMIN_TOKEN`環境変数を確認する
- **THEN** その値は平文ではなく`$argon2id$`から始まるPHC文字列である
