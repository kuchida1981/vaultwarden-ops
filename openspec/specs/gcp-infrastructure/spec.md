## Purpose

TerraformによるGCE VM/静的IP/ファイアウォール/永続ディスク/Secret Managerのプロビジョニングを管理する。東京リージョン(asia-northeast1)で最安スペックのVMを構成し、公開インターネットに晒される環境として妥当な最低限のセキュリティ(ファイアウォール制限、機密情報の最小権限管理、OS自動セキュリティ更新)を組み込む。

## Requirements

### Requirement: 東京リージョンの最安スペックVM
システムは、GCP Compute Engine上に東京リージョン(asia-northeast1)、マシンタイプ`e2-micro`、OS Debian 13(trixie)のVMインスタンスをTerraformでプロビジョニングしなければならない(SHALL)。Preemptible/SpotなどVMが強制停止されうる構成は使用しない。

#### Scenario: Terraformでインスタンスが作成される
- **WHEN** `terraform apply`を実行する
- **THEN** asia-northeast1リージョンに`e2-micro`・Debian 13のVMインスタンスが1台作成される

### Requirement: 静的External IPの永続化
システムは、VMに静的External IPを割り当て、VMインスタンスが再作成された場合でも同一のIPアドレスを維持しなければならない(SHALL)。

#### Scenario: VM再作成後もIPが変わらない
- **WHEN** VMインスタンスがdestroy&createされる
- **THEN** 静的External IPリソースは削除されず、新しいVMに再アタッチされ、外部から見えるIPアドレスは変化しない

### Requirement: 公開ファイアウォールは80/443のみ
システムは、インターネットからのインバウンド接続を80番・443番ポートのみに制限しなければならない(SHALL)。SSH(22番)を含むそれ以外のポートは公開ファイアウォールルールで許可しない。

#### Scenario: 公開ポートからのSSH接続が拒否される
- **WHEN** インターネット上の任意のホストからVMの外部IPの22番ポートへ接続を試みる
- **THEN** GCPファイアウォールにより接続がブロックされる

### Requirement: Vaultwardenデータ用の専用永続ディスク
システムは、Vaultwardenのデータ(データベース、暗号鍵、添付ファイル)を保存するための、VM本体のライフサイクルから独立した永続ディスクを作成しなければならない(SHALL)。当該ディスクはTerraformの`prevent_destroy`ライフサイクル設定により誤destroyから保護されなければならない(SHALL)。

#### Scenario: VM再作成後もデータディスクが残る
- **WHEN** VMインスタンスのみがTerraformによりdestroy&createされる
- **THEN** データ用永続ディスクは削除されず、新しいVMインスタンスに再アタッチされてデータが引き継がれる

### Requirement: 機密情報はSecret Managerで最小権限管理
システムは、ADMIN_TOKENやTailscale認証キーなどの機密情報をGoogle Secret Managerに保管しなければならない(SHALL)。VMに付与する実行時サービスアカウントは、自身が必要とするシークレットに対する`roles/secretmanager.secretAccessor`のみを持ち、それ以外のシークレットや書き込み権限を持ってはならない(SHALL NOT)。Terraform/CI用の管理サービスアカウントとVM実行時サービスアカウントは別々に定義しなければならない(SHALL)。

#### Scenario: VM実行時SAは割り当てられたシークレットのみ読み取れる
- **WHEN** VMの実行時サービスアカウントが自身に割り当てられたシークレットのバージョンにアクセスする
- **THEN** アクセスに成功し、平文の値が取得できる

#### Scenario: VM実行時SAは他のシークレットにアクセスできない
- **WHEN** VMの実行時サービスアカウントが自身に割り当てられていない別のシークレットへのアクセスを試みる
- **THEN** IAM権限不足によりアクセスが拒否される

### Requirement: OSの自動セキュリティ更新
システムは、Debian VM上でセキュリティパッチの自動適用(unattended-upgrades相当の仕組み)を有効化しなければならない(SHALL)。

#### Scenario: セキュリティパッチが無人で適用される
- **WHEN** Debianのセキュリティリポジトリに新しいパッチが公開される
- **THEN** 手動操作なしに、VM上の定期実行タイミングでそのパッチが自動的に適用される
