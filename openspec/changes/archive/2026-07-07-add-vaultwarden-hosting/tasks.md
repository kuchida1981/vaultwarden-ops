## 1. リポジトリ構成の初期化

- [x] 1.1 `terraform/bootstrap`, `terraform/main`, `vaultwarden`, `.github/workflows` のディレクトリ構成を作成
- [x] 1.2 `.gitignore`に`*.tfstate*`, `.terraform/`等を追加し、機密情報が誤ってコミットされない状態にする

## 2. Bootstrap(手動・1回のみ)

- [x] 2.1 GCSバケット(Terraform remote state用)を`gcloud`で手動作成する手順をREADMEに記載
- [x] 2.2 GitHub Actions用のWorkload Identity Pool/Providerおよび管理用サービスアカウントを手動作成する手順をREADMEに記載
- [x] 2.3 Tailscale OAuthクライアント(Terraformプロバイダ用)の発行手順をREADMEに記載
- [x] 2.4 上記で得られた値をGitHub Actions Secretsに登録する手順をREADMEに記載

## 3. Terraform: GCPコアインフラ (`gcp-infrastructure`)

- [x] 3.1 `terraform/main`にGCSバックエンド設定を追加
- [x] 3.2 `e2-micro`/Debian 13のVMインスタンスをasia-northeast1に定義
- [x] 3.3 静的External IPリソースを定義しVMにアタッチ
- [x] 3.4 ファイアウォールルールを定義(公開: 80/443のみ、SSHは公開しない)
- [x] 3.5 Vaultwardenデータ用の専用Persistent Diskを定義し、`lifecycle { prevent_destroy = true }`を設定してVMにアタッチ
- [x] 3.6 Google Secret Managerのシークレット(ADMIN_TOKEN, Tailscale authkey等)リソースを定義
- [x] 3.7 CI/Terraform用管理サービスアカウントとVM実行時サービスアカウントを分離して定義し、実行時SAには対象シークレットへの`secretAccessor`のみを付与
- [x] 3.8 起動時にunattended-upgradesを有効化するstartup-script/cloud-init断片を追加

## 4. Terraform: Tailscale接続 (`tailscale-connectivity`)

- [x] 4.1 `tailscale`プロバイダを設定
- [x] 4.2 `tailscale_acl`でtag:vaultwarden-serverの権限(自分の端末からの`tailscale ssh`許可、adminアクセス元の想定送信元レンジ等)を定義
- [x] 4.3 `tailscale_tailnet_key`でタグ付き認証キーを発行し、Secret Managerのシークレットバージョンとして書き込む
- [x] 4.4 VMのstartup-scriptにSecret Managerから認証キーを取得し`tailscale up --ssh --advertise-tags=tag:vaultwarden-server`を無人実行する処理を追加

## 5. Vaultwardenアプリケーション (`vaultwarden-service`)

- [x] 5.1 `docker-compose.yml`でvaultwardenコンテナとcaddyコンテナを定義
- [x] 5.2 データディレクトリを専用Persistent Diskのマウントパスに向ける
- [x] 5.3 `Caddyfile`で`vaultwarden.u-rei.com`のリバースプロキシとLet's Encrypt自動TLSを設定
- [x] 5.4 Caddyfileで`/admin`パスへのアクセスをTailscaleのCGNAT範囲(100.64.0.0/10)に制限するルールを追加
- [x] 5.5 Vaultwarden環境変数で`SIGNUPS_ALLOWED=false`等、招待制運用に必要な設定を行う
- [x] 5.6 ADMIN_TOKENをSecret Manager経由でコンテナに注入する仕組みを実装
- [x] 5.7 VMのstartup-scriptにDocker/Docker Composeのインストールと`docker compose up -d`の起動処理を追加

## 6. GitHub Actions CI/CD (`deployment-pipeline`)

- [x] 6.1 WIFを使ったGCP認証ステップを含む`terraform plan`ワークフロー(PRトリガー)を作成
- [x] 6.2 PRにplan結果をコメントする処理を追加
- [x] 6.3 GitHub Environmentのprotection ruleで承認ゲート付きの`terraform apply`ワークフロー(mainマージトリガー)を作成
- [x] 6.4 Dependabot/Renovateでdocker-composeのVaultwardenイメージタグを自動更新PR化する設定を追加

## 7. DNSとカットオーバー

- [x] 7.1 初回`terraform apply`(承認込み)を実行しインフラ一式を作成
- [x] 7.2 出力された静的External IPを使い、`u-rei.com`のDNS管理画面で`vaultwarden.u-rei.com`のAレコードを手動作成
- [x] 7.3 Let's Encrypt証明書が正常に発行され、`https://vaultwarden.u-rei.com`にアクセスできることを確認
- [x] 7.4 `tailscale ssh`(相当のOpenSSH経由)でVMに接続できること、`/admin`がtailnet外から403になることを確認
- [ ] 7.5 管理画面から家族分の招待リンクを発行し共有

## 8. ドキュメント

- [x] 8.1 README.mdに全体アーキテクチャ図、bootstrap手順、DNS手動設定手順、招待手順、ロードマップ(バックアップ/監視/SMTP)を記載
