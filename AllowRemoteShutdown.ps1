[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web

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
# Configuration - edit this section only
# ============================================================
# 日本語: 以下の $config を編集してください。Language は "ja" / "en" / "auto" を指定できます。
# English: Edit $config below. Language may be "ja" / "en" / "auto".
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

# PSShutdown.exe の共通パス（必要に応じて編集してください）
# Shared path to PSShutdown.exe (edit if needed)
$psShutdownPath = "C:\PSTools\psshutdown.exe"

$config = @{
    Port         = 8080
    Host         = "http://+:{0}/"
    # トレイに表示するテキスト。デフォルトは多言語化された文字列に置き換えられます。
    # Tray text shown in the system tray. Default will be replaced by i18n strings.
    TrayText     = "AllowRemoteShutdown"
    # shell32.dll のアイコンインデックス (既定 27)。カスタムアイコンを使う場合は UseCustomIcon を $true にし、IconPath を指定してください。
    # Icon index in shell32.dll (default 27). To use a custom icon, set UseCustomIcon=$true and specify IconPath.
    IconIndex    = 27
    # カスタムアイコンのパス（.ico ファイルなど）。空文字なら shell32 を使用します。
    # Custom icon path (.ico). If empty, shell32 with IconIndex is used.
    IconPath     = ""
    # カスタムアイコンを有効にするフラグ。デフォルトは $false（shell32 を使用）。
    # Enable custom icon flag. Default $false uses shell32 icon.
    UseCustomIcon = $false
    # 言語設定: "auto"(既定) / "ja" / "en"
    # Language: "auto" (default) / "ja" / "en"
    Language     = "auto"
    # アクセストークンを任意に設定する
    # Optional access token
    Token        = ""
    ShowConsole  = $false
    # PSShutdown.exe のパス（共通変数 $psShutdownPath を使用）
    # Path to PSShutdown.exe (uses shared $psShutdownPath)
    ShutdownCmd  = $psShutdownPath
    # PSShutdown.exe のパス（共通変数 $psShutdownPath を使用）
    # Path to PSShutdown.exe (uses shared $psShutdownPath)
    AbortCmd     = $psShutdownPath
    AbortArgs    = "-a"
    LogFile      = "$scriptDir\AllowRemoteShutdown.log"
}

# トレイメニューの選択状態（一時的、再起動でデフォルトに戻る）
# Tray menu selection state (temporary, reverts to default on restart)
$script:mode  = "-s"
$script:delay = "15"
# ============================================================

# --- ロケール判定と言語選択 ---
# Locale detection and language selection
function Get-EffectiveLanguage {
    param()
    $lang = $config.Language
    if ($lang -eq "auto") {
        try {
            $ci = [System.Globalization.CultureInfo]::InstalledUICulture.Name
            if ($ci -like "ja*") { return "ja" }
        } catch { }
        return "en"
    }
    return $lang
}

# --- 多言語文字列定義 ---
# Multilingual string dictionary
$strings = @{
    ja = @{
        TrayText = "AllowRemoteShutdown"
        MenuMode = "クイックオフのモード"
        Mode_Shutdown = "シャットダウン"
        Mode_Restart  = "再起動"
        Mode_Logoff   = "ログオフ"
        Mode_Hibernate= "休止"
        MenuDelay = "クイックオフの遅延"
        Delay_15 = "15秒"
        Delay_30 = "30秒"
        Delay_60 = "60秒"
        Delay_Custom = "任意秒数"
        MenuShowLog = "ログを表示／非表示"
        MenuExit = "終了"
        QuickButton = "クイックオフ（現在：{0}／{1}秒）"
        ExecuteButton = "実行"
        AbortButton = "シャットダウン中止"
        AbortDoneMsg = "中止しました"
        RunningBalloon = "実行しました。クリックで中止。（{0}秒）"
        AbortedBalloon = "中止しました"
        Log_ServerStarted = "サーバー起動中 → {0} (終了はトレイアイコンから)"
        Log_RequestAuthFailed = "認証失敗 [{0}]"
        Log_RequestError = "リクエスト処理エラー: {0}"
        Log_Invoke = "実行: {0} 遅延 {1} 秒 [{2}]"
        Log_AbortByWeb = "中止: Web操作により中止 [{0}]"
        Log_AbortByUser = "中止: ユーザー操作により中止"
        Log_ModeChanged = "クイックオフのモード変更: {0}"
        Log_DelayChanged = "クイックオフの遅延変更: {0} 秒"
        Log_Cleanup = "サーバーを停止しました"
        CustomDelayPlaceholder = "秒数"
    }
    en = @{
        TrayText = "AllowRemoteShutdown"
        MenuMode = "Quick-off Mode"
        Mode_Shutdown = "Shutdown"
        Mode_Restart  = "Restart"
        Mode_Logoff   = "Log off"
        Mode_Hibernate= "Hibernate"
        MenuDelay = "Quick-off Delay"
        Delay_15 = "15s"
        Delay_30 = "30s"
        Delay_60 = "60s"
        Delay_Custom = "Custom seconds"
        MenuShowLog = "Show/Hide Log"
        MenuExit = "Exit"
        QuickButton = "Quick Off (current: {0} / {1}s)"
        ExecuteButton = "Execute"
        AbortButton = "Abort Shutdown"
        AbortDoneMsg = "Aborted"
        RunningBalloon = "Started. Click to abort. ({0}s)"
        AbortedBalloon = "Aborted"
        Log_ServerStarted = "Server started → {0} (stop from tray icon)"
        Log_RequestAuthFailed = "Auth failed [{0}]"
        Log_RequestError = "Request handling error: {0}"
        Log_Invoke = "Invoke: {0} delay {1} sec [{2}]"
        Log_AbortByWeb = "Abort: aborted by web operation [{0}]"
        Log_AbortByUser = "Abort: aborted by user action"
        Log_ModeChanged = "Quick-off mode changed: {0}"
        Log_DelayChanged = "Quick-off delay changed: {0} sec"
        Log_Cleanup = "Server stopped"
        CustomDelayPlaceholder = "seconds"
    }
}

$script:lang = Get-EffectiveLanguage

# --- 翻訳ヘルパー関数 ---
# Translation helper function
function T {
    param([string]$key, [Parameter(ValueFromRemainingArguments=$true)][object[]]$args)
    $loc = $script:lang
    if (-not $strings.ContainsKey($loc)) { $loc = 'en' }
    if (-not $strings[$loc].ContainsKey($key)) { return "<$key>" }
    $fmt = $strings[$loc][$key]
    if ($args -and $args.Length -gt 0) {
        return [string]::Format($fmt, $args)
    }
    return $fmt
}

# --- ログ出力関数（堅牢化） ---
# Logging output function (robust)
function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp $message"
    try {
        Write-Host $line
        Add-Content -Path $config.LogFile -Value $line -Encoding UTF8
    } catch {
        # ログ書き込み失敗は致命的ではないがコンソールに出力する
        # Log write failure is not fatal but output to console
        Write-Host "Log write failed: $_" -ForegroundColor Yellow
    }
}

