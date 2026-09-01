## 1. ワークフローファイルの作成

- [x] 1.1 `.github/workflows/lint.yml`を新規作成し、`on: pull_request`(パスフィルタなし、GCP認証ステップなし)で起動するようにする
- [x] 1.2 `terraform-validate`ジョブ: `terraform/main`と`terraform/bootstrap`をmatrix(またはstepの繰り返し)で対象にし、各ディレクトリで`terraform init -backend=false`→`terraform validate`を実行する
- [x] 1.3 `tflint`ジョブ: `terraform/main`と`terraform/bootstrap`をmatrix(またはstepの繰り返し)で対象にし、デフォルトのcore rulesetで実行する(`terraform-linters/setup-tflint`アクション、またはdockerイメージ経由)
- [x] 1.4 `shellcheck`ジョブ: `terraform/main/templates/startup-script.sh.tftpl`に対して`--exclude=SC2154,SC1091`を指定して実行し、除外理由をワークフローファイル内にコメントで明記する
- [x] 1.5 `caddy-validate`ジョブ: `vaultwarden/Caddyfile`に対して`caddy:2.11.4`イメージ(docker-compose.ymlのバージョンと同一)で`caddy validate --config`を実行する(ダミーの`DOMAIN`環境変数を与える)

## 2. 検証

- [x] 2.1 実際にPRを作成し、4つのジョブすべてがGCP Secretsなしで正常にpassすることを確認する(PR #95で6ジョブ全てpassを確認済み)
- [x] 2.2 意図的に構文エラーを混入させた一時的な変更で、各ジョブが正しくfailすることを確認する(terraform構文エラー・shellcheck対象の実際のbashエラー・Caddyfile構文エラーそれぞれ) — ローカルのscratchpad上の一時コピーに対して実行し、PRブランチ・git履歴は汚さない形で確認した
- [x] 2.3 確認用の一時的な構文エラーを元に戻す — 2.2の検証はリポジトリ外の一時コピーに対して行ったため、リポジトリ側に戻す変更は元々発生していない

## 3. 後片付け

- [ ] 3.1 GitHub Issue #90をこの変更のマージ後にクローズする
