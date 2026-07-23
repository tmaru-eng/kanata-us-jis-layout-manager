# ファイル構成とPS1の役割

## ルート直下

### `Bootstrap-KanataWintercept.ps1`

初回導入用です。`bin\` に同梱しているパッチ版Kanataと `interception.dll` を `%LOCALAPPDATA%\KanataLayoutManager\runtime` に配置し、必要に応じてInterceptionドライバのインストーラを管理者権限で起動します。最後に `Install-KanataLayoutManager.ps1` を呼びます。

### `Install-KanataLayoutManager.ps1`

管理ツールのインストーラです。`src\` の管理スクリプトと `config\` のKanata設定を `%LOCALAPPDATA%\KanataLayoutManager` にコピーし、ログオン時とPnPイベント時に起動するタスクスケジューラを登録します。既存の状態ファイルがある場合は、公開用の空テンプレートをコピーした後に登録済みHWIDを復元します。

### `Uninstall-KanataLayoutManager.ps1`

アンインストーラです。タスクスケジューラの登録と `%LOCALAPPDATA%\KanataLayoutManager` を削除します。Interceptionドライバ自体は削除しません。

## `src\`

インストール先へコピーされ、実際の運用で使われる管理スクリプトです。

### `Invoke-KanataLayoutManager.ps1`

タスクスケジューラから呼ばれる常駐管理入口です。登録済みUSキーボードが1台でもあればKanataを起動します。キーボード登録ウィザードは開きません。

### `KanataLayout.Common.ps1`

共通関数群です。保存状態の読み書き、HWID変換、接続中キーボードの取得、Kanata設定更新、Kanataの停止/起動を担当します。

### `Reconfigure-KanataKeyboard.ps1`

手動のキーボード登録・再設定ウィザードです。対象キーボードでキーを押してKanata HWIDを取得し、US/JISの判定を保存して設定を更新します。

### `Show-KanataKeyboardProfiles.ps1`

登録済みキーボードの表示名、US/JIS、接続状態、更新日時を表示します。

### `Test-KanataLayoutManager.ps1`

外部キーボードなしでできる自己診断です。PowerShell構文、Kanata設定、実行ファイル、DLL、タスク登録を確認します。

## その他のディレクトリ

- `config\`: Kanataのリマップ設定。インストール時はファイル名を変えずにインストール先へコピーします。
- `launchers\`: `.ps1` を直接実行しなくてよいようにするダブルクリック用 `.cmd` です。実運用で人が触る入口です。
- `docs\`: 実運用手順、IME検証、署名エラー対策、Kanataパッチ説明です。
- `docs\licenses\`: サードパーティライセンス本文と upstream README のコピーです。
- `bin\`: 同梱バイナリです。
- `deploy\`: 個人環境依存の導入補助や状態ファイルです。`.gitignore` 対象です。
