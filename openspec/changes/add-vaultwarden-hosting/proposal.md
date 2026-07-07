## Why

1Passwordの値上げを機に、自分と家族用のパスワードマネージャをVaultwardenでセルフホスティングする。個人利用だが公開ドメインでインターネットからアクセス可能にするため、最小コストのインフラをTerraformで宣言的に管理しつつ、公開環境として妥当なセキュリティ設定を最初から組み込む。

## What Changes

- GCP Compute Engine上に最安スペック(e2-micro, asia-northeast1, Debian 13)のVMをTerraformでプロビジョニングし、Vaultwarden(+Caddy)をDocker Composeで稼働させる
- `vaultwarden.u-rei.com` カスタムドメインでVaultwarden本体を公開(HTTPS, Let's Encrypt自動発行)。SSHおよびVaultwardenの`/admin`パネルはTailscale tailnet経由のみに制限し、公開ポートは443/80のみ
- VMをTailscale tailnetに自動参加させる(起動時に無人でauthkey取得・join)。tailnetのACL/認証キー発行はTerraformの`tailscale`プロバイダで管理
- ADMIN_TOKENやTailscale authkeyなどの機密情報はGoogle Secret Managerに保管し、VM実行時SAはread-onlyでのみアクセス
- GitHub Actions(Workload Identity Federationでキーレス認証)でTerraformのCI/CDパイプラインを構築。PRでplan、mainマージ後は手動承認を経てapply
- Vaultwardenのデータ(DB, RSA鍵, 添付ファイル)を専用のPersistent Disk(`prevent_destroy`)に永続化し、VM再作成に対して独立させる
- 公開VMの最低限のセキュリティ衛生として、Debianの自動セキュリティ更新(unattended-upgrades)を有効化
- 公開リポジトリとして運用するため、全ての機密情報はGitHub Actions SecretsまたはGoogle Secret Manager経由とし、リポジトリには一切コミットしない

**ロードマップ(本変更のスコープ外)**:
- NASへの定期バックアップ(rsync over Tailscale)
- 稼働監視・アラート(Uptime Check)
- SMTPによるメール招待

## Capabilities

### New Capabilities
- `gcp-infrastructure`: TerraformによるGCE VM/静的IP/ファイアウォール/永続ディスク/Secret Managerのプロビジョニング、東京リージョン・最安スペック、OS自動セキュリティ更新
- `tailscale-connectivity`: VMのtailnet自動参加、ACL/認証キーのTerraform管理、SSHおよび管理系エンドポイントのtailnet限定アクセス
- `vaultwarden-service`: Docker ComposeによるVaultwarden+Caddyのデプロイ、カスタムドメインでのTLS終端、公開環境向けハードニング設定(サインアップ制御、admin token等)
- `deployment-pipeline`: GitHub ActionsによるTerraform CI/CD(WIF認証、PR plan、承認後apply)、初回bootstrap手順(GCSバケット・WIF Pool)

### Modified Capabilities
(既存specなし。新規プロジェクトのため該当なし)

## Impact

- 新規GCPプロジェクト/リソース一式(Compute Engine, VPC Firewall, Persistent Disk, Secret Manager, Workload Identity連携)のコストが発生(概算 月$10以下)
- `u-rei.com` のDNSに `vaultwarden.u-rei.com` のAレコードを手動追加する必要あり(レジストラのデフォルトDNS管理のためTerraform対象外)
- 既存のTailscale tailnetにVMという新しいデバイスが参加し、ACLポリシーの変更が必要
- 新規GitHubリポジトリ(公開)に Terraform/Docker Compose/GitHub Actionsワークフロー一式を追加
