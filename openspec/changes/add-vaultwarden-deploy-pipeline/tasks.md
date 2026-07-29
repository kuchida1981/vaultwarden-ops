凡例: 各タスクの先頭に実行主体を明記する。
- **[実装]**: このリポジトリのコード変更(agentが実施可能)
- **[ユーザー手動]**: GCPコンソール/CLIでの実apply、GitHub Environment承認など、人間が実際の環境に対して手を動かす必要がある操作

## 1. terraform/bootstrap: IAP tunnel用IAM追加

- [ ] 1.1 **[実装]** `terraform/bootstrap/main.tf`の`google_project_service.required`に`iap.googleapis.com`を追加する
- [ ] 1.2 **[実装]** `terraform/bootstrap/main.tf`の`terraform_ci_roles`(`google_project_iam_member`)に`roles/iap.tunnelResourceAccessor`・`roles/compute.osAdminLogin`を追加する
- [ ] 1.3 **[実装]** なぜ`osAdminLogin`(`osLogin`ではない)が必要かのコメントを追記する(`/opt/vaultwarden/app`・`.env`・dockerソケットがroot所有でsudoが必要なため。n8n-opsの`terraform/bootstrap/main.tf`のコメントを参考にする)
- [ ] 1.4 **[ユーザー手動]** `terraform/bootstrap`はCIから自動applyされないため、上記変更を反映するために手動で`terraform init -backend-config="bucket=<state_bucket>"` → `terraform apply`を実行する

## 2. terraform/main: OS Login有効化とIAPファイアウォール

- [ ] 2.1 **[実装]** `terraform/main/compute.tf`のVM `metadata`に`enable-oslogin = "TRUE"`を追加する
- [ ] 2.2 **[実装]** `terraform/main/network.tf`に、IAPの専用ソースレンジ(`35.235.240.0/20`)から`target_tags = ["vaultwarden-server"]`へのtcp:22を許可する新規firewallルール(`vaultwarden-allow-iap-ssh`)を追加する
- [ ] 2.3 **[実装]** 既存の「port 22は公開しない、SSHはtailscale sshのみ」というコメントの近くに、IAP tunnel用ルールがなぜ別途必要かの説明を追記する(n8n-opsの`network.tf`のコメントを参考にする)

## 3. `vaultwarden-deploy.yml`ワークフロー新設

- [ ] 3.1 **[実装]** `.github/workflows/vaultwarden-deploy.yml`を新規作成し、`on: push: branches: [main], paths: ["vaultwarden/**"]`をトリガーに設定する
- [ ] 3.2 **[実装]** `summary`ジョブ: `vaultwarden/docker-compose.yml`内の`image:`行の差分を、`vaultwarden-last-deploy`タグ(存在しなければ`HEAD^`)を基準に計算し、`$GITHUB_STEP_SUMMARY`へ出力する
- [ ] 3.3 **[実装]** `deploy`ジョブ: `needs: summary`、`environment: production`を指定し、WIF認証後`gcloud compute ssh vaultwarden --tunnel-through-iap`で`cd /opt/vaultwarden/app && git pull --ff-only && cd vaultwarden && docker compose --env-file /opt/vaultwarden/.env pull && docker compose --env-file /opt/vaultwarden/.env up -d`を実行する。失敗時のフォールバック(`|| echo WARNING`等)は入れず、失敗をそのままジョブ失敗として伝播させる
- [ ] 3.4 **[実装]** デプロイ成功後、`git tag -f vaultwarden-last-deploy && git push -f origin vaultwarden-last-deploy`を実行するステップを追加する(`permissions: contents: write`が必要)
- [ ] 3.5 **[実装]** `run-name`にコミットメッセージを表示する設定を加える(n8n-deploy.ymlと同様、承認画面での視認性のため)

## 4. ドキュメント更新

- [ ] 4.1 **[実装]** `README.md`/`README.ja.md`に、`terraform/bootstrap`への今回のIAM追加分を手動applyする手順を追記する
- [ ] 4.2 **[実装]** `README.md`/`README.ja.md`に、vaultwardenのバージョンアップがどう本番に反映されるか(Dependabot PR→マージ→`vaultwarden-deploy.yml`起動→`production` Environment承認→反映)という一連の流れを追記する
- [ ] 4.3 **[実装]** `README.md`/`README.ja.md`のSSHに関する記述を「Tailscale tailnet経由のみ」から「Tailscale(運用者による通常アクセス)+ IAP tunnel(CI用SA限定・承認ゲート付き)」に更新する

## 5. ロールアウトと動作確認

- [ ] 5.1 **[ユーザー手動]** タスク1.4の`terraform apply`(bootstrap)が完了していることを確認する
- [ ] 5.2 **[ユーザー手動]** タスク2の変更(OS Login・IAPファイアウォール)を含むPRを作成・マージし、既存の`terraform-apply.yml`の`production` Environment承認を実施してVMへ反映する
- [ ] 5.3 **[ユーザー手動]** `gcloud auth login`等でローカルのgcloud CLI認証状態を整えた上で、`gcloud compute ssh vaultwarden --tunnel-through-iap --zone=<zone> --project=<project>`が手動で成功することを事前に検証する(IAP tunnel経路そのものの疎通確認)
- [ ] 5.4 **[ユーザー手動]** タスク3・4の変更(`vaultwarden-deploy.yml`・README)を含むPRを作成・マージする
- [ ] 5.5 **[ユーザー手動]** PR #46、またはその時点の最新のDependabotによるvaultwardenバージョンPRをマージし、`vaultwarden-deploy.yml`が起動して`production` Environmentの承認待ちで停止することを確認する
- [ ] 5.6 **[ユーザー手動]** 承認を実施し、実際にVM上でイメージが更新されること(ログイン成功・添付ファイル表示・`/admin`パネルの動作)を確認する
- [ ] 5.7 **[ユーザー手動]** 一連の動作確認が完了したら、`/opsx:archive`でこのchangeをアーカイブする