# --- 安全な外部プロセス起動関数 ---
# Safe external process invocation function
function Safe-StartProcess {
    param([string]$file, [string[]]$args)
    try {
        if ($args) {
            Start-Process $file -ArgumentList $args -WindowStyle Hidden -ErrorAction Stop
        } else {
            Start-Process $file -WindowStyle Hidden -ErrorAction Stop
        }
    } catch {
        Write-Log "Start-Process failed: $file $args -> $_"
        try {
            $icon.BalloonTipTitle = T 'TrayText'
            $icon.BalloonTipText  = "Error: $file"
            $icon.ShowBalloonTip(3000)
        } catch { }
    }
}

# --- shell32 からアイコンを抽出する関数 ---
# Extract icon from shell32.dll function
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

# --- トレイアイコンを読み込む関数 ---
# Load tray icon function
function Load-TrayIcon {
    param($cfg)
    if ($cfg.UseCustomIcon -and $cfg.IconPath -ne "" -and (Test-Path $cfg.IconPath)) {
        try {
            return [System.Drawing.Icon]::ExtractAssociatedIcon($cfg.IconPath)
        } catch {
            Write-Log "Custom icon load failed: $($cfg.IconPath) -> $_"
        }
    }
    return New-IconFromShell32 $cfg.IconIndex
}

# --- メニューのチェック状態を更新する関数 ---
# Update menu check state function
function Update-MenuCheck {
    param($items, $value)
    foreach ($item in $items) {
        $item.Checked = ($item.Tag -eq $value)
    }
}

