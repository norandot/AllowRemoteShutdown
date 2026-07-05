# AllowRemoteShutdown (リモートシャットダウン管理サーバー)

**AllowRemoteShutdown** は、PowerShell 5.1標準の HTTP サーバー（`HttpListener`）と Microsoft Sysinternals 製の `psshutdown.exe`（または Windows 標準の `shutdown.exe`）を組み合わせた、軽量かつ抜群の透明性を誇るリモート電源管理サーバーおよびそのモダンな Web UI です。

すべてのバックエンドロジックが改ざんや安全性の検証（監査）が容易なオープンコード（PowerShell スクリプト）で記述されており、中・上級ユーザーがセキュアかつクローズドなネットワーク内で安心して利用できるように設計されています。

---

## 🚀 主な特徴 (Key Features)

1. **多言語・ローカライズ対応 (Bilingual UI)**
   * 日本語（JP）および英語（EN）を完全サポート。OSのシステムロケールを判別して自動で切り替えるほか、設定による言語固定も可能です。
2. **多彩な電源操作モード**
   * シャットダウン（Shutdown）、再起動（Restart）、ログオフ（Log off）、スリープ/サスペンド（Suspend）、休止状態（Hibernate）、モニターオフ（Monitor Off）、画面ロック（Lock）など、豊富な操作がトレイメニューおよび Web UI から実行可能。
3. **安全・快適なタスクトレイ常駐**
   * Unicode 記号「⏼」を使用した視認性の高いトレイアイコン（または任意に変更可能）から、状態の監視、ログ表示、各種設定の変更をリアルタイムに操作できます。
4. **不整合対策・誤操作防止機能 (Web Sync Protection)**
   * PC（トレイ）側で設定されている「クイックオフ設定」が変更された場合、Webブラウザ側からの意図しない実行を防ぐため、安全のために不整合を検知して遮断します。上の再読み込み（⟳）ボタンを押して同期を促す安全設計です。
5. **文字化け対策済みのバルーン通知 ＆ クイック中止**
   * Web からシャットダウンが要求されると、PC 画面上にバルーン通知が表示されます。通知をクリックする、または Web UI から「中止」をタップすることで即座に `psshutdown -a` が走り、カウントダウンを撤回できます。日本語の文字化け問題も UTF-8 URLエンコード/デコード処理により完全対策済みです。
6. **3つの美しい標準スキン ＆ 完全なカスタムスキン対応**
   * **Slate** (モダンで目に優しいダークテーマ)
   * **Terminal** (ハッカー/コマンドライン風レトロテーマ)
   * **Minimal** (極太ボーダーとフラットなブルータリストデザイン)
   * 自作の HTML/CSS を適用できる「カスタムスキン」機能も搭載（詳細は [SKIN_CUSTOMIZATION_GUIDE.md](./SKIN_CUSTOMIZATION_GUIDE.md) を参照）。
7. **対話式の初期設定スクリプト (`setup.ps1`)**
   * ポート番号、セキュリティトークンの生成、使用する実行コマンド（Windows標準 or PsShutdown）のパス設定、および「EULA（ライセンス同意）のレジストリ自動登録」を対話形式で一発構築できる初期設定スクリプトを同梱。
8. **学習用最小モデル (`LEARNING_MINIMAL_SERVER.ps1`)**
   * バックグラウンドスレッド、HttpListener、トレイアイコン（NotifyIcon）の連携動作原理のみを凝縮した、学習者向け・改変用のクリーンなスケルトンコードを同梱。

---

## 📦 ファイル構成 (Files Included)

*   `AllowRemoteShutdown.ps1` - 本体スクリプト。バックグラウンドサーバー、タスクトレイ、ロギングなどを制御。
*   `setup.ps1` - ポートやパス、トークン等を対話形式でヒアリングし `config.json` を一括自動生成・環境整備するスクリプト。
*   `config.json` - 設定ファイル（`setup.ps1` または本体設定画面から生成・変更）。
*   `LEARNING_MINIMAL_SERVER.ps1` - 仕組みを学ぶための、解説コメント付き最小構成 PowerShell サーバーコード。
*   `SKIN_CUSTOMIZATION_GUIDE.md` - 独自デザインの HTML/CSS で操作画面をフルカスタムしたい方向けの開発ガイド。

---

## 🛠️ セットアップ・導入手順 (Setup Guide)

### 手順 1: 対話式設定スクリプトの実行
管理者権限で PowerShell を起動し、本フォルダに移動後、以下のスクリプトを実行します。

```powershell
Set-ExecutionPolicy RemoteSigned -Scope Process
.\setup.ps1
```
画面の指示に従って、ポート番号（既定: 3000）、アクセス制限用のトークン、PsShutdown のパス等を入力すると、自動的に `config.json` が生成されます。また、PsShutdown の初回起動時における規約同意（EULA）ダイアログを自動でスキップするレジストリの書き込みも同時に実施できます。

*※PsShutdown の利用規約・ライセンスに配慮し、本スクリプト内での実行ファイルの自動配布・ダウンロードは行いません。必要に応じて Microsoft Sysinternals 公式サイトより手動でダウンロードして指定してください。*

### 手順 2: URL ACL の登録 (非管理者実行のため)
一般ユーザーや非特権プロセスでも指定ポート（例: 3000）で HTTP リスナーを待ち受けできるようにするため、管理者権限のターミナルで一度だけ以下を実行します。

```powershell
netsh http add urlacl url=http://+:3000/ user=Everyone
```

