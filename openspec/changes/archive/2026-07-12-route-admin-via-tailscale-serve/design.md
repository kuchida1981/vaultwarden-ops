## Context

`/admin`パネルのtailnet制限は現在、Caddyが送信元IPをTailscaleのCGNAT範囲(100.64.0.0/10)かどうかで判定する方式(`tailscale-connectivity`スペックの「管理パネルアクセスのtailnet制限」要件)で実現している。しかし`vaultwarden.u-rei.com`の公開DNS Aレコードは常にVMの公開IPを指すため、tailnetに参加した端末から素直にこのホスト名へアクセスしても、トラフィックはTailscaleのWireGuardトンネルを通らず公開インターネット経由になり、送信元IPはtailnet外として判定され403になる。現行の回避策(管理者の端末の`/etc/hosts`にこのホスト名とVMのTailscale IPを手動追記する)は、tailnetに参加しているだけでは自動的に機能しない点が使い勝手上の課題であり、また過去にDockerの`userland-proxy`設定に起因して送信元IP判定そのものが誤動作した実績がある(`add-vaultwarden-hosting`のdesign.md参照)。

この変更は、tailnetに参加している端末(現状は管理者本人の端末のみ)であれば追加のDNS/hosts操作なしに`/admin`へ到達できるようにし、あわせて送信元IP判定という壊れやすいロジックを撤去することを目的とする。

## Goals / Non-Goals

**Goals:**
- tailnetに参加している端末から、`/etc/hosts`編集などの手動DNS操作なしに`/admin`へ到達できるようにする
- 公開ドメイン経由での`/admin`到達を完全に遮断し、送信元IP判定という壊れやすい仕組みを排除する
- VMが再作成された場合でも、startup-scriptの再実行だけで`/admin`へのtailnet経由アクセスが自動的に復元される

**Non-Goals:**
- 通常のvault利用(パスワード閲覧・保存など)を`tailscale serve`経由に移行すること — 引き続き公開ドメイン経由のみとする
- tailnetへの家族の参加を想定した設計にすること — 現状、自分以外がtailnetに参加することは想定しない
- Tailscale Split DNSなど、他の恒久対応手段の実装(design検討時に比較した代替案であり、今回は不採用)

## Decisions

### 1. `tailscale serve`によるtailnet限定配信を採用(Split DNS方式は不採用)

`/admin`をtailnetからDNS操作なしで到達可能にする手段として、以下を比較した。

| 案 | 概要 | 評価 |
|---|---|---|
| A. Tailscale Split DNS | `u-rei.com`の名前解決をtailnet内の自前DNSサーバーに委譲し、tailnet内では`vaultwarden.u-rei.com`をTailscale IPに解決させる | 新たにDNSサーバー(dnsmasq等)をVM上で運用する必要があり、既存構成を保ったまま穴を塞ぐ方向。運用コンポーネントが1つ増える |
| B. `tailscale serve`(採用) | Tailscaleの組み込み機能でMagicDNSホスト名(`vaultwarden.<tailnet>.ts.net`)にTLS終端込みで公開し、tailnet内からのみ到達可能にする | DNSサーバー運用が不要、証明書の発行・更新もTailscaleに任せられる。経路そのものをシンプルにする方向 |
| C. 専用サブドメイン + Split DNS | Aのバリエーション。公開DNSに存在しないサブドメインだけをSplit DNSでtailnet内に解決 | Aと同様の運用コスト増があり、Bに対する優位性が薄い |

Bを採用する。理由: 新規の運用コンポーネント(DNSサーバー)を増やさずに済み、TLS証明書の発行・更新もTailscaleに一任できるため、design.mdで過去に指摘された「送信元IPのすり替わり」のような細かい実装バグの余地を増やさない。

### 2. `tailscale serve`は`/admin`のみを対象とし、アプリ全体は公開しない

`tailscale serve`で公開する範囲を「`/admin`のみ」と「Vaultwardenアプリ全体」で比較した。通常のvault利用は普段どおり公開ドメイン(`vaultwarden.u-rei.com`)から行えば十分であり、admin作業時にのみ別ホスト名を使う運用の方が、公開ドメインと`ts.net`ドメインのどちらでもvault本体が使えてしまう曖昧さを避けられる。したがって`/admin`のみを対象とする。

実装上は、Caddyに`127.0.0.1`限定のリスナー(例: `:8080`)を追加し、そこでは`/admin*`のみを`vaultwarden:80`へ中継する。`tailscale serve`はこのローカルポートへフォワードする。

### 3. 公開ドメイン側の`/admin`は無条件403に簡略化(案X、案Yのフォールバック維持は不採用)

tailnet経由の正規到達経路を`tailscale serve`に一本化した上で、公開ドメイン(`vaultwarden.u-rei.com`)側の`/admin`ハンドラをどうするか、次の2案を比較した。

