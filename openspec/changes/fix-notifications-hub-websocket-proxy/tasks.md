## 1. Caddyfile修正

- [ ] 1.1 `vaultwarden/Caddyfile`から`reverse_proxy /notifications/hub vaultwarden:3012`の行(および関連コメント)を削除する
- [ ] 1.2 削除後もキャッチオール`handle { reverse_proxy vaultwarden:80 }`が`/notifications/hub`を含む全パスをカバーしていることをファイルを読み直して確認する

## 2. 検証

- [ ] 2.1 `caddy validate --config vaultwarden/Caddyfile`(または`docker run --rm -v $(pwd)/vaultwarden/Caddyfile:/etc/caddy/Caddyfile caddy:2.11.4 caddy validate --config /etc/caddy/Caddyfile`)で構文エラーがないことを確認する
- [ ] 2.2 可能であればステージング/実環境で、別クライアントからのVault変更が接続中のクライアントへWebSocket経由でリアルタイム同期されることを目視確認する

## 3. デプロイ・後片付け

- [ ] 3.1 `vaultwarden-deploy.yml`パイプライン経由で変更をデプロイする
- [ ] 3.2 GitHub Issue #92をこの変更のマージ/デプロイ後にクローズする
