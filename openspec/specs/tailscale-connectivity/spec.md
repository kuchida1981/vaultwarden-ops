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
システムは、Vaultwardenの`/admin`パネルを`tailscale serve`によりtailnet限定で配信しなければならない(SHALL)。tailnetに参加している端末は、TailscaleのMagicDNSホスト名(`https://vaultwarden.<tailnet>.ts.net/admin`)経由で、追加のDNS設定や`hosts`ファイル編集なしに到達できなければならない(SHALL)。公開ドメイン(`vaultwarden.u-rei.com`)経由での`/admin`パスへのリクエストは、送信元IPによらず常に拒否しなければならない(SHALL)。VMが再作成された場合も、startup-scriptの実行により`tailscale serve`によるtailnet限定配信が自動的に復元されなければならない(SHALL)。

#### Scenario: tailnet経由のMagicDNSホスト名からのadminアクセスは許可される
- **WHEN** tailnetに参加した端末が`https://vaultwarden.<tailnet>.ts.net/admin`にアクセスする
- **THEN** 追加の設定なしにリクエストがVaultwardenの管理パネルまで到達する

#### Scenario: 公開ドメイン経由のadminアクセスは常に拒否される
- **WHEN** `vaultwarden.u-rei.com`経由で`/admin`パスへアクセスする(送信元IPがtailnet内であっても)
- **THEN** リバースプロキシ(Caddy)が常に403を返す

#### Scenario: tailnet外からMagicDNSホスト名への到達は失敗する
- **WHEN** tailnetに参加していない端末が`vaultwarden.<tailnet>.ts.net`への到達を試みる
- **THEN** `tailscale serve`がtailnet外からのトラフィックを配信対象としないため到達できない

#### Scenario: VM再作成後もtailnet限定配信が自動的に復元される
- **WHEN** VMが再作成され、startup-scriptが実行される
- **THEN** 人手を介さずに`tailscale serve`の設定が再適用され、`/admin`へのtailnet経由アクセスが復元される
