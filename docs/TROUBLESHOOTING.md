# トラブルシュート

## デジタル署名エラー

このリポジトリの PowerShell スクリプトと同梱 exe はコード署名していないため、環境の実行ポリシーが `AllSigned` の場合は次のようなエラーになります。

```text
is not digitally signed. You cannot run this script on the current system.
```

このツールでは、システム全体の実行ポリシーを変更せず、起動するコマンドだけ `-ExecutionPolicy Bypass` を付けて実行します。実運用では `launchers` フォルダの `.cmd` を使ってください。

```powershell
.\launchers\Bootstrap-Install.cmd
```

インターネットからダウンロードした ZIP を展開した場合は Zone.Identifier が残り、別の警告が出ることがあります。その場合は、内容を確認したうえでリポジトリフォルダ内のファイルだけブロック解除します。

```powershell
Get-ChildItem -Recurse | Unblock-File
```

## ダブルクリック起動

`.ps1` を直接ダブルクリックすると、関連付けによってはメモ帳で開く、すぐ閉じる、署名エラーで止まることがあります。通常は次を使います。

- `launchers\Bootstrap-Install.cmd`: 初回導入
- `launchers\Reconfigure-Keyboard.cmd`: キーボード登録・変更
- `launchers\Show-Profiles.cmd`: 登録状態の確認
- `launchers\Test-Installation.cmd`: 自己診断
- `launchers\Uninstall.cmd`: アンインストール

インストール後は再設定・確認・診断・アンインストール用ランチャーが `%LOCALAPPDATA%\KanataLayoutManager\launchers` にもコピーされます。
