# Skin Customization Guide (スキンカスタマイズガイド)

AllowRemoteShutdown では、Web UI（スマホやブラウザ用操作画面）のデザインを自由に変更することができます。
本ガイドでは、組み込みスキンの概要と、外部HTMLファイルを使用した**完全なカスタムスキンの作成手順**について解説します。

---

## 1. 組み込みスキン (Built-in Skins)
アプリケーションにはデフォルトで3つのデザインテンプレートが内蔵されています。設定画面（Web UIまたはトレイ）から `skin` を切り替えるだけで適用されます。

*   **slate (デフォルト)**: ダークトーン（チャコールグレー）を基調とした、目に優しく洗練されたモダンなデザイン。
*   **terminal (ターミナル)**: 黒背景にグリーンの等幅フォント、ボーダーを多用したレトロなハッカー・コマンドライン風スタイル。
*   **minimal (ミニマル)**: 白背景に極太の漆黒ボーダー、フラットでスタイリッシュなブ brutalist デザイン。

---

## 2. カスタムスキンの作成方法
`customSkinPath`（カスタムスキンファイルのパス）に独自のHTMLファイルのフルパスを指定することで、Web UIのすべてのHTMLとCSSを完全に入れ替えることができます。

### ① 仕組み
PowerShellサーバーはリクエストを受信すると、指定されたHTMLファイルをUTF-8形式で読み込み、あらかじめ定義されたプレースホルダー（変数）を最新の状態値に置換してブラウザに送信します。

### ② 置換プレースホルダー一覧
カスタムHTML内に以下の文字列を記述しておくと、サーバーによって動的に値が埋め込まれます。

| プレースホルダー | 置換後の内容 | 用途 |
| :--- | :--- | :--- |
| `$token` | 設定されているセキュリティトークン（例: `abc12`） | フォームやリンクの認証用 |
| `$tokenQuery` | `?token=トークン` または 空文字列 | 遷移先URLのクエリ文字列にそのまま付与可能 |
| `$msgHtml` | `<p class='msg'>メッセージ内容</p>` または 空文字列 | 「中止しました」等の実行結果の表示領域 |
| `$langAttr` | `ja` または `en` | `<html lang="$langAttr">` 用 |
| `$trayText` | 設定されたツール名・タイトル（例: `AllowRemoteShutdown`） | タイトルや大見出し用 |
| `$quickHeading` | ローカライズされた「ワンタップ実行」の文言 | 見出し |
| `$quickCurrentSetting` | 現在のクイックオフ設定情報（例: `シャットダウン / 15秒`） | 状態説明 |
| `$quickLabel` | ローカライズされた「今すぐ実行」の文言 | ボタン文字 |
| `$chooseHeading` | ローカライズされた「モードを選んで実行」の文言 | 見出し |
| `$execLabel` | ローカライズされた「このモードで実行」の文言 | 実行ボタン文字 |
| `$abortLabel` | ローカライズされた「シャットダウン中止」の文言 | 中止ボタン文字 |
| `$currentModeCss` | 現在の設定に応じたCSSクラス名 (`shutdown`, `restart` など) | 動的なボタンスタイリング用 |

---

## 3. カスタムスキン HTML テンプレート
以下は、独自のサイバーパンク/ネオン風テーマを構築するための完全なカスタムスキンHTMLのサンプルです。これを `my_custom_skin.html` などの名前で保存し、アプリ設定の `customSkinPath` にその絶対パスを指定してください。

