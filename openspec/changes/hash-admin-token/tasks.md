## 1. startup-script: ハッシュ化ロジックの追加

- [ ] 1.1 `terraform/main/templates/startup-script.sh.tftpl`の`apt-get install`リストに`argon2`パッケージを追加する
- [ ] 1.2 `.env`生成部分で、`fetch_secret`で取得した平文`ADMIN_TOKEN`をそのまま書き込む代わりに、`openssl rand -hex 16`等でランダムsaltを生成し、`argon2`コマンド(`-e -id -m 16 -t 3 -p 4`、Vaultwarden公式の"bitwardenプリセット"に相当するパラメータ)でArgon2id PHC文字列に変換してから`ADMIN_TOKEN=`として書き込むよう変更する

## 2. Terraform plan確認とapply

- [ ] 2.1 PRを作成し`terraform plan`を実行、`compute.tf`のmetadata(startup-script)のみが差分として出ることを確認する(Secret Manager等の既存リソースに破壊的変更がないこと)
- [ ] 2.2 マージ後、`terraform apply`を実行する

## 3. 稼働中VMへの反映

- [ ] 3.1 `gcloud compute instances add-metadata`でstartup-scriptの新しいメタデータが反映されていることを確認する(`terraform apply`で自動的に反映されるはずだが、念のため実機で確認する)
- [ ] 3.2 `google_metadata_script_runner startup`でstartup-scriptを再実行する(既存`add-smtp-support`と同じ手順)

## 4. 動作確認

- [ ] 4.1 vaultwardenコンテナの`ADMIN_TOKEN`環境変数を確認し、`$argon2id$`から始まるPHC文字列になっている(平文ではない)ことを確認する
- [ ] 4.2 Secret Managerから平文トークンを取得し、`/admin`のログイン画面に入力して実際にログインできることを確認する(`.env`→`docker-compose.yml`の`${ADMIN_TOKEN}`展開経路で`$`が壊れていないことの実地検証)
- [ ] 4.3 `/admin`にアクセスした際、冒頭の「平文ADMIN_TOKENを使っている」という警告が表示されなくなっていることを確認する
- [ ] 4.4 VMを再起動(またはstartup-script再実行)し、saltが変わってもログインが引き続き成功することを確認する
