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
# 管理者権限チェック（D1）
# Administrator privilege check (D1)
# ------------------------------------------------------------
# 日本語: 本ツールはpsshutdown.exeがシャットダウン特権を要求する関係上、
#         管理者権限での起動を正式仕様とする。非管理者起動のまま常駐させると、
#         psshutdown実行時にUACの昇格要求が繰り返し表示され、Windows Formsの
#         メッセージポンプと競合して操作不能になる不具合が実機で確認されている。
#         そのため、非管理者権限での起動を検出した時点で警告を表示し終了する。
# English: This tool requires Administrator privileges because psshutdown.exe
#          needs shutdown-related privileges. Running without admin rights can
#          cause a UAC prompt loop that freezes the Windows Forms message pump,
#          making the app unresponsive (confirmed on real hardware). Therefore,
#          the script checks for admin rights at startup and exits with a
#          warning if not elevated.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
$isAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    [System.Windows.Forms.MessageBox]::Show(
        "AllowRemoteShutdown は管理者権限での実行が必要です。`r`n" +
        "ショートカットのプロパティ→詳細設定→「管理者として実行」を有効にしてください。`r`n`r`n" +
        "AllowRemoteShutdown requires Administrator privileges.`r`n" +
        "Please enable 'Run as administrator' in the shortcut's Advanced properties.",
        "AllowRemoteShutdown - Administrator rights required",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    ) | Out-Null
    Exit
}

# ============================================================
# 多重起動防止（B4）
# Prevent multiple instances (B4)
# ------------------------------------------------------------
# 日本語: 同一マシン上での多重起動を防ぐため、Global名前空間のMutexで排他制御する。
#         Global\ を付与することで、別ユーザーセッションからの多重起動も防止する。
# English: Uses a named Mutex in the Global namespace to prevent multiple
#          instances on the same machine, including across different user
#          sessions (Global\ prefix).
$mutexName = "Global\AllowRemoteShutdown_Mutex_8080"
$createdNew = $false
$script:appMutex = New-Object System.Threading.Mutex($true, $mutexName, [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.Forms.MessageBox]::Show(
        "AllowRemoteShutdown は既に起動しています。`r`n" +
        "AllowRemoteShutdown is already running.",
        "AllowRemoteShutdown",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
    Exit
}

# ============================================================
# 設定（ここだけ編集する）
# Configuration - edit this section only
# ============================================================
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }

$psShutdownPath = "C:\Utility\PSTools\psshutdown.exe"

$config = @{
    Port         = 8080
    Host         = "http://+:{0}/"
    TrayText     = "AllowRemoteShutdown"
    IconIndex    = 27
    IconPath     = ""
    UseCustomIcon = $false
    Language     = "auto"
    Skin         = "slate"
    CustomSkinPath = ""
    Token        = ""
    ShowConsole  = $false
    ShutdownCmd  = $psShutdownPath
    AbortCmd     = $psShutdownPath
    AbortArgs    = "-a"
    LogFile      = "$scriptDir\AllowRemoteShutdown.log"
    # デバッグログの出力可否（A5）。$true にするとDEBUG行がログ・コンソールに出力される。
    # Whether to emit DEBUG log lines (A5). Set to $true to enable verbose debug output.
    Debug        = $false
}

$global:currentMode  = "-s"
$global:currentDelay = "15"
# ============================================================

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

