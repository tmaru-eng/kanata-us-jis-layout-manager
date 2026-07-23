# kanata-us-jis-layout-manager

Windows本体のJISキーボード設定・内蔵JISキーボードをそのまま使いながら、外付けの物理ANSI USキーボードだけを**JIS相当として補正**するためのツール一式です。
[kanata](https://github.com/jtroo/kanata) (wintercept版=Interceptionドライバ) と、キーボードをHWIDで判別して自動起動するPowerShell製マネージャで構成されています。

この構成の目的は、Windows側のキーボード種別をUSへ切り替えず、内蔵キーボードや本体側JIS配列との共用を維持することです。登録したUSキーボードだけを補正対象にするため、JISキーボードは通常どおり使えます。

## 特徴

- **対象キーボードだけをリマップ**: InterceptionのHWIDで登録済みUSキーボードのみ補正。JISキーボードや内蔵キーボードは素通し
- **本体JISキーボードと共用**: Windowsのキーボード設定は日本語106/109のまま運用し、外付けUSキーボードだけを補正
- **IMEフレンドリー**: ドライバレベルのスキャンコード置換のみを使うため、日本語IMEの未確定(変換前)状態が維持される。unicode出力(VK_PACKET)は不使用
- **自動運用**: ログオン時・キーボード接続(PnP)時にタスクスケジューラから自動起動(US登録が1台でもあればKanataを起動)。常駐の起動はミューテックスで直列化し二重起動を防止
- **手動登録**: 新規キーボードの登録はランチャーから手動実行(接続時に自動でウィザードは開かない。理由は [docs/OPERATION.md](docs/OPERATION.md) の設計メモ参照)
- **オフライン導入**: パッチ済みkanataバイナリとInterceptionランタイムを`bin\`に同梱
- **個人設定はローカル保存**: 登録済みキーボードのHWIDは `%LOCALAPPDATA%\KanataLayoutManager\keyboard-layout-state.json` に保存し、リポジトリには含めない

## 基本の使い方

普段使うWindowsユーザーで実行します。通常の入口は `launchers\` の `.cmd` です。`.ps1` を直接ダブルクリックする必要はありません。

1. 初回導入: `launchers\Bootstrap-Install.cmd`
2. Windows再起動: Interceptionドライバを導入した場合のみ
3. USキーボード登録: `%LOCALAPPDATA%\KanataLayoutManager\launchers\Reconfigure-Keyboard.cmd`
4. 状態確認: `%LOCALAPPDATA%\KanataLayoutManager\launchers\Show-Profiles.cmd`
5. 以後の常駐起動: ログオン時/PnPイベント時にタスクスケジューラが自動実行

PowerShellから明示実行したい場合は、同じ処理を以下でも実行できます。

```powershell
.\launchers\Bootstrap-Install.cmd
& "$env:LOCALAPPDATA\KanataLayoutManager\launchers\Reconfigure-Keyboard.cmd"
```

詳細な運用方法は [docs/OPERATION.md](docs/OPERATION.md) を、検証手順は [docs/IME検証手順.md](docs/IME検証手順.md) を参照してください。デジタル署名エラーやダブルクリック起動については [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) を参照してください。

## ファイル構成

- `Bootstrap-KanataWintercept.ps1`: 初回導入。Kanata/Interceptionランタイムを準備し、必要ならドライバ導入を起動
- `Install-KanataLayoutManager.ps1`: `%LOCALAPPDATA%\KanataLayoutManager` へ管理ツールを配置し、ログオン/PnPタスクを登録
- `Uninstall-KanataLayoutManager.ps1`: タスクとインストール先を削除
- `src\`: インストール先へコピーされる管理スクリプト本体
- `config\`: Kanataのリマップ設定
- `launchers\`: ダブルクリック用 `.cmd`
- `docs\`: 実運用手順、検証手順、トラブルシュート、Kanataパッチ説明
- `bin\`: 同梱バイナリ

## 同梱バイナリについて

`bin\kanata_wintercept_cmd_allowed_patched.exe` は kanata v1.11.0 に**2行のパッチ**を当てたビルドです。
同梱版の元になっているv1.11.0では出力変換表にJIS固有キー(`ろ` SC 0x73 / `¥` SC 0x7D)が無く、`_` `\` `|` の入力時に
**Escが代送されてIMEの未確定文字列が全消しされる**問題があります。パッチ内容と再ビルド手順は
[docs/KANATA-PATCH.md](docs/KANATA-PATCH.md) を参照してください。

Kanata upstream の最新版が同梱版より新しい場合があります。バイナリを差し替える場合は、JIS固有キーの出力変換が upstream 側で対応済みかを確認してください。

## 制約・既知事項

- kanataのHWIDはキー入力時に取得した数値列が正。同一型番のキーボード2台は区別できません
- `windows-interception-keyboard-hwids` はライブリロードされないため、設定変更時はkanataを再起動します
- 初回導入時は予備キーボードまたは緊急停止(`lctl+spc+esc`)を確認してください
- AutoHotInterception等、他のInterception利用ツールとの併用は不可

## クレジット / ライセンス

- [kanata](https://github.com/jtroo/kanata) by jtroo - LGPL-3.0-only。同梱バイナリはv1.11.0+パッチ([docs/KANATA-PATCH.md](docs/KANATA-PATCH.md)に差分と再ビルド手順)のビルドです
- [Interception](https://github.com/oblitum/Interception) by Francisco Lopes - 非商用用途ではLGPLベース。ランタイムDLLとインストーラを同梱しています
- サードパーティのライセンス本文と表記は [docs/licenses](docs/licenses) に同梱しています
