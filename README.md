# vaultwarden-hosting

自分と家族用のVaultwarden(パスワードマネージャ)を、GCP Compute Engine(東京リージョン)上でセルフホスティングするためのインフラ一式。TerraformでGCPリソースを、GitHub ActionsでCI/CDを、Tailscaleで管理系アクセスを保護する。

- 公開URL: `https://vaultwarden.u-rei.com` (家族はここから普通にアクセス)
- SSH / Vaultwardenの`/admin`パネル: Tailscale tailnet経由のみ
- データバックアップ・稼働監視・SMTP招待は今回のスコープ外(ロードマップ、下記参照)

## アーキテクチャ

```
                         インターネット (誰でも)
                                │ 443 のみ
                                ▼
                    ┌───────────────────────────┐
                    │  GCE VM (e2-micro)          │
                    │  asia-northeast1, Debian13  │
                    │  ┌───────────────────────┐  │
                    │  │ Caddy (TLS終端)         │  │
                    │  │  / → Vaultwarden        │  │
                    │  │  /admin → tailnetのみ    │  │
                    │  └───────────────────────┘  │
                    │  data disk: 専用Persistent   │
                    │  Disk (VMと独立ライフサイクル) │
                    └───────────────┬───────────────┘
                                    │ Tailscale (WireGuard)
                                    ▼
                         SSHはtailscale sshのみ
                     (公開ファイアウォールで22番は非公開)
```

Terraformは`terraform/bootstrap`(1回だけ手動apply)と`terraform/main`(GitHub Actionsが継続的にapply)の2段構成。

## セットアップ手順

### 0. 前提

- GCPプロジェクトが作成済みで、課金が有効化されていること
- ローカルに`gcloud` CLIと`terraform`(>=1.6)がインストール済みで、`gcloud auth application-default login`済みであること
- Tailscaleのtailnetに参加済みであること(このリポジトリではtailnetそのものは作成しない)

### 1. Bootstrap(手動・最初の1回だけ)

`terraform/main`はGCSのリモートバックエンドとWorkload Identity Federation経由のGitHub Actions認証を前提にしているが、そのバケットとWIF Pool自体は「これから作る側」なので、ローカルから一度だけ手動で作成する。

```bash
cd terraform/bootstrap
terraform init
terraform apply \
  -var="project_id=<your-gcp-project-id>" \
  -var="github_repo=<your-github-username>/vaultwarden-hosting"
```

apply完了後、以下のoutputを控える(次のGitHub Secrets登録で使う):

```bash
terraform output
# state_bucket
# workload_identity_provider
# terraform_ci_service_account_email
```

### 2. Tailscale OAuthクライアントの発行(手動)

`terraform/main`の`tailscale`プロバイダがACLと認証キーをコード管理するために、tailnetへのAPIアクセス権を持つOAuthクライアントが必要。

1. **先にタグを定義する**: https://login.tailscale.com/admin/acl/file を開き、`tagOwners`に以下を追記して保存する(`Auth Keys`スコープはタグ制限が必須で、そのタグがACLに未定義だと選択できない)

   ```json
   "tagOwners": {
       "tag:vaultwarden-server": ["autogroup:admin"],
   },
   ```

   (このエントリは`terraform/main/tailscale.tf`の`tailscale_acl`リソースが後で適用する内容と同一なので、後続のTerraform applyと矛盾しない)

2. https://login.tailscale.com/admin/settings/oauth を開く
3. "Generate OAuth client" を実行
4. スコープに **Policy File** (write) と **Auth Keys** (write) を付与(APIスコープ名としては`policy_file`と`auth_keys`。`tailscale_acl`リソースがPolicy File、`tailscale_tailnet_key`リソースがAuth Keysを使う)。Auth Keysのタグには手順1で定義した `tag:vaultwarden-server` を選択する
5. 発行された **Client ID** と **Client Secret** を控える(Secretは一度しか表示されない)

### 3. GitHub Actions Secretsの登録

このリポジトリの Settings → Secrets and variables → Actions に、以下を登録する:

| Secret名 | 値 |
|---|---|
| `GCP_PROJECT_ID` | GCPプロジェクトID |
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | bootstrapのoutput `workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT_EMAIL` | bootstrapのoutput `terraform_ci_service_account_email` |
| `TF_STATE_BUCKET` | bootstrapのoutput `state_bucket` |
| `TAILSCALE_OAUTH_CLIENT_ID` | 手順2で発行したClient ID |
| `TAILSCALE_OAUTH_CLIENT_SECRET` | 手順2で発行したClient Secret |
| `TAILSCALE_TAILNET` | 自分のtailnet名(例: `example.ts.net`のexample部分、またはメールアドレス形式) |

**重要**: これらはリポジトリにコミットしない。すべてGitHub Actions Secretsとしてのみ保持する(このリポジトリは公開リポジトリなので特に注意)。

### 4. GitHub Environmentの承認ゲート設定(手動)

`terraform-apply.yml`ワークフローは`environment: production`を参照しているが、実際に人間の承認待ちで停止させるprotection ruleはワークフローYAMLだけでは設定できない。このリポジトリの Settings → Environments → New environment で `production` を作成し、"Required reviewers" に自分自身(または信頼できるレビュワー)を追加する。

### 5. Terraform mainのapply

`main`ブランチへのマージ後、GitHub Actionsの`terraform apply`ワークフローが承認待ちで停止するので、GitHub上で承認する。初回applyでVM・静的IP・ファイアウォール・データディスク・Secret Manager・Tailscale ACL/認証キーが一括作成される。

**注意**: `tailscale_acl`リソースはtailnetのACLポリシー全体を1つのリソースとして管理する。初回apply前に https://login.tailscale.com/admin/acl/file で現在のACL設定を確認し、既存のカスタムルール(あれば)を`terraform/main/tailscale.tf`にマージしてから実行すること。

### 6. DNSレコードの手動作成

`u-rei.com`はレジストラのデフォルトDNSで管理しており、Terraformでは自動化していない。apply完了後、以下の出力値を使って手動でAレコードを作成する:

```bash
cd terraform/main
terraform output vm_external_ip
```

`u-rei.com`のDNS管理画面で `vaultwarden` サブドメインのAレコードをこのIPに向けて作成する。

### 7. 動作確認と家族の招待

- `https://vaultwarden.u-rei.com` にアクセスし、Let's Encrypt証明書が有効になっていることを確認
- `tailscale ssh <vm-hostname>` でVMに接続できることを確認
- tailnet外から`/admin`にアクセスすると403になることを確認
- `/admin`(tailnet経由)から家族分のアカウント招待リンクを発行し、個別に共有する(SMTPは未設定のため、リンクはLINEやメール等で手動送付)

## ロードマップ(本リポジトリの現時点のスコープ外)

- NASへの定期バックアップ(rsync over Tailscale SSH、世代管理)
- 稼働監視・アラート(Cloud Monitoring Uptime Check)
- SMTPによるメール招待・通知

## ディレクトリ構成

```
terraform/bootstrap/  … 手動・1回だけapply。GCS state bucket, WIF Pool, CI用SA
terraform/main/       … GitHub Actionsが継続的にapply。VM/FW/Disk/Secret Manager/Tailscale ACL
vaultwarden/           … docker-compose.yml, Caddyfile
.github/workflows/     … terraform plan(PR) / apply(main, 承認ゲート付き)
```
