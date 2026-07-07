## Context

自分と家族のためのパスワードマネージャを、1Passwordの値上げを機にVaultwardenへセルフホスティング移行する。制約は以下の通り:

- インフラはGCP Compute Engine、東京リージョン(asia-northeast1)、最安スペック
- インフラはTerraformで管理
- ホスティング関連ファイルは公開GitHubリポジトリで管理(機密情報はコミットしない)
- カスタムドメイン `vaultwarden.u-rei.com` を使用(`u-rei.com`はレジストラのデフォルトDNSで管理中、Terraform管理対象外)
- 個人用途だが公開環境であるため、相応のセキュリティ設定が必要
- 既存のTailscale tailnetにNASが参加済み。VMも参加させる
- NASへの定期バックアップ、稼働監視、SMTP招待は本変更のロードマップ外(将来対応)

## Goals / Non-Goals

**Goals:**
- 家族が `https://vaultwarden.u-rei.com` から自由にVaultwardenへアクセスできる
- 管理系操作(SSH, `/admin`パネル)はTailscale tailnet経由のみに制限する
- インフラ・アプリ設定をすべてコードとして公開リポジトリで管理し、機密情報は分離する
- GitHub ActionsからGCPへキーレス認証(WIF)でTerraformを適用できる
- VM再作成が発生してもVaultwardenのデータは失われない
- 月額コストを最小化する(目安: $10/月以下)

**Non-Goals:**
- NASへの自動バックアップの実装(ロードマップ、本変更ではACLに疎通余地を残すのみ)
- 稼働監視・アラーティングの実装(ロードマップ)
- SMTPによるメール招待・通知(今回は管理画面の招待リンク手動共有)
- 高可用性・マルチリージョン対応(個人用途のため不要)
- Postgresなど外部DBへの移行(SQLiteで十分な規模)

## Decisions

### 1. 公開範囲: Vaultwarden本体はフル公開、管理系はtailnet限定
Tailscaleを既に保有しているため「tailnet限定公開」や「Tailscale Funnel経由の公開」も選択肢だったが、以下の理由で不採用:
- tailnet限定は家族全員へのTailscaleクライアント導入・維持という運用負荷が常時発生する
- Tailscale Funnelは証明書がts.netドメイン向けであり、独自ドメイン(`vaultwarden.u-rei.com`)を正面に立てるには追加のリバースプロキシ層が必要になり複雑化する

採用: VMに静的External IPを持たせ、GCPファイアウォールで443/80のみ公開。Caddyが`vaultwarden.u-rei.com`のTLSをLet's Encryptで自動終端。SSHは公開ポートを一切開けず`tailscale ssh`のみ、Vaultwardenの`/admin`はCaddy側で送信元IPをTailscaleのCGNAT範囲(100.64.0.0/10)に制限する。

### 2. DNS: Terraform管理外、手動設定
`u-rei.com`はレジストラのデフォルトDNSで管理されており、Terraformプロバイダで自動化できない。Terraformは静的External IPをoutputとして提示するに留め、Aレコード作成はREADMEに手順化した手動ステップとする。

### 3. マシンタイプ・OS: e2-micro / Debian 13 (trixie)
asia-northeast1はGCPの無料枠(Always Free)対象リージョンに含まれないため、無料枠は狙わず単純に最安の汎用マシンタイプ`e2-micro`を採用。Preemptible/Spot VMは強制停止のリスクがあり常時稼働のパスワードマネージャには不適のため不採用。OSはContainer-Optimized OSではなくDebian 13を採用: cron(バックアップ用ロードマップ含む)やunattended-upgradesをホスト側で素直に扱えることを優先した。

### 4. データ永続化: 専用Persistent Diskを分離
VaultwardenのデータをVMのboot diskに直接置くと、Terraformコードの変更でVMが意図せず再作成(destroy&create)された際にデータが消失する。専用のPersistent Disk(`lifecycle { prevent_destroy = true }`)を切り出し、`/opt/vaultwarden/data`にマウントする。VMのライフサイクルとデータのライフサイクルを分離することで、VM再作成時もディスクを新VMに付け替えるだけで復旧できる。

### 5. 機密情報: Google Secret Managerに集約
ADMIN_TOKEN、Tailscale authkeyなどはGoogle Secret Managerに保管する。VMに付与するサービスアカウントは対象シークレットへの`roles/secretmanager.secretAccessor`のみを持つ最小権限とし、Terraform/CI用の管理SA(Secret書き込み・GCEリソース作成権限)とは分離する。VM起動時のstartup-scriptはSecret Manager APIから値を取得し、GCPインスタンスmetadataに機密情報を平文で載せない。

### 6. Tailscale接続: Terraform `tailscale` プロバイダでACL/キーをコード管理
Tailscaleの公式Terraformプロバイダで管理できるのはtailnet側のリソース(ACLポリシー、認証キーの発行)であり、VM内部での`tailscale up`実行そのものはTerraformの管理対象にならない(宣言的リソースではなくランタイム動作のため)。よって:
- `tailscale_tailnet_key`でタグ付きの認証キーを発行し、Secret Manager経由でVMに渡す
- `tailscale_acl`でtag:vaultwarden-serverの権限(自分の端末からの`tailscale ssh`許可等)を事前定義し、自動承認されるようにする
- VM起動時のstartup-scriptがSecret Managerからキーを取得し`tailscale up --ssh --advertise-tags=tag:vaultwarden-server`を無人実行する
- Tailscale API認証(OAuthクライアント)はユーザーが既存のtailnetで発行し、GitHub Actions Secretsに保管する(GCP向けWIFとは別チャネル)

