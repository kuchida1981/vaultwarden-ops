## Why

Vaultwarden の admin diagnostics で `IP Header check` が失敗している(issue #58)。`vaultwarden/docker-compose.yml` に `IP_HEADER` が未設定のため Vaultwarden はデフォルトの `X-Real-IP` を期待するが、`Caddyfile` の `reverse_proxy` は `X-Real-IP` を送らず、代わりに `X-Forwarded-For` を付与している。結果として全リクエストが実クライアントIPではなく Caddy コンテナのIPとして扱われ、ログイン試行のレート制限が全ユーザー共有バケット化し、イベント/監査ログの実用性が下がっている。

## What Changes

- `vaultwarden/docker-compose.yml` の `vaultwarden` サービスに `IP_HEADER: "X-Forwarded-For"` を追加する
- `IP_HEADER_TRUSTED_PROXIES` はデフォルトの `local` のまま変更しない(Caddy コンテナは docker internal network 上のプライベートIPから接続するため)
- `Caddyfile` は変更しない。ただし、この構成の安全性(クライアントが `X-Forwarded-For` を自作しても Caddy の `trusted_proxies` 未設定によりなりすましが成立しないこと)を `Caddyfile` にコメントとして明文化し、将来 `trusted_proxies` を追加する変更が入った際に、この前提が壊れることに気づけるようにする

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `vaultwarden-service`: 実クライアントIPの取得に関する要件を追加する(現状は未記述のため、新規Requirementとして追加)

## Impact

- `vaultwarden/docker-compose.yml`: `IP_HEADER` 環境変数を追加
- `vaultwarden/Caddyfile`: 説明コメントの追加のみ(挙動は変更なし)
- 反映は `vaultwarden-deploy.yml` の承認ゲート経由(README「Vaultwardenのバージョン更新」節と同じ運用フロー、`docker compose up -d`)
- 影響を受けるのは実ログイン時のレート制限判定キーと、イベント/監査ログに記録されるIP。既存データの移行は不要
