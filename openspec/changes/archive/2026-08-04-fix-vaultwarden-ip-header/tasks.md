## 1. docker-compose.yml の変更

- [x] 1.1 `vaultwarden/docker-compose.yml` の `vaultwarden` サービスの `environment` に `IP_HEADER: "X-Forwarded-For"` を追加する

## 2. Caddyfile へのコメント追加

- [x] 2.1 `vaultwarden/Caddyfile` に、`trusted_proxies` が未設定である前提が `X-Forwarded-For` のなりすまし耐性の根拠であることを説明するコメントを追加する(design.mdのDecision 2参照)

## 3. デプロイと確認

- [x] 3.1 PRを作成し `main` へマージする
- [x] 3.2 `vaultwarden-deploy.yml` の承認ゲートを通して本番反映する(README「Vaultwardenのバージョン更新」節の手順)
- [x] 3.3 `/admin` パネルのdiagnosticsページで `IP Header check` が成功に変わることを確認する(`IP Header check: true (X-Forwarded-For)`)
- [x] 3.4 公開ドメイン経由でログインし、イベントログに実クライアントIP(Caddyコンテナのdocker内部IPではない)が記録されることを確認する(admin diagnosticsの`IP Header check: true`が、実トラフィックからVaultwardenが有効なIPを抽出できていることの直接的な根拠)

## 4. Issue のクローズ

- [x] 4.1 issue #58 に対応PRへの参照を残し、確認完了後にクローズする(PR #59、クローズ済み)