### 7. CI/CD: GitHub Actions + WIF + 手動承認ゲート
公開リポジトリでの長期SAキー保管を避けるため、Workload Identity FederationでGitHub ActionsからGCPへキーレス認証する。フローは「PRで`terraform plan`を実行しレビュー→mainへのマージ後、GitHub Environmentの protection rule により人間が承認して初めて`terraform apply`が走る」。完全自動applyにしなかった理由は、インフラ変更頻度が低い個人用途であり、意図しないVM再作成などの事故を承認ゲートで防ぐ価値が高いため。

### 8. Terraform state / WIF Poolのbootstrap問題
tfstateをGCSバケットに置く方針だが、そのバケット自体とWorkload Identity Pool/Providerは「Terraformが管理する対象」であると同時に「Terraformを動かすために事前に存在すべきもの」というchicken-and-egg関係にある。これは自動化せず、`terraform/bootstrap`配下に最小構成(ローカルstate、手動apply一回のみ)を用意し、README手順化する。以降の変更は`terraform/main`(GCS backend、GitHub Actions経由)で管理する。

### 9. 自動セキュリティ更新
公開VMの最低限の衛生として、Debianの`unattended-upgrades`を有効化しセキュリティパッチを自動適用する。追加コスト・運用負荷がほぼゼロなため、監視機能を持たない現段階でも含める。

## Risks / Trade-offs

- [リスク] GitHub Actionsの承認者(自分自身)が長期不在の場合、緊急のインフラ変更が滞る → 影響は小さい(個人用途、変更頻度低)ため許容
- [リスク] Secret Managerアクセス用のVM実行時SAの権限設定を誤ると、意図せず広い範囲のシークレットにアクセス可能になる → シークレットごとにIAMバインディングを個別に定義し、`secretAccessor`ロールを対象シークレットのみに限定する
- [リスク] `vaultwarden.u-rei.com`のAレコードが手動設定のため、静的IPが変わった場合(通常発生しないが)に追従漏れが起きうる → 静的IPをTerraform outputとして明示し、README上で変更検知の注意点として明記
- [リスク] tailnetのACL設定を誤ると`tailscale ssh`経由の管理アクセス自体を失う可能性がある → 初回はGCPコンソールのシリアルコンソール/ブラウザSSHを緊急アクセス手段として温存しておく
- [トレードオフ] フル公開+ tailnet限定管理という構成は、tailnet限定公開に比べ攻撃対象領域が広い → Caddyでの`/admin`アクセス制限、ADMIN_TOKEN、サインアップ無効化、自動セキュリティ更新の組み合わせで許容範囲に抑える
- [トレードオフ] 承認ゲート付きCI/CDは完全自動化に比べ運用の手間が増える → 変更頻度が低い個人インフラのため妥当と判断
- [リスク] `/admin`のCaddy送信元IP制限(100.64.0.0/10)は、`vaultwarden.u-rei.com`の公開DNSがVMの公開IPを指すため、公開ドメイン経由でアクセスすると常に非tailnetの送信元IPになり403になる(実装レビューで発覚) → adminは自分の端末の`hosts`ファイルでこのホスト名をVMのTailscale IPに上書きすることで到達する運用とし、READMEに手順化(恒久対応としてはTailscale Split DNSや`tailscale cert`によるMagicDNS側site blockの追加も検討可能)
- [リスク] 上記の`hosts`上書き経由でTailscale IPに直接アクセスしても、Dockerの`userland-proxy`が有効だとCaddyコンテナから見た送信元IPがdockerブリッジのゲートウェイIPにすり替わり、tailnet経由でも常に403になる(実カットオーバー時に発覚) → `/etc/docker/daemon.json`で`userland-proxy: false`を設定し、iptablesのみのDNATで送信元IPを保持するようstartup-scriptを修正

## Migration Plan

1. (手動・1回のみ) GCSバケットとWorkload Identity Pool/Provider、Tailscale OAuthクライアントをbootstrap手順に従い作成
2. `terraform/main`をGitHub Actionsで`plan`→レビュー→承認→`apply`し、VM・静的IP・ファイアウォール・Persistent Disk・Secret Managerリソース・Tailscale ACL/キーを作成
3. VM起動(startup-script)によりDocker/Tailscale/Vaultwarden/Caddyが無人セットアップされる
4. 出力された静的External IPを使い、`u-rei.com`のDNSに`vaultwarden.u-rei.com`のAレコードを手動作成
5. Let's Encrypt証明書の自動発行を確認後、Vaultwardenの`/admin`から家族分のアカウント招待リンクを発行して手動共有
6. ロールバック: `terraform destroy`はデータディスクを`prevent_destroy`で保護しているため誤爆時も即データ消失には至らない。問題発生時はVMのみ再作成しディスクを再アタッチする

## Open Questions

- Tailscale ACLで tag:vaultwarden-server に許可する送信元(自分の端末のタグ/ユーザー)の具体的な範囲は実装時に確定する
- 将来のNASバックアップ実装時、tailnet ACLにNASタグとの疎通ルールを追加する必要がある(本変更では未定義)
