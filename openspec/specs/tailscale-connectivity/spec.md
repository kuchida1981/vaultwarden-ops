## Purpose

VMのTailscale tailnetへの自動参加、ACL/認証キーのTerraformによる管理、SSHおよび管理系エンドポイント(Vaultwardenの`/admin`パネル)へのアクセスをtailnet経由に限定することで、公開VMに対する管理系アクセス経路をインターネットから遮断する。

## Requirements

### Requirement: VMの無人tailnet参加
システムは、VM起動時にstartup-scriptが自動的にTailscaleクライアントをインストールし、Secret Managerから取得した認証キーを用いて手動承認なしにtailnetへ参加しなければならない(SHALL)。

#### Scenario: 起動したVMが自動的にtailnetへ現れる
- **WHEN** VMインスタンスが起動する
- **THEN** 人手を介さずに`tailscale up`が実行され、当該VMがTailscale管理画面上でtailnetの一員として認識される

### Requirement: ACL・認証キーのTerraform管理
システムは、Tailscaleの公式Terraformプロバイダを用いて、tailnetの認証キー発行とACLポリシー(タグ`tag:vaultwarden-server`に対する権限設定を含む)をコードとして管理しなければならない(SHALL)。

#### Scenario: Terraform applyでタグ付き認証キーが発行される
- **WHEN** `terraform apply`を実行する
- **THEN** `tag:vaultwarden-server`が付与された認証キーが発行され、Secret Managerに書き込まれる

### Requirement: SSHアクセスはtailnet経由に限定
システムは、VMへのSSHアクセス手段として`tailscale ssh`のみを提供し、インターネットからの直接SSH接続を許可してはならない(SHALL NOT)。

#### Scenario: tailnet経由のSSHは成功する
- **WHEN** tailnetに参加済みの承認された端末から`tailscale ssh`でVMに接続する
- **THEN** 接続が確立できる

#### Scenario: 公開インターネット経由のSSHは到達できない
- **WHEN** tailnetに参加していないホストがVMの外部IPに対してSSH接続を試みる
- **THEN** ファイアウォールにより到達できない(gcp-infrastructureの公開ファイアウォール要件と合わせて成立する)

### Requirement: 管理パネルアクセスのtailnet制限
システムは、Vaultwardenの`/admin`パネルへのアクセスを、送信元IPがTailscaleのCGNAT範囲(100.64.0.0/10)である場合のみ許可しなければならない(SHALL)。それ以外の送信元からのリクエストは拒否しなければならない(SHALL)。

#### Scenario: tailnet外からのadminアクセスは拒否される
- **WHEN** tailnetに属さない送信元IPから`/admin`パスへアクセスする
- **THEN** リバースプロキシ(Caddy)が403を返す

#### Scenario: tailnet内からのadminアクセスは許可される
- **WHEN** Tailscale経由でtailnet内のIP(100.64.0.0/10)から`/admin`パスへアクセスする
- **THEN** リクエストがVaultwardenの管理パネルまで到達する
