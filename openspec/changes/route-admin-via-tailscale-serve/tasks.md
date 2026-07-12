凡例: **[あなた]** = ブラウザ操作・実機での確認・マージ承認などユーザー本人が行う必要があるステップ / **[実装]** = コード変更としてこの場で実施するステップ

## 1. Tailscale管理コンソールの手動設定

- [ ] 1.1 **[あなた]** Tailscale管理コンソールで「HTTPS Certificates」機能を有効化する(tailnet単位、Terraform管理外。ブラウザでの操作が必要)

## 2. Caddyfileの変更

- [ ] 2.1 **[実装]** `127.0.0.1`限定で待ち受ける内部リスナー(例: `:8080`)を追加し、`/admin*`のみを`vaultwarden:80`へ中継する設定を書く
- [ ] 2.2 **[実装]** 公開ドメイン(`{$DOMAIN}`)側の`/admin`ハンドラから送信元IP判定(`@not_tailnet`)を撤去し、無条件403を返すよう変更する
- [ ] 2.3 **[実装]** 変更後のCaddyfileをローカルの`docker compose`で起動し、公開側`/admin`が常に403になること、内部リスナー経由では到達できることを確認する

## 3. startup-scriptへの`tailscale serve`設定追加

- [ ] 3.1 **[実装]** `terraform/main/templates/startup-script.sh.tftpl`に、`tailscale serve`で`/admin`を内部リスナー(`localhost:8080`等)へフォワードする設定を追加する
- [ ] 3.2 **[実装]** 既存の`tailscale up`と同様、既に設定済みかどうかを確認してから適用する冪等な形にする(VM再作成時にも安全に再実行できること)
- [ ] 3.3 **[実装]** `tailscale serve`と`tailscale funnel`の違い、および誤って`funnel`を使うと`/admin`がインターネット全体に公開されてしまう旨を警告するコメントを追加する

## 4. デプロイと動作確認

- [ ] 4.1 **[あなた]** 変更をmainにマージし、GitHub ActionsのGitHub Environment承認ゲートを承認してVMに反映する(マージ・承認はリポジトリ権限を持つ本人が行う)
- [ ] 4.2 **[あなた]** 公開ドメイン経由で`/admin`にアクセスし、常に403が返ることを確認する(tailnet内外どちらの送信元でも。実機のブラウザでの確認)
- [ ] 4.3 **[あなた]** tailnetに参加した自分の端末から`https://vaultwarden.<tailnet>.ts.net/admin`にアクセスし、追加設定なしに管理パネルへ到達できることを確認する
- [ ] 4.4 **[あなた]** tailnetに参加していない端末(例: モバイル回線のスマートフォン)から`vaultwarden.<tailnet>.ts.net`への到達を試み、失敗することを確認する
- [ ] 4.5 **[あなた]** VM再作成(または`startup-script`の再実行)後も、`tailscale serve`経由での`/admin`アクセスが自動的に復元されることを確認する

## 5. README更新

- [ ] 5.1 **[実装]** `README.md`/`README.ja.md`のセットアップ手順9(`/etc/hosts`編集手順)を削除する
- [ ] 5.2 **[実装]** 新しいadmin到達方法(`https://vaultwarden.<tailnet>.ts.net/admin`)の説明に置き換える
- [ ] 5.3 **[実装]** Tailscale管理コンソールでのHTTPS Certificates有効化手順を、既存のOAuthクライアント発行手順などと同様の形式でREADMEに追加する
- [ ] 5.4 **[実装]** セットアップ手順10(動作確認)の記述を、新しい到達方法・確認内容に合わせて更新する
