## 1. 事前準備(ユーザー作業・NAS側)

- [x] 1.1 NASのコントロールパネル→ファイルサービスで「Rsyncサーバー」を有効化する
- [x] 1.2 バックアップ受け入れ用の共有フォルダを新規作成する(Btrfs上のボリュームであることを確認)(`vaultwarden-backups`)
- [x] 1.3 バックアップ専用アカウントを作成し、手順1.2の共有フォルダへの読み書き権限のみを付与する。発行したパスワードを控える(アカウント名`vaultwarden`)
- [x] 1.4 手順1.2の共有フォルダにスナップショットスケジュールを設定する(daily保持7世代、weekly保持4世代、monthly保持3世代。スケジュールは毎日04:30)
- [x] 1.5 VMからNASのMagicDNSホスト名(`synology-nas`)への疎通を再確認する(`tailscale ping synology-nas`)

## 2. Terraform: 変数とSecret Manager

- [x] 2.1 `terraform/main/variables.tf`にNAS接続用の変数を追加する: ホスト名/rsyncモジュール名/rsyncdユーザー名はデフォルト値付きの非sensitive変数(`synology-nas` / `vaultwarden-backups` / `vaultwarden`)、パスワードはデフォルトなしのsensitive変数
- [x] 2.2 `terraform/main/secrets.tf`にrsyncdパスワード用のSecret Manager secret(`vaultwarden-nas-backup-password`)を追加する
- [x] 2.3 `terraform/main/iam.tf`にVM実行時サービスアカウントへの新シークレット読み取り権限(`secretAccessor`)を追加する

## 3. バックアップスクリプトとsystemdユニット

- [x] 3.1 バックアップ本体のシェルスクリプトを作成する(`sqlite3 .backup`でのDBスナップショット生成 → `icon_cache/`除外でステージング領域へミラー → rsyncdへpush、の3ステップ)
- [x] 3.2 `backup.service`(Type=oneshot)ユニットファイルを作成する。rsyncdパスワードファイルのパスと接続先(ホスト/モジュール/ユーザー名)を環境変数または引数として渡す
- [x] 3.3 `backup.timer`ユニットファイルを作成する(`OnCalendar=*-*-* 03:00:00`、`RandomizedDelaySec`で多少分散させる)
- [x] 3.4 `rsync`パッケージがVMのapt installリストに含まれていることを確認する(未導入なら追加)(`sqlite3`も併せて追加)

## 4. Terraform: VM起動時の設定反映

- [x] 4.1 `terraform/main/compute.tf`のstartup-script呼び出しに、NAS接続情報(非機密のホスト/モジュール/ユーザー名)と新シークレットIDを渡す
- [x] 4.2 `terraform/main/templates/startup-script.sh.tftpl`で新シークレットをfetchし、パーミッション600のパスワードファイルとして配置する
- [x] 4.3 startup-scriptで、手順3のバックアップスクリプト・`backup.service`・`backup.timer`をVM上の所定パスに配置し、`systemctl enable --now backup.timer`を実行する(冪等に、既存タイマーの再作成に対応できる形で)
- [x] 4.4 `compute.tf`の`depends_on`に新しいSecret Managerリソースを追加する(既存のadmin_token/tailscale_authkeyと同様)

## 5. GitHub Secrets登録とapply

- [x] 5.1 `.github/workflows/terraform-plan.yml`・`terraform-apply.yml`に新しいsensitive変数のTF_VAR配線を追加する(既存の`tailscale_oauth_client_id/secret`と同じパターン)
- [ ] 5.2 GitHub Actions Secretsに、手順1.3で発行したNASのrsyncdパスワードを登録する
- [ ] 5.3 PRを作成し`terraform plan`で差分を確認する(新規リソースのみで既存リソースの破壊的変更がないこと)
- [ ] 5.4 `main`マージ後、GitHub Environmentの承認を経て`terraform apply`を実行する
- [ ] 5.5 VM上でstartup-scriptが再実行され(または再起動により)、`backup.timer`が有効化されたことを確認する(`systemctl status backup.timer`)

## 6. 動作確認

- [ ] 6.1 `systemctl start backup.service`で初回バックアップを手動トリガーし、正常終了(exit code 0)することを確認する
- [ ] 6.2 NAS側の共有フォルダに、DBスナップショット・`attachments/`・`sends/`・`rsa_key.pem`・`rsa_key.pub.pem`・`config.json`が転送されており、`icon_cache/`が含まれていないことを確認する
- [ ] 6.3 バックアップ実行中もVaultwardenへのアクセス(ログイン等)が問題なくできることを確認する
- [ ] 6.4 2回目以降の実行で、NAS側のスナップショットが設定通りのタイミング・世代数で作成されていることを確認する

## 7. リストア検証

- [ ] 7.1 design.mdに記載したリストア手順(NASスナップショット選択 → Vaultwarden停止 → 現行データ退避 → 復元 → 権限確認 → 起動確認)を実地で1回通しで実行する
- [ ] 7.2 復元後、既存ユーザーでのログイン、既存添付ファイルへのアクセス、`/admin`のユーザー一覧が正しいことを確認する
- [ ] 7.3 検証中に手順の過不足が見つかった場合はdesign.mdのリストア手順を修正する

## 8. README更新

- [x] 8.1 NAS側の手動セットアップ手順(手順1.1〜1.4相当)を、TailscaleやBrevoの手動手順と同じ書式でREADME.mdのセットアップ手順に追記する
- [ ] 8.2 検証済みのリストア手順をREADME.mdに追記する(下書きは追記済み。手順7の実地検証が済むまで「未検証」の注記を残す)
- [x] 8.3 ロードマップの「NASへの定期バックアップ」の記載を実施済みの内容に更新する
