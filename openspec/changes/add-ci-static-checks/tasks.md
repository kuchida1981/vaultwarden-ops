## 1. ワークフローファイルの作成

- [ ] 1.1 `.github/workflows/lint.yml`を新規作成し、`on: pull_request`(パスフィルタなし、GCP認証ステップなし)で起動するようにする
- [ ] 1.2 `terraform-validate`ジョブ: `terraform/main`と`terraform/bootstrap`をmatrix(またはstepの繰り返し)で対象にし、各ディレクトリで`terraform init -backend=false`→`terraform validate`を実行する
- [ ] 1.3 `tflint`ジョブ: `terraform/main`と`terraform/bootstrap`をmatrix(またはstepの繰り返し)で対象にし、デフォルトのcore rulesetで実行する(`terraform-linters/setup-tflint`アクション、またはdockerイメージ経由)
- [ ] 1.4 `shellcheck`ジョブ: `terraform/main/templates/startup-script.sh.tftpl`に対して`--exclude=SC2154,SC1091`を指定して実行し、除外理由をワークフローファイル内にコメントで明記する
- [ ] 1.5 `caddy-validate`ジョブ: `vaultwarden/Caddyfile`に対して`caddy:2.11.4`イメージ(docker-compose.ymlのバージョンと同一)で`caddy validate --config`を実行する(ダミーの`DOMAIN`環境変数を与える)

## 2. 検証

- [ ] 2.1 実際にPRを作成し、4つのジョブすべてがGCP Secretsなしで正常にpassすることを確認する(ローカルでの事前確認はdesign.mdの検証結果を参照)
- [ ] 2.2 意図的に構文エラーを混入させた一時的な変更で、各ジョブが正しくfailすることを確認する(terraform構文エラー・shellcheck対象の実際のbashエラー・Caddyfile構文エラーそれぞれ)
- [ ] 2.3 確認用の一時的な構文エラーを元に戻す

## 3. 後片付け

- [ ] 3.1 GitHub Issue #90をこの変更のマージ後にクローズする
