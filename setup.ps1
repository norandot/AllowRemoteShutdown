# setup.ps1
# ==============================================================================
# AllowRemoteShutdown - インストール・初期設定対話スクリプト
# ==============================================================================
# このスクリプトは、アプリケーション起動に必要な設定（ポート番号、トークン、
# PsShutdown の実行パスなど）を対話式でヒアリングし、config.json を構築します。
# 
# 【ライセンスへの配慮】
# Microsoft Sysinternals の利用規約に基づき、PsShutdown の自動ダウンロードや
# 無断展開は行いません。必要に応じて公式サイトから手動ダウンロードしたファイルを指定してください。
#
# 【実行方法】
# PowerShellを起動し、このスクリプトを実行してください。
# ==============================================================================

$ErrorActionPreference = "Continue"
Clear-Host

Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host " AllowRemoteShutdown セットアップ & 初期設定スクリプト" -ForegroundColor Cyan
Write-Host "==============================================================================" -ForegroundColor Cyan
Write-Host "このスクリプトは、お使いの環境に合わせて設定ファイル (config.json) を作成します。`n"

# ------------------------------------------------------------------------------
# 1. ポート番号の確認
# ------------------------------------------------------------------------------
$defaultPort = 3000
Write-Host "[1/4] Web UIにアクセスするためのポート番号を入力してください。" -ForegroundColor Green
Write-Host "      (デフォルト: $defaultPort)" -ForegroundColor Gray
$inputPort = Read-Host "PORT番号"
if ([string]::IsNullOrWhiteSpace($inputPort)) {
    $port = $defaultPort
} else {
    if ($inputPort -match '^[0-9]+$') {
        $port = [int]$inputPort
    } else {
        Write-Host " -> 無効な入力のため、デフォルトの $defaultPort を適用します。" -ForegroundColor Yellow
        $port = $defaultPort
    }
}
Write-Host " -> 設定ポート: $port`n" -ForegroundColor DarkGray

# ------------------------------------------------------------------------------
# 2. セキュリティトークンの確認
# ------------------------------------------------------------------------------
# ランダムな5桁のトークン候補を生成
$charset = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
$randomToken = -join ((1..5) | ForEach-Object { $charset[(Get-Random -Max $charset.Length)] })

Write-Host "[2/4] 不正アクセス防止用のセキュリティトークンを設定してください。" -ForegroundColor Green
Write-Host "      何も入力せずにEnterを押すと、自動生成されたトークンが設定されます。" -ForegroundColor Gray
Write-Host "      (自動生成候補: $randomToken)" -ForegroundColor Gray
$inputToken = Read-Host "セキュリティトークン"
if ([string]::IsNullOrWhiteSpace($inputToken)) {
    $token = $randomToken
} else {
    $token = $inputToken.Trim()
}
Write-Host " -> 設定トークン: $token`n" -ForegroundColor DarkGray

# ------------------------------------------------------------------------------
# 3. PsShutdown / shutdown.exe パスの選択
# ------------------------------------------------------------------------------
Write-Host "[3/4] シャットダウン等の実行コマンドを指定してください。" -ForegroundColor Green
Write-Host "      1) Windows標準 shutdown.exe を使用する (サスペンド、休止、モニターオフ不可)" -ForegroundColor Gray
Write-Host "      2) Sysinternals PsShutdown.exe を使用する (フル機能が利用可能)" -ForegroundColor Gray
$cmdChoice = Read-Host "選択 (1 または 2) [デフォルト: 2]"

