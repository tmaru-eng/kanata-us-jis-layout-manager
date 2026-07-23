# 実運用手順

Windowsの入力レイアウトが **日本語キーボード 106/109** であることを前提に、物理ANSI USキーボードだけをJIS相当へ補正します。Windows側の設定をUSへ切り替えず、内蔵JISキーボードや本体側JIS配列と外付けUSキーボードを共用するための構成です。

## 基本方針

- 人が実行する操作は `launchers\` の `.cmd` を使う。
- 常駐Kanataの起動は、インストール後に登録されるタスクスケジューラへ任せる。
- `.ps1` は実装ファイルとして扱い、直接ダブルクリックしない。

## 動作

- ログオン時とPnPデバイスイベント時に管理スクリプトを起動する。
- **US登録が1台でもあればKanataを起動する**（Kanata自身が設定内の数値HWIDで対象を絞るため、対象が未接続でも無害）。
- 登録は数値HWIDベース。未接続時にKanataが動いていても、対象キーボードのHWIDだけを補正する。
- **キーボードの新規登録は手動**で `Reconfigure-Keyboard.cmd` を実行して行う。対象のキーボードでキーを1つ押し、表示名とUS/JISを選ぶ。JISとして登録済みのものも変更できる。
- 登録時の初期表示名にはWindowsのデバイス名を使う。Bluetoothでは同じコンテナの親デバイス名をたどり、広告名・製品名を優先する。必要なら任意の名前へ変更できる。

> **設計メモ（接続時に自動ウィザードを出さない理由）**
> 以前は未登録キーボード接続時に登録コンソールを自動で開いていたが、1回のBluetooth接続が
> 多数のPnPイベントを発火させ、ウィザードが競合起動→常駐Kanata停止＋検出プローブ乱立→
> InterceptionクライアントがKanataは同時2つ以上になり全キー入力が停止する、という不具合が
> あった。このため自動ウィザードは廃止し、登録は手動実行のみとした。常駐Kanataの起動は
> 名前付きミューテックスで直列化し、同時に2つ起動しないことを保証している。

判定状態には、Kanataの数値HWIDとWindowsのHardware ID群を対応付けて保存します。Kanataの補正対象は数値HWIDだけで決まります。

## 初回導入

管理者ではなく、普段使うWindowsユーザーで実行します。

KanataとInterceptionが未導入の場合は、まず `launchers\Bootstrap-Install.cmd` をダブルクリックします。`bin\` にパッチ版Kanataとランタイムを同梱しており、通常はダウンロード不要です。同梱が無い場合のみ公式Releaseから取得しますが、その場合はJIS固有キーのパッチが含まれない可能性があります。パッチの内容は `KANATA-PATCH.md` を参照してください。

Interceptionドライバの導入時だけUAC確認が出ます。導入した場合はWindowsを再起動してください。

すでにInterceptionを導入済みなら、ドライバ導入を省略できます。

```powershell
.\launchers\Bootstrap-Install.cmd -SkipDriverInstall
```

外部キーボードがないリモート環境では、ドライバ・タスク・キーボード設定を変更せず、ダウンロードとKanata起動ファイルだけを確認できます。

```powershell
.\launchers\Bootstrap-Install.cmd -PrepareOnly
```

すでにKanataを導入済みの場合は、以下の管理ツールだけを導入します。

```powershell
.\Install-KanataLayoutManager.ps1 -KanataPath 'C:\Tools\kanata\windows-binaries-x64\kanata_windows_tty_wintercept_cmd_allowed.exe'
```

インストール先は `%LOCALAPPDATA%\KanataLayoutManager` です。タスクスケジューラには次の2件を登録します。

- `Kanata Layout Manager - Logon`
- `Kanata Layout Manager - PnP`

PnPタスクは `Microsoft-Windows-Kernel-PnP/Configuration` のイベントで起動します。環境によってこのログが有効でない、またはBluetooth・KVMなどで十分に発火しない場合があります。その場合でもログオン時判定と手動再設定は使えます。

登録済みキーボードのHWIDは `%LOCALAPPDATA%\KanataLayoutManager\keyboard-layout-state.json` に保存されます。リポジトリ側の `config\kanata-us-to-jis-wintercept.kbd` は公開・配布用の空テンプレートです。再インストール時は、状態ファイルが残っていればテンプレートを更新したうえでHWIDを復元し、既存設定は `.bak-YYYYMMDDHHMMSS` としてバックアップします。

## 手動再設定

導入後は `%LOCALAPPDATA%\KanataLayoutManager\launchers\Reconfigure-Keyboard.cmd` を実行します。

表示名とUS/JISを先に入力してから、スキャン表示が出た後に設定を変更したいキーボードでキーを1つ押します。表示名入力中のキーは判別に使われません。検出キーはEnterでも構いません。登録できると `登録しました: 表示名 (US/JIS)` と表示されます。US/JIS選択は既存の状態を上書きします。US/JIS変更時には管理対象Kanataを停止・設定更新・必要時に再起動します。

複数のキーボードが接続されていても、一覧の曖昧なHID名を選ぶ必要はありません。変更したい実機でキーを押した結果のKanata HWIDを基準に、その機器だけを再設定します。

登録済みの表示名・US/JIS・接続状態は次で確認できます。

`%LOCALAPPDATA%\KanataLayoutManager\launchers\Show-Profiles.cmd`

## キーボードなしの自己診断

導入後は次で、PowerShell構文、設定ファイル、Kanataの`--help`実行、DLL配置、タスク登録を確認できます。実機キー入力は不要です。

`%LOCALAPPDATA%\KanataLayoutManager\launchers\Test-Installation.cmd`

## アンインストール

リポジトリ側またはインストール先の `launchers\Uninstall.cmd` を実行します。

タスク、インストール先、保存済みのUS/JIS判定を削除します。現在すでに起動しているKanataは終了しないので、必要なら自分で終了してください。

## 制約と確認項目

- KanataのHWIDはキー入力時に取得した数値列を正とする。Windows側の名前だけでは判定しない。
- `windows-interception-keyboard-hwids` の変更はライブリロードされないため、設定変更時は再起動する。
- 初回は予備キーボードまたは緊急停止手段を用意する。Interception設定の誤りでは入力不能になる可能性がある。
- 同じキーボードをAutoHotInterception等の別Interception利用ツールで同時に捕捉しない。
- Interceptionドライバの削除は、このツールのアンインストールとは分離する。ほかのInterception利用ツールがある場合、削除すると動作しなくなる。
- `\\`、`|`、`@`などの記号キーは、実際の対象キーボードとRDP先で確認する。
