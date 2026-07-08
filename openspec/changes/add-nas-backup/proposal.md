## Why

現在、Vaultwardenのデータ(SQLite DB・添付ファイル・Send)はVMに接続された永続ディスク1本にしか存在せず、ディスク障害や誤操作(誤destroy等)が起きた場合の復旧手段がない。README.mdのロードマップに「NASへの定期バックアップ」として記載済みの項目であり、GitHub issue #11で具体化されている。家族の実データを預かって運用している以上、この単一障害点は早めに解消したい。

## What Changes

- VM上にsystemd timer(1日1回、深夜帯)を追加し、バックアップ処理を自動実行する
- バックアップ処理は`sqlite3 .backup`コマンドで一貫性のあるDBスナップショットを作成し(Vaultwardenを停止せずに実施)、`/data`ディレクトリ全体(添付ファイル・Send・署名鍵`rsa_key*.pem`・`config.json`。再生成可能な`icon_cache/`のみ除外)と合わせてステージング領域にまとめる
- ステージング領域から自宅Synology NASへ、rsyncデーモン(`rsync://`)経由でpush同期する。認証はTailscale WireGuardトンネル内で完結するrsyncdのユーザー/パスワードのみとし、SSH鍵の発行・管理は行わない
- rsyncdの接続パスワードは、既存の`admin_token`/`tailscale_authkey`/SMTP認証情報と同じパターンでGoogle Secret Managerに保管し、VM実行時サービスアカウントに最小権限で読み取りを許可する
- バックアップの世代管理(保持期間・世代数)はVM側では行わず、NAS側のBtrfsスナップショット機能に委譲する(daily×7, weekly×4, monthly×3のGFS方式を初期値として提案。NAS側のGUI設定のみで完結し、コード変更なしに後から調整可能)
- README.mdに、NAS側で必要な手動セットアップ手順(Rsyncサーバー有効化、共有フォルダ・アカウント作成、スナップショットスケジュール設定)とリストア手順を追記する
- ロードマップの記載を更新し、「NASへの定期バックアップ」を実施済みの扱いに変更する

## Capabilities

### New Capabilities
- `nas-backup`: VMからSynology NASへの定期バックアップ(スケジューリング、DB一貫性の確保、rsyncデーモンによる転送、認証情報管理、世代管理の委譲、リストア手順)

### Modified Capabilities
(なし。新しいSecret Managerシークレットの追加は`gcp-infrastructure`スペックの既存要件「機密情報はSecret Managerで最小権限管理」の適用範囲内であり、要件自体の変更は発生しない)

## Impact

- `terraform/main/variables.tf`: NAS接続用の変数を追加(ホスト名/モジュール名/ユーザー名は非機密のデフォルト値付き変数、パスワードはデフォルトなしのsensitive変数)
- `terraform/main/secrets.tf`: rsyncdパスワード用のSecret Manager secretを追加
- `terraform/main/iam.tf`: VM実行時サービスアカウントへの新シークレットの読み取り権限を追加
- `terraform/main/compute.tf`, `terraform/main/templates/startup-script.sh.tftpl`: 新シークレットのfetch、systemd timer/serviceユニットの配置、バックアップスクリプトの配置を追加
- 新規ファイル: バックアップ処理本体のシェルスクリプト、systemdユニットファイル(timer/service)
- `.github/workflows/terraform-plan.yml`, `terraform-apply.yml`: 新しいsensitive変数をGitHub SecretsからTF_VARとして渡す配線を追加
- `README.md`: NAS側の手動セットアップ手順、リストア手順の追記。ロードマップの記載更新
- GitHub Actions Secrets: NAS用rsyncdパスワードの新規登録が必要(ユーザーの手動作業)
- 前提作業(ユーザー側・手動): NAS側でRsyncサーバーの有効化、バックアップ用共有フォルダとアカウントの作成、Btrfsスナップショットスケジュールの設定
