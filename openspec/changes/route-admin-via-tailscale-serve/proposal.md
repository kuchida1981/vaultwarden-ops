## Why

現在、Vaultwardenの`/admin`パネルはCaddyが送信元IPをTailscaleのCGNAT範囲(100.64.0.0/10)かどうかで判定して制限しているが、`vaultwarden.u-rei.com`の公開DNSはVMの公開IPを指しているため、tailnetに参加した端末であっても素直にこのドメインへアクセスすると常に非tailnet経由のIPとして扱われ403になる。回避策として管理者は自分の端末の`/etc/hosts`にこのホスト名とVMのTailscale IPの対応を手動で書き足す運用になっているが、tailnetに参加している端末であれば本来この編集なしに到達できて然るべきであり、また送信元IPの判定ロジックは過去にDockerの`userland-proxy`設定に起因する誤判定を一度引き起こしている(design.md参照)。

## What Changes

- Vaultwardenの`/admin`パネルを`tailscale serve`でtailnet専用に公開し、TailscaleのMagicDNSホスト名(`https://vaultwarden.<tailnet>.ts.net/admin`)経由で到達できるようにする。証明書の発行・更新はTailscaleに委ねる
- Caddyに`127.0.0.1`限定で待ち受ける内部リスナーを追加し、`tailscale serve`からのリクエストを`/admin`のみvaultwardenへ中継する(送信元IP判定は行わない。到達経路自体がtailnet限定であるため)
- 公開ドメイン(`vaultwarden.u-rei.com`)側の`/admin`ハンドラを、送信元IPによる条件分岐から無条件403へ簡略化する。**BREAKING**: 公開ドメイン経由での`/admin`到達手段(hostsファイル上書きによる回避)が使えなくなる
- startup-scriptに`tailscale serve`設定の冪等な再適用を追加する(VM再作成時にも設定が復元されるように)
- README:
  - `/etc/hosts`編集手順(現行のセットアップ手順9)を削除し、`tailscale serve`のURLへの到達方法に置き換える
  - Tailscale管理コンソールで「HTTPS Certificates」機能を有効化する新しい手動セットアップ手順を追加する

## Capabilities

### New Capabilities

(なし)

### Modified Capabilities

- `tailscale-connectivity`: 管理パネルアクセスの制限方式を、Caddyでの送信元IP判定から`tailscale serve`によるtailnet限定配信へ変更する

## Impact

- `vaultwarden/Caddyfile`: `/admin`ハンドラの条件分岐撤去、内部リスナー追加
- `terraform/main/templates/startup-script.sh.tftpl`: `tailscale serve`設定の冪等適用を追加
- `README.md` / `README.ja.md`: セットアップ手順9(hostsファイル編集)の削除、HTTPS Certificates有効化手順の追加
- Tailscale管理コンソール側の手動設定(HTTPS Certificatesの有効化)が新たに必要になる
