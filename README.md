# AllowRemoteShutdown

## 概要

**AllowRemoteShutdown**  は、PowerShell標準の HttpListener と Microsoft Sysinternals 製の psshutdown.exe を組み合わせた、軽量かつ透明性の高いリモート電源管理サーバーです。本プロジェクトの最大のコンセプトは「透明性」です。外部のブラックボックスな実行ファイルに依存せず、すべてのロジックを検証可能なPowerShellスクリプトで記述しています。中・上級ユーザーがコードの内容を精査し、自身の環境に合わせて自由にカスタマイズして導入できるよう設計されています。

### 主な特徴

* **多言語対応** : 日本語（JP）と英語（EN）をサポート。OSの言語設定に応じた自動切り替え（auto）に加え、手動での固定も可能です。  
* **多彩な電源モード** : 単なるシャットダウンだけでなく、再起動（Restart）、ログオフ（Log off）、休止状態（Hibernate）に対応しています。  
* **タスクトレイ常駐** : Unicodeシンボル「⏼」（U+23FC）を用いた電源アイコンがタスクトレイに表示され、動作状況を一目で確認できます。  
* **クイック・フィードバックとキャンセル機能** :  
* アクション実行時にバルーン通知（通知センター）を表示。  
* **実行キャンセル** : 通知をクリックすることで、即座に中止コマンド（psshutdown \-a）を実行し、アクションを撤回できます。  
* **高度な安全性** :  
* アクセストークン（Token）による簡易認証。  
* 多重起動を防止するミューテックス（Mutex）管理。  
* Windows標準の URL ACL による非特権ユーザーの権限管理。  
* **カスタマイズ性** : ポート、トークン、待機時間、ログ保存先などをスクリプト内の設定セクションから容易に変更可能です。

### 動作要件

* **OS** : Windows 10 / 11  
* **実行環境** : PowerShell 5.1（Windows標準。PowerShell Core 7系では動作が異なる場合があります）  
* **外部ツール** : psshutdown.exe（Microsoftの高機能なシャットダウンユーティリティーです。PsToolsを解凍し任意の場所に配置してください）
https://learn.microsoft.com/ja-jp/sysinternals/downloads/psshutdown
* 本スクリプトの冒頭に設定欄がありますのでpsshutdown.exeのパスなどを記載してください。

## セットアップ手順

管理者権限のPowerShellを開き、以下の手順を実行して通信環境を整えてください。

### 手順1：URL ACLの登録

非特権ユーザーによるHTTP待機を許可するため、以下のコマンドを実行します。  
netsh http add urlacl url=http://+:8080/ user=Everyone

### 手順2：ファイアウォールの解放

外部端末からのアクセスを許可するための受信規則（TCP 8080ポート）を追加します。  
New-NetFirewallRule \-DisplayName "Allow Remote Shutdown" \-Direction Inbound \-LocalPort 8080 \-Protocol TCP \-Action Allow

### 手順3：バックグラウンド起動ショートカットの作成

ウィンドウを表示せずに起動するためのショートカットを作成します。ショートカットの「リンク先」に以下の形式で記述してください。  
powershell.exe \-WindowStyle Hidden \-ExecutionPolicy Bypass \-File "C:\（PSShutdownのパス）\AllowRemoteShutdown.ps1"

※ ExecutionPolicy Bypass を付与することで、環境の実行ポリシー設定に関わらず動作させることができます。

## 使用方法

* **サーバーの起動** : ショートカットを管理者権限で実行するとタスクトレイに「⏼」アイコンが表示されます。  
* **トレイメニュー操作** : アイコンを右クリックすることで、クイック実行時の「モード（シャットダウン/再起動等）」や「遅延時間（15/30/60秒）」を変更したり、ログの表示を切り替えたりできます。  
* **クライアントからのアクセス** : スマホ等のブラウザから以下のURLにアクセスします。  
* http://PCのIPアドレス:8080/  
* **トークン設定時** : 初回アクセスには ?token=xxx の付与が必要です。一度認証されると、以降は画面内のボタン操作で完結します。  
* **実行のキャンセル** : 実行後にPC側に表示されるバルーン通知をクリックすると、設定された AbortCmd が走り、シャットダウンが中止されます。

### カスタマイズ (Configuration)

スクリプト冒頭の $config セクションで動作を定義します。
| 設定項目 | 説明 | 既定値 / 例 |
| :--- | :--- | :--- |
| **Port** | 待ち受けポート番号。 | `8080` |
| **Token** | アクセス認証用トークン。空文字以外を設定すると、URL末尾に `?token=xxx` が必要になります。 | `""` |
| **Language** | UI表示言語。`"auto"`（OS依存）, `"ja"`, `"en"` から選択可能です。 | `"auto"` |
| **ShutdownCmd** | `psshutdown.exe` 実行ファイルのフルパスを指定します。 | `C:\（PSShutdownのパス）\psshutdown.exe` |
| **AbortCmd** | シャットダウン中止時に使用する実行ファイルのパスです。 | `$psShutdownPath` |
| **AbortArgs** | 中止実行時のコマンドライン引数です。 | `"-a"` |
| **LogFile** | 実行ログの保存先パスです。 | `.\AllowRemoteShutdown.log` |
| **IconIndex** | `shell32.dll` 内から使用するアイコンのインデックス番号です。 | `27` |
| **UseCustomIcon** | 独自の `.ico` ファイルを使用するかどうかのフラグです。 | `$false` |
| **IconPath** | `UseCustomIcon` が `$true` の場合に使用するアイコンファイルのパスです。 | `""` |

### トラブルシューティング

* **日本語の文字化け** : PowerShell 5.1は、BOMのないUTF-8ファイルを正しく解読できません。スクリプトを編集して保存する際は、必ず  **「BOM付き UTF-8」**  エンコーディングを選択してください。  
* **接続拒否 (Connection Refused)** :  
* Windowsのネットワークプロファイルが  **「プライベート」**  になっているか確認してください。「パブリック」ではOSレベルで外部アクセスが遮断されます。  
* netsh http show urlacl を実行し、対象のポートが正しく予約されているか確認してください。  
* **二重起動・ゾンビプロセスの発生** :  
* 既に同じポートが使用されている場合、起動に失敗します。タスクマネージャーで powershell.exe のプロセスを確認し、古いプロセスが残っている場合は終了させてください。  
* **監査** : 動作の詳細は AllowRemoteShutdown.log に記録されます。通信の成否や認証エラーの履歴はこちらを確認してください。

## ライセンス・免責事項
### ライセンス / License
本プロジェクトは **MITライセンス** の下で公開されています。商用・個人用問わず自由にご利用いただけますが、本ソフトウェアの使用に関連して生じた損害について、作者は一切の責任を負いません。
### 免責事項 / Disclaimer
- 本ツールの利用は自己責任で行ってください。
- `psshutdown.exe` の著作権およびライセンスは Microsoft Corporation (Sysinternals) に帰属します。ツール自体のライセンス条項に従って利用してください。

### 作者 / Author
- 作成者: [norandot]
- プロジェクトURL: [https://github.com/norandot/AllowRemoteShutdown/]
