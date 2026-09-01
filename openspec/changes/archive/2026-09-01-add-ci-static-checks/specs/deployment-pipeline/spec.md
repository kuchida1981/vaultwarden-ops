## ADDED Requirements

### Requirement: 認証不要な静的解析チェック
システムは、`terraform plan`とは独立した、GCP認証やリポジトリSecretsを一切必要としない静的解析ワークフローを提供しなければならない(SHALL)。このワークフローは、すべてのプルリクエスト(人間およびDependabotによるものを含む)に対して同一の`pull_request`イベントで実行されなければならない(SHALL)。このワークフローは以下を含まなければならない(SHALL):
- `terraform/main`と`terraform/bootstrap`それぞれに対する`terraform validate`
- `terraform/main`と`terraform/bootstrap`それぞれに対する`tflint`
- `terraform/main/templates/startup-script.sh.tftpl`に対する`shellcheck`
- `vaultwarden/Caddyfile`に対する`caddy validate`(`docker-compose.yml`にピン留めされたバージョンと同一の`caddy`イメージを使用)

#### Scenario: GCP認証なしでPRチェックが実行される
- **WHEN** GCP Workload Identity Federationの認証情報を持たないフォークリポジトリでプルリクエストが作成される
- **THEN** 静的解析ワークフローはリポジトリSecretsに一切依存せず正常に実行され、結果がPR上のチェックとして表示される

#### Scenario: DependabotのPRも同一経路でチェックされる
- **WHEN** dependabotがterraform providerまたはdocker composeイメージを更新するプルリクエストを作成する
- **THEN** 人間が作成したPRと同じ`pull_request`イベント・同じジョブ構成で静的解析ワークフローが実行される

#### Scenario: Terraformコードの構文エラーが検知される
- **WHEN** `terraform/main`または`terraform/bootstrap`配下の`.tf`ファイルに構文エラーを含むプルリクエストが作成される
- **THEN** `terraform validate`ステップが失敗し、CIチェックがfailとして表示される

#### Scenario: startup-script.sh.tftplの構文エラーが検知される
- **WHEN** `startup-script.sh.tftpl`に、Terraform補間由来ではない実際のbash構文エラーを含むプルリクエストが作成される
- **THEN** `shellcheck`ステップが失敗し、CIチェックがfailとして表示される

#### Scenario: Terraform補間がshellcheckの偽陽性として扱われない
- **WHEN** `startup-script.sh.tftpl`内のTerraform`${var}`補間箇所のみを変更するプルリクエスト(実際のbash構文には変更がない)が作成される
- **THEN** `shellcheck`ステップは`SC2154`を理由に失敗しない

#### Scenario: Caddyfileの構文エラーが検知される
- **WHEN** `vaultwarden/Caddyfile`に構文エラーを含むプルリクエストが作成される
- **THEN** `caddy validate`ステップが失敗し、CIチェックがfailとして表示される