```html
<!DOCTYPE html>
<html lang="$langAttr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$($trayText)</title>
<style>
  /* 全体の近未来サイバーパンクデザイン */
  body {
    background: #0d0e15;
    color: #00f0ff;
    font-family: 'Segoe UI', system-ui, sans-serif;
    text-align: center;
    padding: 30px 15px;
    margin: 0;
  }
  h1 {
    font-size: 1.8em;
    color: #ff007f;
    text-shadow: 0 0 10px #ff007f, 0 0 20px #ff007f;
    margin-bottom: 30px;
    letter-spacing: 2px;
  }
  h2 {
    font-size: 1em;
    color: #00f0ff;
    text-transform: uppercase;
    letter-spacing: 1.5px;
    margin-top: 30px;
    border-left: 3px solid #ff007f;
    padding-left: 8px;
    display: inline-block;
  }
  /* メッセージ領域 (警告・中止通知など) */
  .msg {
    background: rgba(255, 0, 127, 0.1);
    color: #ff007f;
    border: 1px solid #ff007f;
    border-radius: 4px;
    padding: 12px;
    font-weight: bold;
    max-width: 340px;
    margin: 0 auto 20px;
    box-shadow: 0 0 8px rgba(255, 0, 127, 0.3);
  }
  .current-setting {
    color: #e0e0e0;
    font-size: 0.9em;
    margin-bottom: 15px;
  }
  /* ネオンボタンの共通スタイル */
  button {
    width: 90%;
    max-width: 340px;
    padding: 14px;
    font-size: 1em;
    font-weight: bold;
    margin: 10px 0;
    border: 2px solid #00f0ff;
    background: transparent;
    color: #00f0ff;
    border-radius: 8px;
    cursor: pointer;
    box-shadow: 0 0 10px rgba(0, 240, 255, 0.2);
    transition: all 0.2s ease;
  }
  button:hover {
    background: #00f0ff;
    color: #0d0e15;
    box-shadow: 0 0 15px #00f0ff;
  }
  /* モード別のテーマ色 */
  .shutdown { border-color: #ff0055; color: #ff0055; box-shadow: 0 0 10px rgba(255, 0, 85, 0.2); }
  .shutdown:hover { background: #ff0055; color: #fff; box-shadow: 0 0 15px #ff0055; }
  .restart { border-color: #00ff66; color: #00ff66; box-shadow: 0 0 10px rgba(0, 255, 102, 0.2); }
  .restart:hover { background: #00ff66; color: #0d0e15; box-shadow: 0 0 15px #00ff66; }
  
  /* 中止ボタンの特別スタイル */
  .abort {
    background: #ff007f;
    border-color: #ff007f;
    color: #fff;
    box-shadow: 0 0 12px rgba(255, 0, 127, 0.4);
  }
  .abort:hover {
    background: transparent;
    color: #ff007f;
    box-shadow: 0 0 20px #ff007f;
  }
  select, input[type=number] {
    padding: 10px;
    font-size: 0.95em;
    margin: 6px;
    border: 1px solid #00f0ff;
    background: #121324;
    color: #fff;
    border-radius: 6px;
    box-shadow: inset 0 0 5px rgba(0, 240, 255, 0.2);
  }
  .row { margin-bottom: 15px; }
</style>
</head>
<body>

<h1>$($trayText)</h1>

$msgHtml

<h2>$quickHeading</h2>
<p class="current-setting">$quickCurrentSetting</p>
<form method="GET" action="/quick$tokenQuery">
  <button class="$currentModeCss" type="submit">$quickLabel</button>
</form>

<h2>$chooseHeading</h2>
<div class="row">
  <form method="GET" action="/exec" style="display:inline;">
    <input type="hidden" name="token" value="$token">
    <select name="mode" id="modeSelect">
      <option value="-s">シャットダウン</option>
      <option value="-r">再起動</option>
      <option value="-d">サスペンド</option>
      <option value="-h">休止</option>
      <option value="-o">ログオフ</option>
      <option value="-l">ロック</option>
      <option value="-x">モニターオフ</option>
    </select>
    <select name="delay" id="delaySelect">
      <option value="15">15秒</option>
      <option value="30">30秒</option>
      <option value="60">60秒</option>
      <option value="custom">指定秒数</option>
    </select>
    <input type="number" name="customDelay" placeholder="秒数" min="0" style="width:70px; display:none;" id="customDelay">
    <br>
    <button class="shutdown" type="submit" id="execButton">$execLabel</button>
  </form>
</div>

<form method="GET" action="/abort$tokenQuery">
  <button class="abort" type="submit">$abortLabel</button>
</form>

<script>
var delaySelect = document.getElementById('delaySelect');
var customInput = document.getElementById('customDelay');
var modeSelect = document.getElementById('modeSelect');
var execButton = document.getElementById('execButton');

var modeCssMap = {
  '-s': 'shutdown', '-r': 'restart', '-d': 'suspend',
  '-h': 'hibernate', '-o': 'logoff', '-l': 'lock', '-x': 'monitoroff'
};

function updateExecButtonClass() {
  execButton.className = modeCssMap[modeSelect.value] || 'shutdown';
  
  var isImmediate = (modeSelect.value === '-l' || modeSelect.value === '-x' || modeSelect.value === '-o');
  if (isImmediate) {
    delaySelect.style.display = 'none';
    customInput.style.display = 'none';
  } else {
    delaySelect.style.display = 'inline-block';
    customInput.style.display = (delaySelect.value === 'custom') ? 'inline-block' : 'none';
  }
}

modeSelect.addEventListener('change', updateExecButtonClass);
updateExecButtonClass();

delaySelect.addEventListener('change', function(){
  customInput.style.display = (this.value === 'custom') ? 'inline-block' : 'none';
});

document.querySelector('form[action="/exec"]').addEventListener('submit', function(e){
  var isImmediate = (modeSelect.value === '-l' || modeSelect.value === '-x' || modeSelect.value === '-o');
  if (isImmediate) {
    var hidden = document.createElement('input');
    hidden.type  = 'hidden';
    hidden.name  = 'delay';
    hidden.value = '0';
    delaySelect.disabled = true;
    this.appendChild(hidden);
  } else if (delaySelect.value === 'custom') {
    var val = parseInt(customInput.value, 10);
    if (isNaN(val) || val < 1) { val = 15; }
    var hidden = document.createElement('input');
    hidden.type  = 'hidden';
    hidden.name  = 'delay';
    hidden.value = val;
    delaySelect.disabled = true;
    this.appendChild(hidden);
  }
});
</script>
</body>
</html>
```

---

## 4. トラブルシューティング
*   **デザインが崩れる・真っ白になる**: `customSkinPath` のファイルが存在し、読み取り権限があるか確認してください。ファイル名やパスに日本語スペースなど特殊文字がある場合、ダブルクォーテーションでパスを囲んで指定してください。
*   **ボタンが動かない**: HTML内のフォーム遷移先 (`/quick`, `/exec`, `/abort`) や JavaScript が正しく定義されているか、サンプルのスクリプト構成と照らし合わせてみてください。
