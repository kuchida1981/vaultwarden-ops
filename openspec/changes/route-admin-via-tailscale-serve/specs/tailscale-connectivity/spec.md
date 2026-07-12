## MODIFIED Requirements

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