$strings = @{
    ja = @{
        TrayText = "AllowRemoteShutdown"
        MenuMode = "クイックオフのモード"
        Mode_Shutdown = "シャットダウン"
        Mode_Restart  = "再起動"
        Mode_Suspend   = "サスペンド"
        Mode_Hibernate= "休止"
        Mode_Logoff   = "ログオフ"
        Mode_Lock     = "ロック"
        Mode_MonitorOff = "モニターオフ（ロック）"
        MenuDelay = "クイックオフの遅延"
        Delay_15 = "15秒"
        Delay_30 = "30秒"
        Delay_60 = "60秒"
        Delay_Custom = "任意秒数"
        MenuShowLog = "ログを表示／非表示"
        MenuExit = "終了"
        QuickHeading = "ワンタップ実行"
        QuickCurrentSetting = "現在の設定：{0} / {1}秒"
        QuickButton = "今すぐ実行"
        ChooseHeading = "モードを選んで実行"
        ExecuteButton = "このモードで実行"
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
        QuickSettingsMismatch = "PCトレイ側のクイックオフ設定が変更されています。⟳ (再読み込み) をクリックして最新の設定と同期してください。"
        SkinHeading = "スキン (テーマ) の切り替え"
        Log_ExecutedMsg = "リクエストを送信しました: {0} を {1} 秒後に実行します。"
        Log_ExecutedMsgImmediate = "リクエストを送信しました: {0} を即時実行します。"
    }
    en = @{
        TrayText = "AllowRemoteShutdown"
        MenuMode = "Quick-off Mode"
        Mode_Shutdown = "Shutdown"
        Mode_Restart  = "Restart"
        Mode_Suspend   = "Suspend"
        Mode_Hibernate= "Hibernate"
        Mode_Logoff   = "Log off"
        Mode_Lock     = "Lock"
        Mode_MonitorOff = "Monitor off (Lock)"
        MenuDelay = "Quick-off Delay"
        Delay_15 = "15s"
        Delay_30 = "30s"
        Delay_60 = "60s"
        Delay_Custom = "Custom seconds"
        MenuShowLog = "Show/Hide Log"
        MenuExit = "Exit"
        QuickHeading = "One-Tap Execute"
        QuickCurrentSetting = "Current setting: {0} / {1}s"
        QuickButton = "Run Now"
        ChooseHeading = "Choose a Mode to Execute"
        ExecuteButton = "Run this Mode"
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
        QuickSettingsMismatch = "The PC's quick execution parameters were changed. Click ⟳ (Reload) to synchronize first."
        SkinHeading = "Switch Skin (Theme)"
        Log_ExecutedMsg = "Request sent: {0} will execute in {1} seconds."
        Log_ExecutedMsgImmediate = "Request sent: {0} will execute immediately."
    }
}

$script:lang = Get-EffectiveLanguage

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