# --- モードコードからモード名を取得する関数 ---
# Get mode name from mode code function
function Get-ModeLabel {
    param([string]$modeCode)
    switch ($modeCode) {
        "-s" { return (T 'Mode_Shutdown') }
        "-r" { return (T 'Mode_Restart') }
        "-o" { return (T 'Mode_Logoff') }
        "-h" { return (T 'Mode_Hibernate') }
        default { return (T 'Mode_Shutdown') }
    }
}

# --- シャットダウン処理を実行する関数 ---
# Invoke shutdown action function
function Invoke-ShutdownAction {
    param($mode, $delaySeconds, $remoteEndPoint)
    $args = "$mode -f -t $delaySeconds -v 10 -c"
    Write-Log (T 'Log_Invoke' $mode $delaySeconds $remoteEndPoint)

    if ($script:cancelHandler) {
        try { $icon.remove_BalloonTipClicked($script:cancelHandler) } catch { }
    }
    $script:cancelHandler = {
        Safe-StartProcess $config.AbortCmd @($config.AbortArgs)
        Write-Log (T 'Log_AbortByUser')
        try {
            $icon.BalloonTipTitle = T 'TrayText'
            $icon.BalloonTipText  = T 'AbortedBalloon'
            $icon.ShowBalloonTip(3000)
        } catch { }
    }
    $icon.add_BalloonTipClicked($script:cancelHandler)

    try {
        $icon.BalloonTipTitle = T 'TrayText'
        $icon.BalloonTipText  = T 'RunningBalloon' $delaySeconds
        $icon.ShowBalloonTip([int]$delaySeconds * 1000)
    } catch { }

    Safe-StartProcess $config.ShutdownCmd @($args)
}

