# 🚀 Windows PowerShell Auto Suggestions Setup

Linux-style auto suggestions, syntax highlighting, smart history, and terminal enhancements for Windows PowerShell.

Perfect for developers using:

* PowerShell
* VS Code Terminal
* Git
* Node.js / npm
* Python
* Docker
* Developer CLI tools

---

# ✨ Features

✅ Linux-style command auto suggestions
✅ Smart history predictions
✅ Syntax highlighting
✅ Better tab completion
✅ Terminal icons support
✅ Persistent PowerShell profile setup
✅ Works in VS Code terminal
✅ One-time setup for future use

---

# 📦 Requirements

* Windows PowerShell 5+ or PowerShell 7+
* Administrator access
* Internet connection

---

# 📥 Installation Guide

## Step 1 — Open PowerShell as Administrator

* Press `Start`
* Search for `PowerShell`
* Right click → `Run as Administrator`

---

# ⚡ Step 2 — Run the Setup Script

Copy and paste the FULL script below into PowerShell:

```powershell
Write-Host ""
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " Windows Ultimate Terminal Setup "
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Install NuGet Provider
Install-PackageProvider -Name NuGet -Force -Scope CurrentUser

# Trust PSGallery
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

# Install Modules
Install-Module PSReadLine -Force -SkipPublisherCheck
Install-Module Terminal-Icons -Force

# Create PowerShell Profile if missing
if (!(Test-Path $PROFILE)) {
    New-Item -Path $PROFILE -Type File -Force
}

# Backup old profile
Copy-Item $PROFILE "$PROFILE.backup_$(Get-Date -Format yyyyMMdd_HHmmss)" -ErrorAction SilentlyContinue

# Write new profile config
@'

Import-Module PSReadLine
Import-Module Terminal-Icons

# =========================
# AUTO SUGGESTIONS
# =========================

Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle InlineView

# =========================
# BETTER COMPLETION
# =========================

Set-PSReadLineKeyHandler -Key Tab -Function Complete

# =========================
# COLORS
# =========================

Set-PSReadLineOption -Colors @{
    Command            = 'Cyan'
    Parameter          = 'Yellow'
    String             = 'Green'
    Operator           = 'Magenta'
    Variable           = 'White'
    Number             = 'Blue'
    Type               = 'DarkCyan'
    Comment            = 'DarkGreen'
}

# =========================
# HISTORY SETTINGS
# =========================

Set-PSReadLineOption -MaximumHistoryCount 10000

# =========================
# QUALITY OF LIFE
# =========================

Set-Location $HOME
Clear-Host

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " PowerShell Ultimate Setup Loaded "
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

'@ | Set-Content $PROFILE

# Reload profile
. $PROFILE

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host " INSTALLATION COMPLETE "
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

Write-Host "Features Enabled:" -ForegroundColor Yellow
Write-Host "  Auto Suggestions"
Write-Host "  Syntax Highlighting"
Write-Host "  Smart History"
Write-Host "  Tab Completion"
Write-Host "  Terminal Icons"
Write-Host ""

Write-Host "Restart PowerShell if needed." -ForegroundColor Cyan
```

---

# 🔄 Step 3 — Restart PowerShell

Close PowerShell and open it again.

---

# 🧪 Test Auto Suggestions

Try typing previously used commands:

```powershell
git
npm
python
cd
```

You will see inline suggestions automatically.

---

# ⌨️ Keyboard Shortcuts

| Key           | Action                 |
| ------------- | ---------------------- |
| Right Arrow → | Accept suggestion      |
| Tab           | Complete command       |
| Up Arrow ↑    | Previous history       |
| Ctrl + R      | Search command history |

---

# 🖥️ Works With

✅ Windows PowerShell
✅ PowerShell 7
✅ VS Code Terminal
✅ Windows Terminal

---

# 📂 PowerShell History Location

Your command history is stored at:

```text
C:\Users\YOUR_USERNAME\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

You can back up this file to preserve suggestions after reinstalling Windows.

---

# 🔥 Future Improvements

Planned future upgrades:

* Oh My Posh themes
* Hacker-style terminal UI
* Zoxide smart navigation
* FZF command search
* Git aliases
* Docker shortcuts
* Transparent terminal themes
* Developer productivity setup

---

# 📸 Recommended Additions

Add these folders to improve your repository:

```text
screenshots/
backup/
```

Example:

```text
powershell-auto-suggestions/
│
├── README.md
├── setup.ps1
├── screenshots/
└── backup/
```

---

# ⭐ Support

If this project helped you, consider giving it a star ⭐ on GitHub.

---

# 👨‍💻 Author

Developed by Ali Hamza

GitHub:
https://github.com/AliHamza-Coder