function Write-Log {
    param($message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp $message"
    try {
        Write-Host $line
        Add-Content -Path $config.LogFile -Value $line -Encoding UTF8
    } catch {
        Write-Host "Log write failed: $_" -ForegroundColor Yellow
    }
}

# デバッグ用ログ出力（A5）。$config.Debug が $true の場合のみ出力される。
# Debug-only log output (A5). Only emits when $config.Debug is $true.
function Write-DebugLog {
    param($message)
    if ($config.Debug) {
        Write-Log "DEBUG $message"
    }
}

function Safe-StartProcess {
    param(
        [string]$file,
        [string[]]$argList
    )
    try {
        if (Test-Path $file) {
            Start-Process $file -ArgumentList $argList -WindowStyle Hidden -ErrorAction Stop
        } else {
            Write-Log "Error: File not found -> $file"
        }
    } catch {
        Write-Log "Start-Process failed: $file $argList -> $_"
    }
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

function Update-MenuCheck {
    param($items, $value)
    foreach ($item in $items) {
        $item.Checked = ($item.Tag -eq $value)
    }
}

# 内部コード（-s等）からローカライズ済みラベルへ変換する（B3）。
# Converts an internal mode code (e.g. -s) to a localized label (B3).
function Get-ModeLabel {
    param([string]$modeCode)
    switch ($modeCode) {
        "-s" { return (T 'Mode_Shutdown') }
        "-r" { return (T 'Mode_Restart') }
        "-d" { return (T 'Mode_Suspend') }
        "-h" { return (T 'Mode_Hibernate') }
        "-o" { return (T 'Mode_Logoff') }
        "-l" { return (T 'Mode_Lock') }
        "-x" { return (T 'Mode_MonitorOff') }
        default { return (T 'Mode_Shutdown') }
    }
}

# CSSクラス名を取得する（Web UIの動的配色用）。
# Returns the CSS class name for a given mode code (used for dynamic button coloring).
function Get-ModeCssClass {
    param([string]$modeCode)
    switch ($modeCode) {
        "-s" { return "shutdown" }
        "-r" { return "restart" }
        "-d" { return "suspend" }
        "-h" { return "hibernate" }
        "-o" { return "logoff" }
        "-l" { return "lock" }
        "-x" { return "monitoroff" }
        default { return "shutdown" }
    }
}

function Invoke-ShutdownAction {
    param($mode, $delaySeconds, $remoteEndPoint)

    # Windows 11 / Lenovo 等の実機検証および Sysinternals 仕様に基づく特別処理：
    # ロック (-l)、モニターオフ (-x) および ログオフ (-o) オプションはタイムアウト (-t) や強制終了 (-f) パラメータを受け付けません。
    # そのため、これらの指定時は余分な引数を付与せずに即時呼び出しを行います。
    # For Lock (-l), Monitor Off (-x) and Logoff (-o), execute immediately.
    if ($mode -eq "-l" -or $mode -eq "-x" -or $mode -eq "-o") {
        $argsArray = @($mode)
        $delayToLog = "0"
    } else {
        $argsArray = @($mode, "-f", "-t", "$delaySeconds", "-v", "10", "-c")
        $delayToLog = $delaySeconds
    }

    $fullCmdLine = "$($config.ShutdownCmd) $($argsArray -join ' ')"
    $ep = if ($remoteEndPoint) { $remoteEndPoint } else { "Unknown" }

    Write-Log (T 'Log_Invoke' $mode $delayToLog $ep)
    Write-Log "Calling Process: $fullCmdLine"

    if ($script:cancelHandler) {
        try { $icon.remove_BalloonTipClicked($script:cancelHandler) } catch { }
    }

    # ロック・モニターオフ・ログオフ以外のカウントダウン時のみ、バルーン通知クリックによる中止イベントを登録
    if ($mode -ne "-l" -and $mode -ne "-x" -and $mode -ne "-o") {
        $script:cancelHandler = {
            # A4: ハードコードされた "-a" ではなく $config.AbortArgs を参照する
            # A4: reference $config.AbortArgs instead of the hardcoded "-a"
            Safe-StartProcess $config.AbortCmd @($config.AbortArgs)
            Write-Log (T 'Log_AbortByUser')
            $icon.ShowBalloonTip(3000, (T 'TrayText'), (T 'AbortedBalloon'), 1)
        }
        $icon.add_BalloonTipClicked($script:cancelHandler)

        try {
            $msg = T 'RunningBalloon' $delaySeconds
            $icon.ShowBalloonTip(([int]$delaySeconds * 1000), (T 'TrayText'), $msg, 1)
        } catch { }
    } else {
        $script:cancelHandler = $null
    }

    Safe-StartProcess $config.ShutdownCmd $argsArray
}

function Get-HtmlPage {
    param($token, $message = "", $currentMode = "-s", $currentDelay = "15")
    Write-DebugLog "Get-HtmlPage mode=$currentMode delay=$currentDelay"
    $tokenQuery = if ($token -ne "") { "?token=$token" } else { "" }
    $msgHtml = if ($message -ne "") { "<p class='msg'>$([System.Web.HttpUtility]::HtmlEncode($message))</p>" } else { "" }
    $langAttr = $script:lang

    # B3: 内部コードではなくローカライズ済みラベルを表示に使う
    $currentModeLabel = [System.Web.HttpUtility]::HtmlEncode((Get-ModeLabel $currentMode))
    $currentModeCss = Get-ModeCssClass $currentMode

    $quickHeading = [System.Web.HttpUtility]::HtmlEncode((T 'QuickHeading'))
    $quickCurrentSetting = [System.Web.HttpUtility]::HtmlEncode((T 'QuickCurrentSetting' $currentModeLabel $currentDelay))
    $quickLabel = [System.Web.HttpUtility]::HtmlEncode((T 'QuickButton'))
    $chooseHeading = [System.Web.HttpUtility]::HtmlEncode((T 'ChooseHeading'))
    $execLabel = [System.Web.HttpUtility]::HtmlEncode((T 'ExecuteButton'))
    $abortLabel = [System.Web.HttpUtility]::HtmlEncode((T 'AbortButton'))
    $modeOption_Shutdown = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Shutdown'))
    $modeOption_Restart  = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Restart'))
    $modeOption_Suspend   = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Suspend'))
    $modeOption_Hibernate= [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Hibernate'))
    $modeOption_Logoff   = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Logoff'))
    $modeOption_Lock     = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_Lock'))
    $modeOption_MonitorOff = [System.Web.HttpUtility]::HtmlEncode((T 'Mode_MonitorOff'))
    $delayOption_15 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_15'))
    $delayOption_30 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_30'))
    $delayOption_60 = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_60'))
    $delayOption_Custom = [System.Web.HttpUtility]::HtmlEncode((T 'Delay_Custom'))
    $delayPlaceholder = [System.Web.HttpUtility]::HtmlEncode((T 'CustomDelayPlaceholder'))
    $skinHeading = [System.Web.HttpUtility]::HtmlEncode((T 'SkinHeading'))
    $skinSelected_slate = if ($config.Skin -eq "slate") { "selected" } else { "" }
    $skinSelected_terminal = if ($config.Skin -eq "terminal") { "selected" } else { "" }
    $skinSelected_minimal = if ($config.Skin -eq "minimal") { "selected" } else { "" }

    if ($config.CustomSkinPath -and (Test-Path $config.CustomSkinPath)) {
        try {
            $customHtml = Get-Content -Path $config.CustomSkinPath -Raw -Encoding UTF8
            $customHtml = $customHtml.Replace('$token', $token)
            $customHtml = $customHtml.Replace('$tokenQuery', $tokenQuery)
            $customHtml = $customHtml.Replace('$msgHtml', $msgHtml)
            $customHtml = $customHtml.Replace('$langAttr', $langAttr)
            $customHtml = $customHtml.Replace('$trayText', $config.TrayText)
            $customHtml = $customHtml.Replace('$quickHeading', $quickHeading)
            $customHtml = $customHtml.Replace('$quickCurrentSetting', $quickCurrentSetting)
            $customHtml = $customHtml.Replace('$quickLabel', $quickLabel)
            $customHtml = $customHtml.Replace('$chooseHeading', $chooseHeading)
            $customHtml = $customHtml.Replace('$execLabel', $execLabel)
            $customHtml = $customHtml.Replace('$abortLabel', $abortLabel)
            $customHtml = $customHtml.Replace('$currentModeCss', $currentModeCss)
            return $customHtml
        } catch {
            Write-Log "Error loading custom skin file: $_. Falling back to built-in skins."
        }
    }

    $skinStyles = ""
    if ($config.Skin -eq "terminal") {
        $skinStyles = @"
  body { font-family: 'Courier New', monospace; background:#050505; color:#33ff33; text-align:center; padding:20px; text-shadow: 0 0 2px #33ff33; }
  h1 { font-size:1.4em; border: 1px double #33ff33; padding: 10px; max-width:340px; margin:0 auto 20px; text-transform: uppercase; }
  h2 { font-size:1em; color:#33ff33; font-weight:bold; margin:22px 0 6px; text-align:left; max-width:320px; margin-left:auto; margin-right:auto; }
  .msg { color:#ff3333; margin-bottom:16px; border: 1px dashed #ff3333; padding: 8px; }
  .current-setting { color:#88ff88; font-size:0.85em; margin:0 0 8px; }
  form { margin-bottom:14px; }
  button {
    width:90%; max-width:320px; padding:12px; font-size:1.1em; font-family: 'Courier New', monospace;
    margin:6px 0; border:1px solid #33ff33; background: transparent; color:#33ff33; cursor:pointer; text-transform: uppercase;
  }
  button:hover { background: #33ff33; color: #050505; text-shadow: none; box-shadow: 0 0 8px #33ff33; }
  select, input[type=number] { padding:6px; font-size:1em; margin:4px; border:1px solid #33ff33; background:#050505; color:#33ff33; font-family: 'Courier New', monospace; }
  .row { margin-bottom:10px; }
  .abort { border:1px solid #ff3333; color:#ff3333; }
  .abort:hover { background:#ff3333; color:#050505; box-shadow: 0 0 8px #ff3333; }
"@
    } elseif ($config.Skin -eq "minimal") {
        $skinStyles = @"
  body { font-family: ui-sans-serif, system-ui, sans-serif; background:#fafafa; color:#111; text-align:center; padding:24px; }
  h1 { font-size:1.5em; font-weight: 800; letter-spacing: -0.025em; margin-bottom:24px; text-transform: uppercase; border-bottom: 2px solid #111; display: inline-block; padding-bottom: 4px; }
  h2 { font-size:0.9em; color:#666; font-weight:700; text-transform: uppercase; letter-spacing: 0.05em; margin:24px 0 8px; text-align:left; max-width:320px; margin-left:auto; margin-right:auto; }
  .msg { background:#fee2e2; color:#b91c1c; border:2px solid #f87171; padding:10px; font-size:0.9em; font-weight:600; margin-bottom:16px; max-width:320px; margin-left:auto; margin-right:auto; }
  .current-setting { color:#4b5563; font-size:0.85em; margin:0 0 8px; font-weight: 500; }
  form { margin-bottom:14px; }
  button {
    width:90%; max-width:320px; padding:12px; font-size:0.95em; font-weight: 700;
    margin:6px 0; border:2px solid #111; background:#111; color:#fff; cursor:pointer; border-radius: 0px; text-transform: uppercase; transition: all 0.15s ease;
  }
  button:hover { background:#fff; color:#111; }
  button:active { transform: scale(0.98); }
  .shutdown:hover { border-color: #ef4444; color: #ef4444; }
  .restart:hover { border-color: #3b82f6; color: #3b82f6; }
  .suspend:hover { border-color: #0d9488; color: #0d9488; }
  .hibernate:hover { border-color: #a855f7; color: #a855f7; }
  .logoff:hover { border-color: #f59e0b; color: #f59e0b; }
  .lock:hover { border-color: #06b6d4; color: #06b6d4; }
  .monitoroff:hover { border-color: #f43f5e; color: #f43f5e; }
  .abort { background: transparent; color:#111; border: 2px solid #ef4444; }
  .abort:hover { background: #ef4444; color: #fff; }
  select, input[type=number] { padding:8px; font-size:0.9em; margin:4px; border:2px solid #111; background:#fff; color:#111; font-weight: 600; border-radius: 0px; }
  .row { margin-bottom:10px; }
"@
    } else {
        # default slate
        $skinStyles = @"
  body { font-family: sans-serif; background:#1e1e1e; color:#eee; text-align:center; padding:20px; }
  h1 { font-size:1.2em; margin-bottom:20px; }
  h2 { font-size:0.95em; color:#aaa; font-weight:normal; margin:22px 0 6px; text-align:left; max-width:320px; margin-left:auto; margin-right:auto; }
  .msg { color:#7fd; margin-bottom:16px; font-weight: 600; background: rgba(119, 255, 221, 0.1); border: 1px solid rgba(119, 255, 221, 0.2); padding: 10px; border-radius: 8px; max-width: 320px; margin-left: auto; margin-right: auto; }
  .current-setting { color:#9c9; font-size:0.85em; margin:0 0 8px; }
  form { margin-bottom:14px; }
  button {
    width:90%; max-width:320px; padding:14px; font-size:1.1em;
    margin:6px 0; border:none; border-radius:8px; cursor:pointer;
    transition: all 0.2s ease;
  }
  button:hover { filter: brightness(1.15); box-shadow: 0 4px 12px rgba(0,0,0,0.3); }
  button:active { transform: scale(0.98); }
  .shutdown  { background:#d44; color:#fff; }
  .restart   { background:#48a; color:#fff; }
  .suspend   { background:#0aa; color:#fff; }
  .hibernate { background:#86a; color:#fff; }
  .logoff    { background:#c90; color:#fff; }
  .lock      { background:#29a; color:#fff; }
  .monitoroff { background:#a65; color:#fff; }
  .abort     { background:#444; color:#fff; border:1px solid #777; }
  select, input[type=number] { padding:8px; font-size:1em; margin:4px; border-radius:6px; border:none; }
  .row { margin-bottom:10px; }
"@
    }

    @"
<!DOCTYPE html>
<html lang="$langAttr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$($config.TrayText)</title>
<style>
$skinStyles
</style>
</head>
<body>
<h1>$($config.TrayText)</h1>
$msgHtml

<h2>$quickHeading</h2>
<p class="current-setting">$quickCurrentSetting</p>
<form method="GET" action="/quick$tokenQuery">
  <input type="hidden" name="expectedMode" value="$currentMode">
  <input type="hidden" name="expectedDelay" value="$currentDelay">
  <button class="$currentModeCss" type="submit">$quickLabel</button>
</form>

<h2>$chooseHeading</h2>
<div class="row">
  <form method="GET" action="/exec" style="display:inline;">
    <input type="hidden" name="token" value="$token">
    <select name="mode" id="modeSelect">
      <option value="-s">$modeOption_Shutdown</option>
      <option value="-r">$modeOption_Restart</option>
      <option value="-d">$modeOption_Suspend</option>
      <option value="-h">$modeOption_Hibernate</option>
      <option value="-o">$modeOption_Logoff</option>
      <option value="-l">$modeOption_Lock</option>
      <option value="-x">$modeOption_MonitorOff</option>
    </select>
    <select name="delay" id="delaySelect">
      <option value="15">$delayOption_15</option>
      <option value="30">$delayOption_30</option>
      <option value="60">$delayOption_60</option>
      <option value="custom">$delayOption_Custom</option>
    </select>
    <input type="number" name="customDelay" placeholder="$delayPlaceholder" min="0" style="width:70px; display:none;" id="customDelay">
    <br>
    <button class="shutdown" type="submit" id="execButton">$execLabel</button>
  </form>
</div>

<form method="GET" action="/abort$tokenQuery">
  <button class="abort" type="submit">$abortLabel</button>
</form>

<h2>$skinHeading</h2>
<div class="row">
  <form method="GET" action="/set-skin">
    <input type="hidden" name="token" value="$token">
    <select name="skin" onchange="this.form.submit()">
      <option value="slate" $skinSelected_slate>Slate</option>
      <option value="terminal" $skinSelected_terminal>Terminal</option>
      <option value="minimal" $skinSelected_minimal>Minimal</option>
    </select>
  </form>
</div>

<script>
var delaySelect = document.getElementById('delaySelect');
var customInput = document.getElementById('customDelay');
var modeSelect = document.getElementById('modeSelect');
var execButton = document.getElementById('execButton');

// モード選択に応じて実行ボタンの配色を動的に切り替える
var modeCssMap = {
  '-s': 'shutdown', '-r': 'restart', '-d': 'suspend',
  '-h': 'hibernate', '-o': 'logoff', '-l': 'lock', '-x': 'monitoroff'
};
function updateExecButtonClass() {
  execButton.className = modeCssMap[modeSelect.value] || 'shutdown';
  
  // 即時実行系 (-l, -x, -o) かどうかの判定
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

// URLから msg パラメータを消去してヒストリをクリーンアップする（リロード時にmsgが残る問題への対策）
if (window.history && window.history.replaceState) {
  var url = new URL(window.location.href);
  if (url.searchParams.has('msg')) {
    url.searchParams.delete('msg');
    window.history.replaceState({}, document.title, url.pathname + url.search);
  }
}
</script>
</body>
</html>
"@
}

$prefix = $config.Host -f $config.Port
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($prefix)
$listener.Start()
Write-Log (T 'Log_ServerStarted' $prefix)

$trayIcon = Load-TrayIcon $config

$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon    = $trayIcon
$icon.Visible = $true
$icon.Text    = T 'TrayText'

$menu = New-Object System.Windows.Forms.ContextMenu

$menuMode = New-Object System.Windows.Forms.MenuItem((T 'MenuMode'))
$modeItems = @()
@(
    @{ Label = T 'Mode_Shutdown'; Value = "-s" }
    @{ Label = T 'Mode_Restart';  Value = "-r" }
    @{ Label = T 'Mode_Suspend';   Value = "-d" }
    @{ Label = T 'Mode_Hibernate'; Value = "-h" }
    @{ Label = T 'Mode_Logoff';   Value = "-o" }
    @{ Label = T 'Mode_Lock';     Value = "-l" }
    @{ Label = T 'Mode_MonitorOff'; Value = "-x" }
) | ForEach-Object {
    $item = New-Object System.Windows.Forms.MenuItem($_.Label)
    $item.Tag     = $_.Value
    # A2: 初期化時点の参照先を $global:currentMode に統一（$script:mode は未初期化のため常に$null）
    $item.Checked = ($_.Value -eq $global:currentMode)
    $itemValue    = $_.Value
    $item.Add_Click({
        $global:currentMode = $itemValue
        Write-DebugLog "click mode=$global:currentMode"
        Update-MenuCheck $modeItems $global:currentMode
        Write-Log (T 'Log_ModeChanged' (Get-ModeLabel $global:currentMode))
    }.GetNewClosure())
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
    # A2: 初期化時点の参照先を $global:currentDelay に統一
    $item.Checked = ($_.Value -eq $global:currentDelay)
    $itemValue    = $_.Value
    $item.Add_Click({
        # A1: $script:delay ではなく $global:currentDelay を更新する（遅延反映バグの修正）
        $global:currentDelay = $itemValue
        Update-MenuCheck $delayItems $global:currentDelay
        Write-Log (T 'Log_DelayChanged' $global:currentDelay)
    }.GetNewClosure())
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
    if ($script:appMutex) {
        try {
            $script:appMutex.ReleaseMutex()
            $script:appMutex.Dispose()
        } catch { }
    }
    [System.Windows.Forms.Application]::Exit()
}) | Out-Null

$icon.ContextMenu = $menu

# ContextMenu（レガシーAPI）は、生成直後にCheckedを設定しても
# 実際に表示するまで見た目が更新されないことがあるため、
# メニューを開く直前（Popupイベント）に必ず再同期する。
# The legacy ContextMenu control does not always repaint Checked state
# immediately after being set programmatically. Force a re-sync right
# before the menu is shown (Popup event) to guarantee the checkmark
# reflects the current mode/delay every time the tray menu opens.
$menu.Add_Popup({
    Update-MenuCheck $modeItems $global:currentMode
    Update-MenuCheck $delayItems $global:currentDelay
})

$script:cancelHandler = $null
$script:contextTask = $listener.GetContextAsync()

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 200

$stateChangingPaths = @("/quick", "/exec", "/abort")

# C1: Refererヘッダーによる簡易CSRF緩和チェック。
#     ・Refererが無い（ブックマーク・URL直打ち等） → 許可（熟練者向けの利便性を維持）
#     ・Refererが自オリジンと一致 → 許可（Web UIからの正規操作）
#     ・Refererが他オリジン → 拒否（第三者ページへの埋め込み等によるCSRFの可能性）
#     ※ Refererは仕様上省略され得るため完全な対策ではなく、多層防御の一部として扱う。
# C1: Lightweight CSRF mitigation via Referer header.
#     - No Referer (bookmark / direct URL entry) -> allow (preserves power-user convenience)
#     - Referer matches own origin -> allow (normal Web UI operation)
#     - Referer is a different origin -> deny (possible CSRF via third-party embedding)
#     Note: Referer can be legitimately absent, so this is defense-in-depth, not a complete fix.
function Test-RefererAllowed {
    param($req)
    $referer = $req.Headers["Referer"]
    if ([string]::IsNullOrEmpty($referer)) { return $true }
    try {
        $refererUri = [Uri]$referer
        $ownScheme = $req.Url.Scheme
        $ownHost   = $req.Url.Host
        $ownPort   = $req.Url.Port
        return ($refererUri.Scheme -eq $ownScheme) -and
               ($refererUri.Host -eq $ownHost) -and
               ($refererUri.Port -eq $ownPort)
    } catch {
        # Refererの形式が不正な場合は安全側に倒して拒否
        return $false
    }
}

$timer.Add_Tick({

    if (-not $listener.IsListening) { $timer.Stop(); return }

    if ($script:contextTask.IsCompleted) {
        try {
            $context = $script:contextTask.Result
            $req     = $context.Request
            $res     = $context.Response
            $path    = $req.Url.AbsolutePath

            $query = [System.Web.HttpUtility]::ParseQueryString($req.Url.Query, [System.Text.Encoding]::UTF8)

            $authorized = ($config.Token -eq "") -or
                          ($query["token"] -eq $config.Token)

            # C1: 状態変更系エンドポイントのみReferer検証の対象とする
            if ($authorized -and ($path -in $stateChangingPaths)) {
                if (-not (Test-RefererAllowed $req)) {
                    $authorized = $false
                    $res.StatusCode = 403
                    $body = [System.Text.Encoding]::UTF8.GetBytes("Forbidden (referer check failed).")
                    $res.OutputStream.Write($body, 0, $body.Length)
                    $res.Close()
                    Write-Log "中止: 外部オリジンからのリクエストを拒否 [$($req.RemoteEndPoint)] Referer=$($req.Headers['Referer'])"
                    $script:contextTask = $listener.GetContextAsync()
                    return
                }
            }

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
                        # A3: /abort からのリダイレクトに付与された msg クエリを取得しデコードして渡す
                        $msgParam = $query["msg"]
                        $msgText = if ($msgParam) { $msgParam } else { "" }
                        $html = Get-HtmlPage $config.Token $msgText $global:currentMode $global:currentDelay
                        $body = [System.Text.Encoding]::UTF8.GetBytes($html)
                        $res.ContentType = "text/html; charset=utf-8"
                        $res.Headers.Add("Cache-Control", "no-store")
                        $res.OutputStream.Write($body, 0, $body.Length)
                        $res.Close()
                    }
                    "/quick" {
                        $expectedMode = $query["expectedMode"]
                        $expectedDelay = $query["expectedDelay"]

                        $mismatch = $false
                        if ($expectedMode -and ($expectedMode -ne $global:currentMode)) { $mismatch = $true }
                        if ($expectedDelay -and ($expectedDelay -ne $global:currentDelay)) { $mismatch = $true }

                        if ($mismatch) {
                            $msgToEncode = T 'QuickSettingsMismatch'
                            $msgEncoded = [System.Web.HttpUtility]::UrlEncode($msgToEncode, [System.Text.Encoding]::UTF8)
                            $res.Headers.Add("Cache-Control", "no-store")
                            $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)&msg=$msgEncoded" } else { "/?msg=$msgEncoded" }
                            $res.Redirect($redirectUrl)
                            $res.Close()
                        } else {
                            Invoke-ShutdownAction $global:currentMode $global:currentDelay $req.RemoteEndPoint
                            
                            $modeLabel = Get-ModeLabel $global:currentMode
                            $msgToEncode = ""
                            if ($global:currentMode -in @("-l","-x","-o")) {
                                $msgToEncode = T 'Log_ExecutedMsgImmediate' $modeLabel
                            } else {
                                $msgToEncode = T 'Log_ExecutedMsg' $modeLabel $global:currentDelay
                            }
                            $msgEncoded = [System.Web.HttpUtility]::UrlEncode($msgToEncode, [System.Text.Encoding]::UTF8)

                            $res.Headers.Add("Cache-Control", "no-store")
                            $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)&msg=$msgEncoded" } else { "/?msg=$msgEncoded" }
                            $res.Redirect($redirectUrl)
                            $res.Close()
                        }
                    }
                    "/exec" {
                        $m = $query["mode"]
                        $d = $query["delay"]
                        # B1/B2/A4: モニターオフ(-x)も許可リストに追加
                        if ($m -notin @("-s","-r","-d","-h","-o","-l","-x")) { $m = "-s" }
                        if (-not ($d -match '^\d+$')) { $d = "15" }
                        Invoke-ShutdownAction $m $d $req.RemoteEndPoint

                        $modeLabel = Get-ModeLabel $m
                        $msgToEncode = ""
                        if ($m -in @("-l","-x","-o")) {
                            $msgToEncode = T 'Log_ExecutedMsgImmediate' $modeLabel
                        } else {
                            $msgToEncode = T 'Log_ExecutedMsg' $modeLabel $d
                        }
                        $msgEncoded = [System.Web.HttpUtility]::UrlEncode($msgToEncode, [System.Text.Encoding]::UTF8)

                        $res.Headers.Add("Cache-Control", "no-store")
                        $redirectUrl = if ($config.Token -ne "") { "/?token=$($config.Token)&msg=$msgEncoded" } else { "/?msg=$msgEncoded" }
                        $res.Redirect($redirectUrl)
                        $res.Close()
                    }
                    "/set-skin" {
                        $newSkin = $query["skin"]
                        if ($newSkin -in @("slate", "terminal", "minimal")) {
                            $config.Skin = $newSkin
                            $configJsonPath = Join-Path $scriptDir "config.json"
                            if (Test-Path $configJsonPath) {
                                try {
                                    $jsonContent = Get-Content -Path $configJsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
                                    $jsonContent.skin = $newSkin
                                    $jsonContent | ConvertTo-Json | Out-File -FilePath $configJsonPath -Encoding UTF8 -Force
                                    Write-Log "Skin persisted to config.json: $newSkin"
                                } catch {
                                    Write-Log "Failed to persist skin to config.json: $_"
                                }
                            }
                            Write-Log "Skin changed to: $newSkin"
                        }
                        $res.Headers.Add("Cache-Control", "no-store")
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
                        $msgEncoded = [System.Web.HttpUtility]::UrlEncode($msgToEncode, [System.Text.Encoding]::UTF8)
                        $res.Headers.Add("Cache-Control", "no-store")
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

[System.Windows.Forms.Application]::Run()

$timer.Stop()
$timer.Dispose()
if ($listener.IsListening) { $listener.Stop() }
$icon.Visible = $false
$trayIcon.Dispose()
Write-Log (T 'Log_Cleanup')

# B4: Mutexを解放する
if ($script:appMutex) {
    try {
        $script:appMutex.ReleaseMutex()
        $script:appMutex.Dispose()
    } catch { }
}