# --- HTMLページ生成関数 ---
# Generate HTML page function
function Get-HtmlPage {
    param($token, $message = "")
    $tokenQuery = if ($token -ne "") { "?token=$token" } else { "" }
    $msgHtml = if ($message -ne "") { "<p class='msg'>$([System.Web.HttpUtility]::HtmlEncode($message))</p>" } else { "" }
    $langAttr = $script:lang

    # ここスコープ前に全ての T() 呼び出しを評価
    $modeLabel = Get-ModeLabel $script:mode
    $quickLabel = [System.Web.HttpUtility]::HtmlEncode((T 'QuickButton' $modeLabel $script:delay))
    $execLabel = [System.Web.HttpUtility]::HtmlEncode((T 'ExecuteButton'))
    $abortLabel = [System.Web.HttpUtility]::HtmlEncode((T 'AbortButton'))
    $modeOption_Shutdown = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Shutdown'))
    $modeOption_Restart  = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Restart'))
    $modeOption_Logoff   = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Logoff'))
    $modeOption_Hibernate= [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Hibernate'))
    $delayOption_15 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_15'))
    $delayOption_30 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_30'))
    $delayOption_60 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_60'))
    $delayOption_Custom = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_Custom'))
    $delayPlaceholder = [System.Web.HttpUtility]::HtmlEncode((T 'CustomDelayPlaceholder'))

    @"
<!DOCTYPE html>
<html lang="$langAttr">
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
  <button class="quick" type="submit">$quickLabel</button>
</form>

<div class="row">
  <form method="GET" action="/exec" style="display:inline;">
    <input type="hidden" name="token" value="$token">
    <select name="mode">
      <option value="-s">$modeOption_Shutdown</option>
      <option value="-r">$modeOption_Restart</option>
      <option value="-o">$modeOption_Logoff</option>
      <option value="-h">$modeOption_Hibernate</option>
    </select>
    <select name="delay">
      <option value="15">$delayOption_15</option>
      <option value="30">$delayOption_30</option>
      <option value="60">$delayOption_60</option>
      <option value="custom">$delayOption_Custom</option>
    </select>
    <input type="number" name="customDelay" placeholder="$delayPlaceholder" min="0" style="width:70px; display:none;" id="customDelay">
    <br>
    <button class="shutdown" type="submit">$execLabel</button>
  </form>
</div>

<form method="GET" action="/abort$tokenQuery">
  <button class="abort" type="submit">$abortLabel</button>
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

# --- HTTPリスナーを起動 ---
# Start HTTP listener
$prefix = $config.Host -f $config.Port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Log (T 'Log_ServerStarted' $prefix)

# --- タスクトレイアイコンを設定 ---
# Set up task tray icon
$trayIcon = Load-TrayIcon $config

$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon    = $trayIcon
$icon.Visible = $true
$icon.Text    = T 'TrayText'

# --- コンテキストメニューを構築 ---
# Build context menu
$menu = New-Object System.Windows.Forms.ContextMenu

$menuMode = New-Object System.Windows.Forms.MenuItem((T 'MenuMode'))
$modeItems = @()
@(
    @{ Label = T 'Mode_Shutdown'; Value = "-s" }
    @{ Label = T 'Mode_Restart';  Value = "-r" }
    @{ Label = T 'Mode_Logoff';   Value = "-o" }
    @{ Label = T 'Mode_Hibernate'; Value = "-h" }
) | ForEach-Object {
    $item = New-Object System.Windows.Forms.MenuItem($_.Label)
    $item.Tag     = $_.Value
    $item.Checked = ($_.Value -eq $script:mode)
    $itemValue    = $_.Value
    $item.Add_Click({
        $script:mode = $itemValue
        Update-MenuCheck $modeItems $script:mode
        Write-Log (T 'Log_ModeChanged' $script:mode)
    })
    $modeItems += $item
    $menuMode.MenuItems.Add($item) | Out-Null
}
$menu.MenuItems.Add($menuMode) | Out-Null

$menuDelay = New-Object System.Windows.Forms.MenuItem((T 'MenuDelay'))
$delayItems = @()
@(
    @{ Label = T 'Delay_15'; Value = "15" }
    @{ Label = T 'Delay_30'; Value = "30" }
    @{ Label = T 'Delay_60'; Value = "60" }
) | ForEach-Object {
    $item = New-Object System.Windows.Forms.MenuItem($_.Label)
    $item.Tag     = $_.Value
    $item.Checked = ($_.Value -eq $script:delay)
    $itemValue    = $_.Value
    $item.Add_Click({
        $script:delay = $itemValue
        Update-MenuCheck $delayItems $script:delay
        Write-Log (T 'Log_DelayChanged' $script:delay)
    })
    $delayItems += $item
    $menuDelay.MenuItems.Add($item) | Out-Null
}
$menu.MenuItems.Add($menuDelay) | Out-Null

$menu.MenuItems.Add("-") | Out-Null

$menuShowLogLabel = T 'MenuShowLog'
$menu.MenuItems.Add($menuShowLogLabel, {
    if ($config.ShowConsole) {
        [ConsoleWindow]::ShowWindow($consoleHwnd, 0) | Out-Null
        $config.ShowConsole = $false
    } else {
        [ConsoleWindow]::ShowWindow($consoleHwnd, 5) | Out-Null
        $config.ShowConsole = $true
    }
}) | Out-Null

$menuExitLabel = T 'MenuExit'
$menu.MenuItems.Add($menuExitLabel, {
    $timer.Stop()
    $listener.Stop()
    $icon.Visible = $false
    $trayIcon.Dispose()
    [ConsoleWindow]::ShowWindow($consoleHwnd, 0) | Out-Null
    [System.Windows.Forms.Application]::Exit()
}) | Out-Null

$icon.ContextMenu = $menu

# --- タイマーポーリング処理を開始 ---
# Start timer polling
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
                Write-Log (T 'Log_RequestAuthFailed' $req.RemoteEndPoint)
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
                        Safe-StartProcess $config.AbortCmd @($config.AbortArgs)
                        Write-Log (T 'Log_AbortByWeb' $req.RemoteEndPoint)
                        if ($script:cancelHandler) {
                            try { $icon.remove_BalloonTipClicked($script:cancelHandler) } catch { }
                            $script:cancelHandler = $null
                        }
                        try {
                            $icon.BalloonTipTitle = T 'TrayText'
                            $icon.BalloonTipText  = T 'AbortedBalloon'
                            $icon.ShowBalloonTip(3000)
                        } catch { }
                        $msgToEncode = T 'AbortDoneMsg'
                        $msgEncoded = [System.Web.HttpUtility]::UrlEncode($msgToEncode)
                        $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)&msg=$msgEncoded" } else { "/?msg=$msgEncoded" }
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
            Write-Log (T 'Log_RequestError' "$_")
        }

        $script:contextTask = $listener.GetContextAsync()
    }
})
$timer.Start()

# --- UIメッセージループを実行 ---
# Run UI message loop
[System.Windows.Forms.Application]::Run()

# --- クリーンアップ処理を実行 ---
# Perform cleanup
$timer.Stop()
$timer.Dispose()
if ($listener.IsListening) { $listener.Stop() }
$icon.Visible = $false
$trayIcon.Dispose()
Write-Log (T 'Log_Cleanup')
