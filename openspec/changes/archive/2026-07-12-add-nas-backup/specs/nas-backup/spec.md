## ADDED Requirements

### Requirement: 毎日自動的にバックアップが実行される
システムは、systemdのtimerユニットにより、1日1回、VM上でバックアップ処理を自動実行しなければならない(SHALL)。cronは使用しない。

#### Scenario: 深夜帯にバックアップが起動する
- **WHEN** 設定されたスケジュール時刻(03:00 JST)になる
- **THEN** systemdが`backup.service`を起動し、バックアップ処理が実行される

### Requirement: SQLiteデータベースは一貫性のあるスナップショットとしてバックアップされる
システムは、稼働中のVaultwardenを停止せずに、SQLiteのオンラインバックアップ機能(`sqlite3 .backup`相当)を用いて一貫性のあるデータベーススナップショットを作成し、それをバックアップ対象に含めなければならない(SHALL)。稼働中の`db.sqlite3`・`-wal`・`-shm`ファイルをそのまま転送してはならない(SHALL NOT)。

#### Scenario: バックアップ中もVaultwardenは応答し続ける
- **WHEN** バックアップ処理が実行されている間
- **THEN** Vaultwardenコンテナは停止されず、ユーザーからのリクエストに応答し続ける

#### Scenario: バックアップされるDBファイルは一貫性がある
- **WHEN** バックアップ処理がNASに転送するデータベースファイルを生成する
- **THEN** そのファイルはSQLiteのオンラインバックアップ機能で生成された、破損のないスナップショットである

### Requirement: バックアップ対象は復旧に必要な全データを含む
システムは、データベーススナップショットに加えて、添付ファイル(`attachments/`)、Send(`sends/`)、署名鍵(`rsa_key.pem`・`rsa_key.pub.pem`)、管理パネル設定(`config.json`)をバックアップ対象に含めなければならない(SHALL)。自動再生成可能なキャッシュ(`icon_cache/`)は転送量削減のため対象から除外してよい(MAY)。

#### Scenario: 復旧に必要なファイルがすべて含まれる
- **WHEN** バックアップ処理がNASへの転送内容を確定する
- **THEN** 転送対象には一貫性のあるDBスナップショット、`attachments/`、`sends/`、`rsa_key.pem`、`rsa_key.pub.pem`、`config.json`が含まれる

### Requirement: バックアップはTailscaleネットワーク内でのみ転送される
システムは、VMからNASへのバックアップ転送を、Tailscaleのプライベートネットワーク経由でのみ行わなければならない(SHALL)。公開インターネット上にバックアップ用のポートやエンドポイントを晒してはならない(SHALL NOT)。

#### Scenario: 転送はTailscale経由のホストに対して行われる
- **WHEN** バックアップ処理がNASへの接続を確立する
- **THEN** 接続先はNASのTailscale IPアドレスまたはMagicDNSホスト名であり、公開IPアドレスではない

### Requirement: バックアップ転送の認証情報はSecret Managerで管理される
システムは、rsyncデーモンへの接続に用いるパスワードをGoogle Secret Managerに保管し、VM実行時サービスアカウントの最小権限アクセスで取得しなければならない(SHALL)。認証情報をVMのメタデータ(startup-script)やリポジトリに平文で含めてはならない(SHALL NOT)。

#### Scenario: バックアップ認証情報はSecret Manager経由でのみ取得される
- **WHEN** startup-scriptがバックアップ処理の設定を行う
- **THEN** rsyncdパスワードはSecret Manager APIから取得され、VM上のパーミッション600のローカルファイルにのみ書き込まれる

### Requirement: バックアップの世代管理はNAS側に委譲される
システムは、バックアップデータの世代管理(保持期間・世代数)をVM側では行わず、NAS側のスナップショット機能に委譲しなければならない(SHALL)。VM側は最新状態への上書き同期のみを行う。

#### Scenario: VM側は最新の1世代のみを保持する
- **WHEN** バックアップ処理がNASへの転送を完了する
- **THEN** VM側のバックアップステージング領域には最新の1世代分のデータのみが存在し、過去の世代はNAS側のスナップショットとしてのみ存在する

### Requirement: リストア手順が文書化され検証されている
システムは、NASのバックアップからVaultwardenのデータを復元する手順をドキュメント化しなければならない(SHALL)。当該手順は実際に1回リストアを行うことで検証されなければならない(SHALL)。

#### Scenario: 文書化された手順でリストアが成功する
- **WHEN** 文書化されたリストア手順に従って、NASのバックアップからVMのデータディレクトリを復元する
- **THEN** Vaultwardenが正常に起動し、既存ユーザーでのログイン・既存添付ファイルへのアクセスができる
