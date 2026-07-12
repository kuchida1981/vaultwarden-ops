## Why

`/admin`を開くと、Vaultwardenが「平文の`ADMIN_TOKEN`を使っている、安全でない」という警告を表示する。現状はSecret Managerに保存した平文トークンをそのままコンテナの`ADMIN_TOKEN`環境変数に渡しており、`.env`ファイルの読み取りやコンテナ環境の露出など何らかの経路でこの値が漏れると、攻撃者は追加の労力なしに即座に管理パネルへログインできてしまう。Vaultwardenは`ADMIN_TOKEN`にArgon2 PHC文字列(ハッシュ)を渡すことをサポートしており、この形式にすればトークンが漏れても即ログインには使えなくなる。

## What Changes

- VM起動時(`startup-script.sh.tftpl`)に`argon2`パッケージを追加インストールする
- `.env`生成時、Secret Managerから取得した平文`ADMIN_TOKEN`をランダムsaltでArgon2id PHC文字列にハッシュ化してから書き込む(Vaultwarden自身の`vaultwarden hash`が使うデフォルトパラメータ`m=65540,t=3,p=4`に合わせる)
- Secret Manager(`vaultwarden-admin-token`)の値は平文のまま変更しない。運用者はこれまで通りSecret Managerから平文を取得して`/admin`ログインに使う
- ハッシュは起動のたびに新しいsaltで再生成される(同じ平文から生成しても`.env`の値自体は毎回変わる)ため、`docker compose up -d`が再起動のたびにvaultwardenコンテナを再作成する可能性がある(機能的な影響はない)

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `vaultwarden-service`: 「ADMIN_TOKENによる管理パネル保護」要件を、平文トークンではなくArgon2ハッシュ済みトークンをコンテナに渡す方式に変更する

## Impact

- `terraform/main/templates/startup-script.sh.tftpl`: `.env`生成ロジックにハッシュ化ステップを追加、`argon2`パッケージのインストールを追加
- `terraform/main/secrets.tf`: 変更なし(平文のまま。コメントの「ハードニングを検討」という記述は解消される)
- `vaultwarden/docker-compose.yml`: 変更なし(`ADMIN_TOKEN: ${ADMIN_TOKEN}`という変数参照のまま)
- 運用者のログイン手順: 変更なし(Secret Managerから平文を取得してログインする点は同じ)
