## ADDED Requirements

### Requirement: 承認ゲート付きvaultwardenデプロイパイプライン
システムは、`vaultwarden/**`配下のファイルが`main`ブランチにマージされた際、GitHub Actionsのワークフローを起動しなければならない(SHALL)。このワークフローは、既存の`production` GitHub Environmentによる人間の承認を経てからのみ、本番VMへの反映処理を実行しなければならない(SHALL)。承認なしに反映処理が自動実行されてはならない(SHALL NOT)。反映処理は、VM自体の再起動(reboot/reset)を伴わず、変更のあったdocker composeサービスのみを再作成する形で行われなければならない(SHALL)。

#### Scenario: vaultwarden/配下の変更でワークフローが起動する
- **WHEN** `vaultwarden/docker-compose.yml`を含むコミットが`main`にマージされる
- **THEN** vaultwardenデプロイワークフローが起動し、`production` Environmentの承認待ち状態で一時停止する

#### Scenario: 承認後にVMへ反映される
- **WHEN** 承認者が待機中のデプロイジョブを承認する
- **THEN** CIランナーがVMに接続し、`git pull`・`docker compose pull`・`docker compose up -d`が実行され、変更のあったコンテナのみが再作成される

#### Scenario: VMは再起動されない
- **WHEN** デプロイジョブが実行される
- **THEN** VMインスタンス自体のreboot/resetは発生せず、caddyの証明書・設定データ(`caddy_data`・`caddy_config`)を保持したコンテナ再作成のみが行われる

#### Scenario: デプロイ失敗が明示的に可視化される
- **WHEN** `git pull --ff-only`がfast-forwardできない、またはVM上のコマンドが非ゼロ終了する
- **THEN** デプロイジョブは失敗として終了し、フォールバック処理による握りつぶしは行われない

### Requirement: CI用サービスアカウントによるIAP tunnel経由のVMアクセス
システムは、Terraform CI用サービスアカウントに対し、GCP Identity-Aware Proxy(IAP) tunnel経由でVMへSSH接続するために必要な最小限のIAM権限(`roles/iap.tunnelResourceAccessor`・`roles/compute.osAdminLogin`)のみを付与しなければならない(SHALL)。この権限はTailscale ACLやVM実行時サービスアカウントには一切影響してはならない(SHALL NOT)。VMへのファイアウォール到達は、IAPの専用ソースレンジからのtcp:22のみに限定しなければならない(SHALL)。

#### Scenario: CI用SAがIAP tunnel経由でSSHできる
- **WHEN** GitHub ActionsのワークフローがWIF経由でCI用SAとして認証し、IAP tunnel経由でVMへSSHを試みる
- **THEN** OS Loginにより一時的なSSH鍵が自動発行され、接続に成功する

#### Scenario: Tailscale ACLが変更されない
- **WHEN** このIAM権限追加をTerraform applyする
- **THEN** `tailscale_acl`リソースの内容に変更が生じない

#### Scenario: IAP専用レンジ以外からのSSHは引き続き到達できない
- **WHEN** GCPの新規ファイアウォールルールの内容を確認する
- **THEN** ソースレンジはIAPの専用レンジ(`35.235.240.0/20`)のみであり、`vaultwarden-server`タグを持つVM以外には適用されない

### Requirement: 承認前のバージョン差分可視化
システムは、`vaultwarden-deploy.yml`のワークフロー実行のジョブサマリーに、直近の承認済みデプロイ以降で変更された`vaultwarden/docker-compose.yml`内の`image:`行の差分を出力しなければならない(SHALL)。この差分は、rejectされた過去の実行がコミットとして`main`に残っている場合でも、実際に承認・反映された最後のデプロイを基準に計算しなければならない(SHALL)。

#### Scenario: ジョブサマリーにimageの差分が表示される
- **WHEN** `vaultwarden/docker-compose.yml`内の`image:`行が変更されたコミットで`vaultwarden-deploy.yml`が起動する
- **THEN** ワークフロー実行のジョブサマリーに、変更前後の`image:`行の差分が表示される

#### Scenario: 承認済みデプロイを基準に差分が計算される
- **WHEN** デプロイジョブの承認が完了する
- **THEN** そのコミットを指す`vaultwarden-last-deploy`タグがforce-pushされ、次回実行時の差分計算の基準点として使われる
