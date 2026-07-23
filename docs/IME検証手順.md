# IME「確定」問題の検証手順

前提: `%LOCALAPPDATA%\KanataLayoutManager` に導入済みで、`Test-Installation.cmd` の自己診断が成功していること。

## 背景

前構成では、リマップ後の文字がIMEの未確定(変換前)状態に入らず確定されてしまった。
原因調査の結果、Kanataが確定文字を直接挿入するのは `unicode` 出力(SendInput+KEYEVENTF_UNICODE/VK_PACKET)を使った場合のみ。
現在の `kanata-us-to-jis-wintercept.kbd` は全てスキャンコード置換(defoverrides)で、
wintercept版はInterceptionドライバ経由の実キーストロークを送出するため、
IMEからは本物のJISキーボードと区別がつかない → 解消する見込み。

## 手順

### 1. USキーボードの登録 (初回のみ)

1. USキーボードを接続する。
2. 登録ランチャーを手動実行する: `%LOCALAPPDATA%\KanataLayoutManager\launchers\Reconfigure-Keyboard.cmd`
   (接続時に自動でウィザードは開かない。理由は OPERATION.md の設計メモ参照)
3. 表示名と `U` (US) を入力し、スキャン表示が出た後にUSキーボードでキーを1つ押す
4. Kanataが自動起動する。確認: `Get-Process kanata*`

登録状態の確認: `%LOCALAPPDATA%\KanataLayoutManager\launchers\Show-Profiles.cmd`

### 2. リマップ自体の確認 (IMEオフ)

メモ帳でUSキーボードの刻印どおりに出ることを確認:

```
` ~ @ ^ & * ( ) _ = + [ { ] } \ | ; : ' "
```

### 3. IME未確定状態の維持確認 (本題)

メモ帳 + MS-IME(ひらがな入力)で:

1. `kana` と打ち「かな」が下線付き(未確定)の状態にする
2. その状態で以下を1つずつ打鍵し、**確定されず未確定文字列に追加される**ことを確認:
   - `@` (Shift+2) / `^` (Shift+6) / `&` (Shift+7) / `*` (Shift+8)
   - `(` (Shift+9) / `)` (Shift+0) / `_` (Shift+-) / `=` / `+` (Shift+=)
   - `[` `{` `]` `}` `\` `|` (Shift+\)
   - `:` (Shift+;) / `'` / `"` (Shift+') / `` ` `` / `~` (Shift+`)
   - 打鍵ごとにEscで未確定部分を消してやり直すと判定しやすい
3. スペースで変換候補を表示した状態でも数キー試す
4. 判定基準: 内蔵JISキーボードで同じ操作をした場合と挙動が一致すること
5. Google日本語入力等、常用する他のIMEでも同様に確認

### 4. 問題が出た場合

- どのキーで・どのIME状態で確定が起きたかをメモ
- デバッグログ採取:
  ```powershell
  # 既存kanataを止めてから
  & "$env:LOCALAPPDATA\KanataLayoutManager\runtime\kanata_wintercept_cmd_allowed.exe" --debug -c "$env:LOCALAPPDATA\KanataLayoutManager\kanata-us-to-jis-wintercept.kbd"
  ```
  `kanata sending ... to driver` の行が実際の送出ストローク

## 緊急停止

- `lctl+spc+esc` (リマップ前の物理キー基準) でKanataを強制終了
- 内蔵JISキーボードはKanataの対象外なので常に使用可能
