# AllowRemoteShutdown

## Summary
**AllowRemoteShutdown** is a lightweight, transparent remote power management server built with PowerShell 5.1 and Microsoft Sysinternals `psshutdown.exe`. 

This project emphasizes "transparency." Every logic is written in an auditable PowerShell script, avoiding third-party "black box" binaries. It is designed for intermediate to advanced users to audit and customize for their own secure environment.

## Key Features
- **Multilingual Support (i18n)**: Supports English (EN) and Japanese (JP). Automatically detects OS locale by default.
- **Various Power Modes**: Supports Shutdown, Restart, Log off, and Hibernate via tray menu.
- **System Tray Integration**: Displays a dedicated icon using the Unicode symbol "⏼" (U+23FC) and monitors the Process ID (PID).
- **Instant Feedback & Abort**:
  - **Balloon Notifications**: Notifies the user via the Action Center when an action is triggered.
  - **Click-to-Abort**: Click the notification to immediately execute `psshutdown -a` and cancel the pending action.
- **Security**: Includes Mutex for preventing multiple instances, optional Token authentication, and standard Windows URL ACL management.

## Prerequisites
- **OS**: Windows 10 / 11 (PowerShell 5.1)
- **External Tool**: `psshutdown.exe` (Download from [Microsoft Sysinternals](https://learn.microsoft.com/en-us/sysinternals/downloads/psshutdown) and place it in `C:\Utility\PSTools\`).
- **Privileges**: Administrator rights are required for port listening and executing system commands.

## Setup Instructions

Please run the following commands in an **Administrator PowerShell** terminal.

### Step 1: Register URL ACL
The following command allows the HTTP listener to bind to the port (default: 8080) for non-privileged execution.

```powershell
netsh http add urlacl url=http://+:8080/ user=Everyone
```

### Step 2: Configure Windows Firewall
Add an inbound rule to allow traffic on port 8080. It is highly recommended to limit access to your local network (e.g., 192.168.1.0/24) for security [1, 2].

```powershell
New-NetFirewallRule -DisplayName "AllowRemoteShutdown" -Direction Inbound -Action Allow -Protocol TCP -LocalPort 8080 -Profile Private -RemoteAddress 192.168.1.0/24
```
### Step 3: Create a Startup Shortcut
To run the script in the background without a visible window, create a shortcut with the following configuration:

1. **Create Shortcut**: Right-click `AllowRemoteShutdown.ps1` and select "Create shortcut".
2. **Edit Target**: Right-click the new shortcut, go to **Properties**, and modify the **Target** field (replace with your actual path):
```cmd
   C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -NoProfile -WindowStyle Hidden -File "C:\Path\To\AllowRemoteShutdown.ps1"
```

Run as Administrator: Click the Advanced button on the Shortcut tab and check "Run as administrator".
Auto-Start (Optional): If you want the server to start automatically when Windows boots, place this shortcut in the shell:startup folder.

### Usage
#### Starting the Server
 Launch the shortcut. The power symbol "⏼" will appear in the system tray

#### Tray Operations
 Right-click the tray icon to change the "Mode" (Shutdown/Restart/etc.), adjust the "Delay" (15/30/60s), or toggle the Log window

#### Client Access
 From a smartphone or another device on the same LAN, access: http://[PC_IP_Address]:8080/

#### Token Access
 If a token is configured, append ?token=xxx to the URL for the first access

#### Aborting an Action
 If a shutdown is triggered, a balloon notification appears on the PC. Clicking this notification will cancel the action

### Configuration
You can customize the behavior in the `$config` section at the top of the script.

| Parameter | Description | Default / Example |
| :--- | :--- | :--- |
| **Port** | The port number the server listens on. | `8080` |
| **Token** | Access token. If set, you must append `?token=xxx` to the URL. | `""` (Empty for none) |
| **Language** | UI Language (`"auto"`, `"ja"`, `"en"`). | `"auto"` |
| **ShutdownCmd** | Full path to the `psshutdown.exe` binary. | `C:\Path\To\psshutdown.exe` |
| **AbortArgs** | Arguments used for the cancellation command. | `"-a"` |
| **LogFile** | Path to the execution log file. | `.\AllowRemoteShutdown.log` |
| **IconIndex** | Icon index from `shell32.dll`. | `27` |
| **UseCustomIcon** | Set to `$true` to use a specific `.ico` file. | `$false` |

## Troubleshooting
- **Character Encoding**: **Crucial:** Always save the script as **UTF-8 with BOM**. PowerShell 5.1 cannot correctly parse UTF-8 files without a BOM, which will lead to broken characters or execution errors.
- **Connection Refused**:
    - Ensure your Windows Network Profile is set to **"Private"**. Inbound connections are often blocked on "Public" profiles.
    - Run `netsh http show urlacl` in an Administrator terminal to verify the port reservation exists.
- **Process Management**: If the tray icon becomes unresponsive, check the **PID** (Process ID) displayed in the startup balloon or log file and terminate the process via Task Manager.

## License & Disclaimer
- **License**: This project is licensed under the **MIT License**.
- **Disclaimer**: Use this tool at your own risk. The author is not responsible for any damages or data loss.
- **Copyright**: `psshutdown.exe` is a property of **Microsoft Corporation (Sysinternals)**. Please adhere to their specific license terms.

## Author
- Created by: **[norandot]**
- Project URL: [https://github.com/norandot/AllowRemoteShutdown/]
