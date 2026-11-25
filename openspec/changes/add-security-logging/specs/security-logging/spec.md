## ADDED Requirements

### Requirement: Caddyはアクセスログを出力する
システムは、公開ドメインと管理用リスナーが受けたすべてのリクエストを、クライアントIP・メソッド・パス・ステータスを含むJSONのアクセスログとして標準出力へ出力しなければならない(SHALL)。

#### Scenario: 管理画面への外部からの試行が記録される
- **WHEN** 外部のクライアントが公開ドメインの`/admin`へリクエストし、403が返る
- **THEN** クライアントIP・パス・ステータス403がアクセスログに記録される

### Requirement: ログに認証情報を残さない
システムは、`Authorization`・`Cookie`・`Set-Cookie`ヘッダの値、およびURLのクエリに含まれるトークンを、ログに記録してはならない(SHALL NOT)。

#### Scenario: クエリのトークンが除去される
- **WHEN** クライアントが`access_token`をクエリに付けてリクエストする
- **THEN** パスは記録されるが、トークンの値はログのどこにも現れない

### Requirement: コンテナログとjournaldはCloud Loggingへ転送される
システムは、コンテナログを`docker_containers`、journaldを`host_journal`というログ名で、Cloud Loggingへ転送しなければならない(SHALL)。

#### Scenario: SSHの認証の記録が検索できる
- **WHEN** VMへのSSH接続が認証される、または失敗する
- **THEN** その記録が`host_journal`で検索できる

#### Scenario: 保持用bucketに複製される
- **WHEN** アクセスログが出力される
- **THEN** `security-logs` bucketでも検索できる

### Requirement: Dockerのログはローテーションされる
システムは、`daemon.json`の`userland-proxy: false`を保ったまま、json-fileログに`max-size`と`max-file`を設定しなければならない(SHALL)。

#### Scenario: 両コンテナに設定が適用される
- **WHEN** 反映後に`docker inspect`でログの設定を確認する
- **THEN** caddyとvaultwardenの両方に`max-size`と`max-file`が設定されている
