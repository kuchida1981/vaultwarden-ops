## MODIFIED Requirements

### Requirement: 東京リージョンの最安スペックVM
システムは、GCP Compute Engine上にus-west1リージョン(GCP常時無料枠の対象リージョン)、マシンタイプ`e2-micro`、OS Debian 13(trixie)のVMインスタンスをTerraformでプロビジョニングしなければならない(SHALL)。VMのブートディスクおよびVaultwardenデータ用永続ディスクは標準永続ディスク(`pd-standard`)でなければならない(SHALL)。Preemptible/SpotなどVMが強制停止されうる構成は使用しない。

#### Scenario: Terraformでインスタンスが作成される
- **WHEN** `terraform apply`を実行する
- **THEN** us-west1リージョンに`e2-micro`・Debian 13のVMインスタンスが1台作成される

#### Scenario: ディスクが標準永続ディスクである
- **WHEN** `terraform apply`を実行する
- **THEN** ブートディスクとデータ用永続ディスクはいずれも`pd-standard`として作成される