- 案X(採用): 送信元IP判定を撤去し、`/admin*`は常に403を返す
- 案Y(不採用): 送信元IP判定を残し、`tailscale serve`側が使えない場合のフォールバック経路として維持する

案Yは、`tailscale serve`に問題が起きた場合の代替到達手段になる一方、過去に一度誤動作した送信元IP判定ロジックをそのまま残すことになる。今回の変更の主眼が「壊れやすい条件分岐を除去してシンプルにする」ことにあるため、案Xを採用する。`tailscale serve`自体に問題が生じた場合は、`tailscale ssh`でVMに直接入って調査・復旧する。

### 4. 内部リスナーでは送信元IPやトークンの追加チェックを行わない

`127.0.0.1`限定リスナーは、GCPファイアウォールでもDockerのポートマッピングでも外部に公開されず、到達経路は「tailnet経由で`tailscale serve`がフォワードしたトラフィックのみ」に限定される。したがってCaddy側で追加の送信元IPチェックは行わない。ADMIN_TOKENによる認証(`vaultwarden-service`スペック)は既存のまま維持され、多層防御の最終層として機能する。

## Risks / Trade-offs

- [リスク] `tailscale serve`ではなく`tailscale funnel`を誤って設定すると、`/admin`がインターネット全体に公開されてしまう → startup-scriptの該当箇所に、`serve`と`funnel`の違いと影響範囲を明記したコメントを残し、誤操作を防ぐ
- [リスク] `tailscale serve`の設定はVM再作成時に失われる(auth keyと同様、永続化されない) → `tailscale up`と同じくstartup-scriptで冪等に再適用する(既に`serve`設定済みかどうかを`tailscale serve status`等で確認してから適用する)
- [リスク] tailnet単位で「HTTPS Certificates」機能が無効な場合、`tailscale serve`は証明書を発行できず失敗する → README新規手順として、Tailscale管理コンソールでの有効化を明記する(Terraformでは管理できない性質の設定のため、既存のOAuthクライアント発行手順と同様に手動ステップとして文書化)
- [トレードオフ] 公開ドメイン側の`/admin`を無条件403にすることで、`tailscale serve`に障害が起きた場合のフォールバック到達経路がなくなる → `tailscale ssh`によるVM直接操作を復旧手段として許容する(README不要、既存のSSHアクセス経路がそのまま使える)
- [トレードオフ] adminがブックマークするURLが`https://vaultwarden.u-rei.com/admin`から`https://vaultwarden.<tailnet>.ts.net/admin`に変わる。運用者本人の一度きりの学習コストとして許容する

## Migration Plan

1. `vaultwarden/Caddyfile`に`127.0.0.1`限定の内部リスナーを追加し、`/admin*`のみを中継するよう変更。公開ドメイン側の`/admin`ハンドラを無条件403に変更
2. `terraform/main/templates/startup-script.sh.tftpl`に`tailscale serve`設定の冪等適用を追加
3. Tailscale管理コンソールでHTTPS Certificates機能を手動で有効化(既存VMには影響しない、tailnet単位の設定)
4. 変更をmainにマージし、GitHub Actionsのapproval gateを経てVMのstartup-scriptを再実行(または`docker compose`の再デプロイ + 手動での`tailscale serve`再設定)し反映
5. 動作確認: 公開ドメイン経由の`/admin`が常に403になること、`https://vaultwarden.<tailnet>.ts.net/admin`がtailnet参加端末から到達できること、tailnet外からは`*.ts.net`ホスト名が到達不能であることを確認
6. README手順9(hostsファイル編集)を削除し、新しい到達方法とHTTPS Certificates有効化手順に置き換える

ロールバックは、Caddyfileと該当startup-script変更を含むコミットをrevertし再apply/再デプロイすることで、旧来の送信元IP判定方式に戻せる。

- [リスク、実カットオーバー時に発覚] `tailscale serve --set-path=/admin`は、マウントポイントとして指定したパスをバックエンドへの転送時にstripしてしまう(`/admin`へのリクエストがバックエンドには`/`として届く)ため、内部Caddyの`handle /admin* {...}`にマッチせず404になっていた。さらに、stripを補正して`/admin`を付け直しても、Vaultwardenのadminパネル自身が静的アセット(CSS/JS/画像)を`/vw_static/...`という`/admin`外の絶対パスで参照しているため、ページ自体は200になってもスタイルもJSも読み込めず実質機能しない状態になることが判明した → `tailscale serve`は`/admin`ではなくサイトルート(`/`)にマウントし、パスの絞り込みは内部Caddy側(`handle /admin*`と`handle /vw_static/*`のみ許可、それ以外は404)で行う方式に修正した。これにより`/`・`/api`・`/identity`など本来のvault機能はtailnet経由でも到達不能なまま維持しつつ、adminパネルと必要な静的アセットのみ到達可能にしている

## Open Questions

(なし。設計方針は探索の中で確定済み)
