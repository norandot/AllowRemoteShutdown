[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ConsoleWindow {
    [DllImport("kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$consoleHwnd = [ConsoleWindow]::GetConsoleWindow()
[ConsoleWindow]::ShowWindow($consoleHwnd, 0) | Out-Null

# ============================================================
# 設定（ここだけ編集する）
# ============================================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$config = @{
    Port         = 8080
    Host         = "http://+:{0}/"
    TrayText     = "AllowRemoteShutdown"
    IconIndex    = 27
    Token        = "" #アクセストークンを任意に設定する
    ShowConsole  = $false
    ShutdownCmd  = "C:\PSTools\psshutdown.exe"#PSShutdown.exeのパス
    AbortCmd     = "C:\PSTools\psshutdown.exe"#PSShutdown.exeのパス
    AbortArgs    = "-a"
    LogFile      = "$scriptDir\AllowRemoteShutdown.log"
}

# トレイメニューの選択状態（一時的、再起動でデフォルトに戻る）
$script:mode  = "-s"
$script:delay = "15"
# ============================================================

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp $message"
    Write-Host $line
    Add-Content -Path $config.LogFile -Value $line -Encoding UTF8
}

function New-IconFromShell32 {
    param($index)
    if (-not ([System.Management.Automation.PSTypeName]'Shell32Icon').Type) {
        Add-Type -TypeDefinition @"
        using System;
        using System.Drawing;
        using System.Runtime.InteropServices;
        public class Shell32Icon {
            [DllImport("shell32.dll", CharSet=CharSet.Auto)]
            public static extern IntPtr ExtractIcon(IntPtr hInst, string lpszExeFileName, int nIconIndex);
        }
"@
    }
    $hIcon = [Shell32Icon]::ExtractIcon([IntPtr]::Zero, "shell32.dll", $index)
    return [System.Drawing.Icon]::FromHandle($hIcon)
}

function Update-MenuCheck {
    param($items, $value)
    foreach ($item in $items) {
        $item.Checked = ($item.Tag -eq $value)
    }
}

function Invoke-ShutdownAction {
    param($mode, $delaySeconds, $remoteEndPoint)
    $args = "$mode -f -t $delaySeconds -v 10 -c"
    Write-Log "実行: $mode 遅延 $delaySeconds 秒 [$remoteEndPoint]"

    if ($script:cancelHandler) {
        $icon.remove_BalloonTipClicked($script:cancelHandler)
    }
    $script:cancelHandler = {
        Start-Process $config.AbortCmd -ArgumentList $config.AbortArgs -WindowStyle Hidden
        Write-Log "中止: ユーザー操作により中止"
        $icon.BalloonTipTitle = $config.TrayText
        $icon.BalloonTipText  = "中止しました"
        $icon.ShowBalloonTip(3000)
    }
    $icon.add_BalloonTipClicked($script:cancelHandler)

    $icon.BalloonTipTitle = $config.TrayText
    $icon.BalloonTipText  = "実行しました。クリックで中止。（${delaySeconds}秒）"
    $icon.ShowBalloonTip([int]$delaySeconds * 1000)

    Start-Process $config.ShutdownCmd -ArgumentList $args -WindowStyle Hidden
}

# --- HTMLページ生成 ---
function Get-HtmlPage {
    param($token, $message = "")
    $tokenQuery = if ($token -ne "") { "?token=$token" } else { "" }
    $msgHtml = if ($message -ne "") { "<p class='msg'>$message</p>" } else { "" }

    @"
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$($config.TrayText)</title>
<style>
  body { font-family: sans-serif; background:#1e1e1e; color:#eee; text-align:center; padding:20px; }
  h1 { font-size:1.2em; margin-bottom:20px; }
  .msg { color:#7fd; margin-bottom:16px; }
  form { margin-bottom:14px; }
  button {
    width:90%; max-width:320px; padding:14px; font-size:1.1em;
    margin:6px 0; border:none; border-radius:8px; cursor:pointer;
  }
  .quick     { background:#2d7; color:#000; }
  .shutdown  { background:#d44; color:#fff; }
  .restart   { background:#48a; color:#fff; }
  .logoff    { background:#888; color:#fff; }
  .sleep     { background:#a6a; color:#fff; }
  .abort     { background:#444; color:#fff; border:1px solid #777; }
  select, input[type=number] { padding:8px; font-size:1em; margin:4px; border-radius:6px; border:none; }
  .row { margin-bottom:10px; }
</style>
</head>
<body>
<h1>$($config.TrayText)</h1>
$msgHtml

<form method="GET" action="/quick$tokenQuery">
  <button class="quick" type="submit">クイックオフ（現在: $script:mode / ${script:delay}秒）</button>
</form>

<div class="row">
  <form method="GET" action="/exec" style="display:inline;">
    <input type="hidden" name="token" value="$token">
    <select name="mode">
      <option value="-s">シャットダウン</option>
      <option value="-r">再起動</option>
      <option value="-o">ログオフ</option>
      <option value="-h">休止</option>
    </select>
    <select name="delay">
      <option value="15">15秒</option>
      <option value="30">30秒</option>
      <option value="60">60秒</option>
      <option value="custom">任意秒数</option>
    </select>
    <input type="number" name="customDelay" placeholder="秒数" min="0" style="width:70px; display:none;" id="customDelay">
    <br>
    <button class="shutdown" type="submit">実行</button>
  </form>
</div>

<form method="GET" action="/abort$tokenQuery">
  <button class="abort" type="submit">シャットダウン中止</button>
</form>

<script>
document.querySelector('select[name=delay]').addEventListener('change', function(){
  document.getElementById('customDelay').style.display = (this.value === 'custom') ? 'inline-block' : 'none';
});
document.querySelector('form[action="/exec"]').addEventListener('submit', function(e){
  var delaySel = this.delay.value;
  if (delaySel === 'custom') {
    this.delay.value = this.customDelay.value || '15';
  }
});
</script>
</body>
</html>
"@
}

# --- HTTPリスナー起動 ---
$prefix = $config.Host -f $config.Port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Log "サーバー起動中 → $prefix (終了はトレイアイコンから)"

# --- タスクトレイアイコン ---
$trayIcon = New-IconFromShell32 $config.IconIndex

$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon    = $trayIcon
$icon.Visible = $true
$icon.Text    = $config.TrayText

# --- メニュー構築 ---
$menu = New-Object System.Windows.Forms.ContextMenu

$menuMode = New-Object System.Windows.Forms.MenuItem("クイックオフのモード")
$modeItems = @()
@(
    @{ Label = "シャットダウン"; Value = "-s" }
    @{ Label = "再起動";         Value = "-r" }
    @{ Label = "ログオフ";       Value = "-o" }
    @{ Label = "休止";           Value = "-h" }
) | ForEach-Object {
    $item = New-Object System.Windows.Forms.MenuItem($_.Label)
    $item.Tag     = $_.Value
    $item.Checked = ($_.Value -eq $script:mode)
    $itemValue    = $_.Value
    $item.Add_Click({
        $script:mode = $itemValue
        Update-MenuCheck $modeItems $script:mode
        Write-Log "クイックオフのモード変更: $script:mode"
    })
    $modeItems += $item
    $menuMode.MenuItems.Add($item) | Out-Null
}
$menu.MenuItems.Add($menuMode) | Out-Null

$menuDelay = New-Object System.Windows.Forms.MenuItem("クイックオフの遅延")
$delayItems = @()
@(
    @{ Label = "15秒"; Value = "15" }
    @{ Label = "30秒"; Value = "30" }
    @{ Label = "60秒"; Value = "60" }
) | ForEach-Object {
    $item = New-Object System.Windows.Forms.MenuItem($_.Label)
    $item.Tag     = $_.Value
    $item.Checked = ($_.Value -eq $script:delay)
    $itemValue    = $_.Value
    $item.Add_Click({
        $script:delay = $itemValue
        Update-MenuCheck $delayItems $script:delay
        Write-Log "クイックオフの遅延変更: $script:delay 秒"
    })
    $delayItems += $item
    $menuDelay.MenuItems.Add($item) | Out-Null
}
$menu.MenuItems.Add($menuDelay) | Out-Null

$menu.MenuItems.Add("-") | Out-Null

$menu.MenuItems.Add("ログを表示／非表示", {
    if ($config.ShowConsole) {
        [ConsoleWindow]::ShowWindow($consoleHwnd, 0) | Out-Null
        $config.ShowConsole = $false
    } else {
        [ConsoleWindow]::ShowWindow($consoleHwnd, 5) | Out-Null
        $config.ShowConsole = $true
    }
}) | Out-Null

$menu.MenuItems.Add("終了", {
    $timer.Stop()
    $listener.Stop()
    $icon.Visible = $false
    $trayIcon.Dispose()
    [ConsoleWindow]::ShowWindow($consoleHwnd, 0) | Out-Null
    [System.Windows.Forms.Application]::Exit()
}) | Out-Null

$icon.ContextMenu = $menu

# --- タイマーポーリング ---
$script:cancelHandler = $null
$script:contextTask = $listener.GetContextAsync()

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 100

$timer.Add_Tick({
    if (-not $listener.IsListening) { $timer.Stop(); return }

    if ($script:contextTask.IsCompleted) {
        try {
            $context = $script:contextTask.Result
            $req     = $context.Request
            $res     = $context.Response
            $path    = $req.Url.AbsolutePath

            $authorized = ($config.Token -eq "") -or
                          ($req.QueryString["token"] -eq $config.Token)

            if (-not $authorized) {
                $res.StatusCode = 403
                $body = [System.Text.Encoding]::UTF8.GetBytes("Forbidden.")
                $res.OutputStream.Write($body, 0, $body.Length)
                $res.Close()
                Write-Log "認証失敗 [$($req.RemoteEndPoint)]"
            }
            else {
                switch ($path) {
                    "/" {
                        $html = Get-HtmlPage $config.Token
                        $body = [System.Text.Encoding]::UTF8.GetBytes($html)
                        $res.ContentType = "text/html; charset=utf-8"
                        $res.OutputStream.Write($body, 0, $body.Length)
                        $res.Close()
                    }
                    "/quick" {
                        Invoke-ShutdownAction $script:mode $script:delay $req.RemoteEndPoint
                        $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)" } else { "/" }
                        $res.Redirect($redirectUrl)
                        $res.Close()
                    }
                    "/exec" {
                        $m = $req.QueryString["mode"]
                        $d = $req.QueryString["delay"]
                        if ($m -notin @("-s","-r","-o","-h")) { $m = "-s" }
                        if (-not ($d -match '^\d+$')) { $d = "15" }
                        Invoke-ShutdownAction $m $d $req.RemoteEndPoint
                        $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)" } else { "/" }
                        $res.Redirect($redirectUrl)
                        $res.Close()
                    }
                    "/abort" {
                        Start-Process $config.AbortCmd -ArgumentList $config.AbortArgs -WindowStyle Hidden
                        Write-Log "中止: Web操作により中止 [$($req.RemoteEndPoint)]"
                        if ($script:cancelHandler) {
                            $icon.remove_BalloonTipClicked($script:cancelHandler)
                            $script:cancelHandler = $null
                        }
                        $icon.BalloonTipTitle = $config.TrayText
                        $icon.BalloonTipText  = "中止しました"
                        $icon.ShowBalloonTip(3000)
                        $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)&msg=中止しました" } else { "/?msg=中止しました" }
                        $res.Redirect($redirectUrl)
                        $res.Close()
                    }
                    default {
                        $res.StatusCode = 404
                        $body = [System.Text.Encoding]::UTF8.GetBytes("Not Found.")
                        $res.OutputStream.Write($body, 0, $body.Length)
                        $res.Close()
                    }
                }
            }
        } catch {
            Write-Log "リクエスト処理エラー: $_"
        }

        $script:contextTask = $listener.GetContextAsync()
    }
})
$timer.Start()

# --- UIメッセージループ ---
[System.Windows.Forms.Application]::Run()

# --- クリーンアップ ---
$timer.Stop()
$timer.Dispose()
if ($listener.IsListening) { $listener.Stop() }
$icon.Visible = $false
$trayIcon.Dispose()
Write-Log "サーバーを停止しました"
