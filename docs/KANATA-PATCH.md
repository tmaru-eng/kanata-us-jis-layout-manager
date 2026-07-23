# Kanata パッチ内容と再ビルド手順

## 同梱バイナリ (再ビルド不要)

`bin\` にビルド済み一式を同梱している。`Bootstrap-KanataWintercept.ps1` は
この同梱版を優先して使い、存在する場合はダウンロードを行わない。

- `bin\kanata_wintercept_cmd_allowed_patched.exe` — 下記パッチ適用済み 1.11.0
- `bin\interception.dll` — Interception x64 ランタイム
- `bin\install-interception.exe` — Interception ドライバインストーラ

別マシンへの導入もこのフォルダごと配置すればオフラインで完結する。

`%LOCALAPPDATA%\KanataLayoutManager\runtime\kanata_wintercept_cmd_allowed.exe` には、
以下のパッチを当てたビルドを配置する。

この文書は同梱している kanata v1.11.0 ベースのビルドについて説明する。Kanata upstream の最新版が v1.11.0 より新しい場合でも、同梱バイナリは自動更新されない。差し替える場合は、対象バージョンの `src/oskbd/windows/interception_convert.rs` に `KEY_RO` / `KEY_YEN` 相当の変換が存在するかを確認する。

## パッチ内容 (2行)

対象: `kanata-1.11.0/src/oskbd/windows/interception_convert.rs`
`impl TryFrom<OsCodeWrapper> for Stroke` の match に追加:

```rust
// JIS-specific keys: without these arms the fallback emits Esc,
// which wipes an active IME composition.
OsCode::KEY_RO => (ScanCode::SC_73, KeyState::empty()),
OsCode::KEY_YEN => (ScanCode::SC_7D, KeyState::empty()),
```

## なぜ必要か

- wintercept版は出力キーをスキャンコードに変換して送るが、変換表にJIS固有キー
  `ろ`(SC 0x73)と`¥`(SC 0x7D)のエントリがなく、`_ => Err`に落ちる
- 変換Err時のフォールバックは **Escの代送**
  (`src/oskbd/windows/interception.rs` の `from_oscode`)
- 本設定は `_`→`Shift+ろ`、`\`→`ろ`、`|`→`Shift+¥` とJISキーを出力に使うため、
  この3文字でEscが送られ **IME変換中の未確定文字列が全消し** されていた
- HENKAN/MUHENKAN等は変換表に存在するが、ro/yen が抜けているため、この構成では追加が必要

## 設定側の注意

- `yen` という名前はパーサーで通常のbackslashに解釈されるため、
  ¥キー(SC 0x7D)を出力したい場合は `¥` と書く (`config\kanata-us-to-jis-wintercept.kbd` 参照)

## 再ビルド手順

```powershell
# Rust (GNU版、VSビルドツール不要): https://win.rustup.rs/x86_64 から rustup-init.exe
.\rustup-init.exe -y --default-host x86_64-pc-windows-gnu --profile minimal

git clone https://github.com/jtroo/kanata.git kanata-1.11.0
cd kanata-1.11.0
git checkout v1.11.0
$env:CARGO_TARGET_DIR = "$env:TEMP\kanata-build"   # 同期フォルダ外に出力
& "$env:USERPROFILE\.cargo\bin\cargo.exe" build --release --features cmd,interception_driver
# 生成物: %TEMP%\kanata-build\release\kanata.exe
```

`win_manifest` フィーチャーは外している (build.rsが`./target`直書きするため
CARGO_TARGET_DIR併用時に失敗する。マニフェストはDPI設定等のみで動作に不要)。