### 手順 3: Windows ファイアウォールの解放
同じ Wi-Fi やローカルネットワーク内のスマートフォンや外部端末からアクセスできるように、受信ポートを許可します。

```powershell
New-NetFirewallRule -DisplayName "AllowRemoteShutdown" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000 -Profile Private
```
*(セキュリティ上、接続可能な送信元 IP 範囲をルーターのLAN内などに制限することを強く推奨します)*

### 手順 4: 常駐起動ショートカットの作成
コンソール画面を表示させず、Windows 起動時にバックグラウンドで自動実行させたい場合は、以下の起動オプションを指定したショートカットを作成して `shell:startup` フォルダに配置します。

*   **リンク先**:
    ```cmd
    powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Path\To\AllowRemoteShutdown.ps1"
    ```
*   **詳細設定**: 「管理者として実行」にチェックを入れます。

---

## 📱 使用方法 (How to Use)

1.  **サーバーを起動する**
    *   作成したショートカットから起動します。タスクトレイに「⏼」アイコンが出現します。
2.  **Webクライアントから操作する**
    *   スマートフォン等のブラウザから、`http://[PCのIPアドレス]:[設定ポート]/` にアクセスします。
    *   トークンが設定されている場合は、初回のみ `http://[PCのIPアドレス]:[設定ポート]/?token=[設定したトークン]` のようにトークン付きのURLでアクセスすることで、ブラウザにクッキー保存され、次回以降はURL入力のみでアクセス可能になります。
3.  **シャットダウンの中止 (Abort)**
    *   シャットダウンまたは再起動処理が開始されカウントダウンが始まった際、PC側にトレイからのバルーン通知が出現します。この通知をクリックするか、Webクライアント画面上の「中止 (Abort)」ボタンをタップすることで、即座にカウントダウンがキャンセルされます。

---

## ⚙️ 各種パラメータの設定 (Configuration)

`config.json` を手動、または Web UI、あるいは `setup.ps1` から変更してカスタマイズできます。

| パラメータ | 説明 | 既定値 / 設定例 |
| :--- | :--- | :--- |
| `port` | Web UI待ち受け用のポート番号。 | `3000` |
| `token` | 不正アクセス防止用トークン（空文字で認証無効化）。 | `"生成されたランダムトークン"` |
| `psshutdownPath` | `psshutdown.exe` の絶対パス。空にすると Windows 標準の `shutdown.exe` を使用する簡易モードで動作。 | `"C:\PSTools\psshutdown.exe"` |
| `mode` | クイックオフ実行で使用するデフォルトコマンド。 | `"-s"` (シャットダウン) / `"-r"` (再起動) 等 |
| `delay` | クイックオフ実行時のデフォルト待機秒数。 | `15` |
| `skin` | Web UIのテーマスタイル。 | `"slate"` / `"terminal"` / `"minimal"` |

---

## ⚠️ トラブルシューティング (Troubleshooting)

*   **ブラウザ操作時、設定が変わっているとエラーが出る**
    *   「PCトレイ側のクイックオフ設定が変更されています...」と表示される場合、誤操作防止機能が作動しています。Web UI 上部の **⟳ (再読み込み)** をクリックし、最新の設定値をフェッチ・同期した状態で再度実行してください。
*   **通知の文字が化ける・スクリプトがエラーになる**
    *   PowerShell 5.1 は、BOM (Byte Order Mark) のない UTF-8 ファイルを正常に解釈できません。テキストエディタでスクリプトを手動編集した場合は、必ず **「UTF-8 (BOM付き)」** エンコードを選択して上書き保存してください。
*   **接続できない (Connection Refused)**
    *   接続するスマートフォンと PC が同じ Wi-Fi ネットワーク（LAN）に属しているか、また Windows のネットワークプロファイルが **「プライベート」** に設定されているか確認してください（パブリックプロファイルではOSのセキュリティ上、通信が遮断されます）。

---

## 📜 ライセンス ＆ 免責事項 (License & Disclaimer)

*   **ライセンス**: 本プロジェクトは **MIT ライセンス** の下で公開されています。商用・個人用を問わず自由に変更・配布可能ですが、使用によって生じた一切の損害やデータ紛失について作者は責任を負いません。
*   `psshutdown.exe` の著作権およびライセンスは、Microsoft Corporation (Sysinternals) に帰属します。

---

## English Quick Summary

**AllowRemoteShutdown** is a transparent, auditable remote shutdown management tool powered by PowerShell 5.1 and Microsoft Sysinternals `psshutdown.exe` (or native `shutdown.exe`).

### Key Highlights:
*   **Robust Web Syncing**: Safety feature checks if the client-side configuration matches the current desktop tray state, preventing unintended operations. If divergent, it prompts you to click **⟳ (Reload)** to synchronize first.
*   **Interactive Setup (`setup.ps1`)**: Prompts for Port, Token, and Command type (native vs psshutdown), handles registry EULA automatic entry, and sets up your `config.json` effortlessly.
*   **3 Visual Themes + Custom Skin Support**: Toggle beautifully styled visual skins (**Slate**, **Terminal**, or **Minimal**), or code your own theme inside [SKIN_CUSTOMIZATION_GUIDE.md](./SKIN_CUSTOMIZATION_GUIDE.md).
*   **No Mojibake**: Complete UTF-8 URL-encoding ensures clear Japanese/English cancellation notifications with instant Click-to-Abort.
*   **Clean Learning Blueprint**: Includes `LEARNING_MINIMAL_SERVER.ps1` highlighting HttpListener & NotifyIcon thread coordination for educational purposes.