$psshutdownPath = ""
if ($cmdChoice -eq "1") {
    Write-Host " -> Windows標準の shutdown.exe を使用するように設定します。" -ForegroundColor Green
} else {
    Write-Host "`n--- PsShutdown のインストール案内 ---" -ForegroundColor Yellow
    Write-Host "PsShutdown のダウンロードは、以下 Microsoft Sysinternals 公式サイトより手動で行ってください。" -ForegroundColor Yellow
    Write-Host "URL: https://docs.microsoft.com/en-us/sysinternals/downloads/psshutdown" -ForegroundColor Cyan
    Write-Host "ダウンロードした ZIP 内の psshutdown.exe (または psshutdown64.exe) を任意の場所に解凍してください。`n"

    $defaultPath = "C:\PSTools\psshutdown.exe"
    Write-Host "解凍した psshutdown.exe のフルパスを入力してください。" -ForegroundColor Green
    Write-Host "      (デフォルト: $defaultPath)" -ForegroundColor Gray
    $inputPath = Read-Host "インストールパス"
    if ([string]::IsNullOrWhiteSpace($inputPath)) {
        $psshutdownPath = $defaultPath
    } else {
        $psshutdownPath = $inputPath.Replace('"', '').Trim() # 念のため囲み記号を除外
    }
    Write-Host " -> 設定パス: $psshutdownPath`n" -ForegroundColor DarkGray

    # レジストリ事前同意（EULA回避）の確認
    Write-Host "★ PsShutdown の初回起動時に表示される使用許諾ダイアログ(EULA)を自動同意させますか？" -ForegroundColor Yellow
    Write-Host "   (バックグラウンド実行中にダイアログでフリーズするのを防ぐために推奨します)" -ForegroundColor Gray
    $eulaChoice = Read-Host "自動同意を有効化しますか？ (Y/N) [デフォルト: Y]"
    if ($eulaChoice -ne "N" -and $eulaChoice -ne "n") {
        Write-Host "レジストリに Sysinternals EULA 同意情報を書き込んでいます..." -ForegroundColor Cyan
        $successAny = $false
        $regPaths = @("HKCU:\Software\Sysinternals\PsShutdown", "HKLM:\Software\Sysinternals\PsShutdown")
        foreach ($path in $regPaths) {
            try {
                $parent = Split-Path $path -Parent
                if (-not (Test-Path $parent -ErrorAction SilentlyContinue)) {
                    New-Item -Path (Split-Path $parent -Parent) -Name (Split-Path $parent -Leaf) -Force -ErrorAction Stop | Out-Null
                }
                if (-not (Test-Path $path -ErrorAction SilentlyContinue)) {
                    New-Item -Path $parent -Name (Split-Path $path -Leaf) -Force -ErrorAction Stop | Out-Null
                }
                New-ItemProperty -Path $path -Name "EulaAccepted" -Value 1 -PropertyType DWord -Force -ErrorAction Stop | Out-Null
                $successAny = $true
            } catch {
                # 管理者権限不足による HKLM への書き込み失敗などは無視して次のパスを試す
            }
        }
        if ($successAny) {
            Write-Host " -> レジストリの事前同意設定を正常に書き込みました。" -ForegroundColor Green
        } else {
            Write-Host " -> レジストリ書き込みに失敗しました。後ほど手動で一度 PsShutdown を起動して同意してください。" -ForegroundColor Yellow
        }
    }
}

# ------------------------------------------------------------------------------
# 4. config.json の生成と保存
# ------------------------------------------------------------------------------
Write-Host "`n[4/4] 設定ファイル (config.json) を作成しています..." -ForegroundColor Green

# 既存の設定があればバックアップ
$configFilePath = Join-Path $PSScriptRoot "config.json"
if (Test-Path $configFilePath) {
    $backupPath = $configFilePath + ".bak"
    Copy-Item $configFilePath $backupPath -Force
    Write-Host " -> 既存の config.json を $backupPath にバックアップしました。" -ForegroundColor Yellow
}

# 設定ハッシュテーブルの構築
$configObj = [ordered]@{
    port           = $port
    token          = $token
    psshutdownPath = $psshutdownPath
    mode           = "-s"
    delay          = 15
    iconIndex      = 0
    skin           = "slate"
}

# JSONとして保存 (UTF-8)
$configJson = $configObj | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($configFilePath, $configJson, [System.Text.Encoding]::UTF8)

Write-Host "`n==============================================================================" -ForegroundColor Green
Write-Host " 設定ファイルの初期構築が完了しました！" -ForegroundColor Green
Write-Host " 保存先: $configFilePath" -ForegroundColor Green
Write-Host "------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host " [設定情報]" -ForegroundColor Cyan
Write-Host "   - 待受ポート番号      : $port" -ForegroundColor White
Write-Host "   - セキュリティトークン: $token" -ForegroundColor White
if ($psshutdownPath -eq "") {
    Write-Host "   - 実行コマンド        : Windows標準 shutdown.exe (簡易モード)" -ForegroundColor White
} else {
    Write-Host "   - 実行コマンド        : PsShutdown ($psshutdownPath)" -ForegroundColor White
}
Write-Host "==============================================================================" -ForegroundColor Green
Write-Host "これで準備完了です！AllowRemoteShutdown (PowerShell) を起動してください。`n"
