# LEARNING_MINIMAL_SERVER.ps1
# ==============================================================================
# Minimal Web-Controlled Shutdown Server (Educational Skeleton)
# ==============================================================================
# This is a lightweight educational script demonstrating the absolute core
# mechanism of AllowRemoteShutdown:
# 1. Spawning a background HTTP Server using [System.Net.HttpListener]
# 2. Creating a Windows System Tray Icon using [System.Windows.Forms.NotifyIcon]
# 3. Executing local actions (like launching a script or command) via web request
#
# Requirements: Windows PowerShell (v5.1+) or PowerShell 7 (Core) with Desktop runtime.
# ==============================================================================

# Ensure UTF-8 output encoding for console
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Load required .NET assemblies for GUI components
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# ------------------------------------------------------------------------------
# 1. HTTP Listener Setup
# ------------------------------------------------------------------------------
$PORT = 8080
$listener = New-Object System.Net.HttpListener
# "http://+:8080/" allows incoming connections from any network interface (requires Administrator rights).
# Use "http://localhost:8080/" if you want to test locally without administrative privileges.
$listener.Prefixes.Add("http://+:$PORT/")

try {
    $listener.Start()
    Write-Host "Success: HTTP Server started on port $PORT." -ForegroundColor Green
} catch {
    Write-Host "Error starting server: $_" -ForegroundColor Red
    Write-Host "Fallback: Attempting to start on localhost only (no admin rights needed)..." -ForegroundColor Yellow
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$PORT/")
    try {
        $listener.Start()
        Write-Host "Success: HTTP Server started on http://localhost:$PORT/" -ForegroundColor Green
    } catch {
        Write-Host "Fatal Error: Failed to bind to port $PORT. Ensure port is not in use." -ForegroundColor Red
        Exit
    }
}

# ------------------------------------------------------------------------------
# 2. Windows System Tray (Notify Icon) Setup
# ------------------------------------------------------------------------------
$icon = New-Object System.Windows.Forms.NotifyIcon
$icon.Icon = [System.Drawing.SystemIcons]::Information # Default system blue "i" icon
$icon.Visible = $true
$icon.Text = "Minimal Shutdown Server"

# Create a Context Menu (Right-click menu) for the tray icon
$menu = New-Object System.Windows.Forms.ContextMenu
$menu.MenuItems.Add("Exit Server", { 
    # Clean up resources when exiting
    Write-Host "Stopping HTTP Server..." -ForegroundColor Yellow
    $listener.Stop()
    $listener.Close()
    $icon.Visible = $false
    Write-Host "Server Stopped. Goodbye!" -ForegroundColor Green
    [System.Windows.Forms.Application]::Exit()
}) | Out-Null
$icon.ContextMenu = $menu

# Show a balloon notification to let the user know it is running
$icon.BalloonTipTitle = "Minimal Server Running"
$icon.BalloonTipText = "Access http://localhost:$PORT/ in your browser to test."
$icon.ShowBalloonTip(3000)

# ------------------------------------------------------------------------------
# 3. Asynchronous HTTP Request Loop (Background Thread)
# ------------------------------------------------------------------------------
# We run the server request loop inside a background thread so the GUI (Tray Icon)
# does not freeze and can handle click events smoothly.
$threadStart = [System.Threading.ThreadStart] {
    Write-Host "Listening for web requests... Access http://localhost:$PORT/ in your browser." -ForegroundColor Cyan
    
    while ($listener.IsListening) {
        try {
            # GetContext() blocks the thread until a client connects
            $context = $listener.GetContext()
            $req = $context.Request
            $res = $context.Response
            
            Write-Host "Received Request: $($req.HttpMethod) $($req.Url.AbsolutePath) from $($req.RemoteEndPoint)" -ForegroundColor Gray
            
            if ($req.Url.AbsolutePath -eq '/shutdown') {
                # Executing a safe demo command: Display a popup alert on the PC screen.
                # In production, this would be: shutdown.exe /s /t 15 or psshutdown.exe
                Write-Host ">>> Remote command triggered: Demo Alert Box shown!" -ForegroundColor Red
                
                # Show Windows MessageBox on thread
                [System.Windows.Forms.MessageBox]::Show(
                    "Remote Shutdown Command Received!`n(This is a safe educational placeholder)", 
                    "AllowRemoteShutdown Simulator", 
                    [System.Windows.Forms.MessageBoxButtons]::OK, 
                    [System.Windows.Forms.MessageBoxIcon]::Warning
                ) | Out-Null
                
                # HTML response back to the client browser
                $html = "<html><body style='font-family:sans-serif; text-align:center; padding-top:50px; background:#f4f4f9; color:#333;'>"
                $html += "<h1>Action Triggered Successfully!</h1>"
                $html += "<p>A demo alert message box has been displayed on the host machine.</p>"
                $html += "<a href='/' style='color:#0066cc;'>Go Back</a>"
                $html += "</body></html>"
            }
            else {
                # Default homepage
                $html = "<html><body style='font-family:sans-serif; max-width:500px; margin:0 auto; padding:40px 20px; line-height:1.6;'>"
                $html += "<h1>Minimal Shutdown Server</h1>"
                $html += "<p>This is a simplified educational skeleton of the AllowRemoteShutdown backend.</p>"
                $html += "<div style='background:#e2f0fe; padding:15px; border-radius:5px; border-left:5px solid #0066cc; margin:20px 0;'>"
                $html += "<strong>Action Command:</strong><br>"
                $html += "Click the link below to send a trigger command:<br>"
                $html += "<a href='/shutdown' style='display:inline-block; margin-top:10px; padding:10px 20px; background:#ff3366; color:#fff; text-decoration:none; border-radius:4px; font-weight:bold;'>Trigger Action</a>"
                $html += "</div>"
                $html += "</body></html>"
            }
            
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = "text/html; charset=utf-8"
            $res.ContentLength64 = $buffer.Length
            $res.OutputStream.Write($buffer, 0, $buffer.Length)
            $res.Close()
        }
        catch {
            # Loop breaks naturally when listener is stopped from the main thread
            break
        }
    }
}

# Instantiate and kick-start the background thread
$serverThread = New-Object System.Threading.Thread($threadStart)
$serverThread.IsBackground = $true
$serverThread.Start()

# ------------------------------------------------------------------------------
# 4. Run GUI Message Loop
# ------------------------------------------------------------------------------
# Keeping the PowerShell process alive and processing GUI events
Write-Host "Running GUI event loop. To terminate, right-click the System Tray Icon and select 'Exit Server'." -ForegroundColor Yellow
[System.Windows.Forms.Application]::Run()
