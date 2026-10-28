# 🚀 Windows PowerShell Auto Suggestions

Linux-style command auto suggestions, syntax highlighting, smart history, and a safer terminal setup for Windows PowerShell.

Works with:

- Windows PowerShell 5.1
- PowerShell 7+
- Windows Terminal
- VS Code integrated terminal
- Git, Node.js, Python, Docker, and other CLI tools

---

## ✨ Features

- ✅ Inline or list-style history predictions
- ✅ PSReadLine history predictions, plus plugin predictions on PowerShell 7.2+
- ✅ Better completion menu on `Tab`
- ✅ History de-duplication
- ✅ Larger history limit
- ✅ Optional Terminal-Icons support
- ✅ Managed profile block instead of overwriting your whole profile
- ✅ Safe uninstall, repair, status, and dry-run commands
- ✅ Automatic cleanup of the old broken profile
- ✅ Never forces `Set-Location $HOME`
- ✅ Never runs `Clear-Host`

---

## 🛠️ The old bug is fixed

The previous setup script wrote these lines into your PowerShell profile:

```powershell
Set-Location $HOME
Clear-Host
```

Because a PowerShell profile runs every time a new shell starts, every terminal was forced back to your home directory and the screen was cleared. That is why opening a terminal in a project folder took you to `C:\Users\<you>` instead.

This installer:

1. Detects that legacy profile.
2. Backs it up.
3. Removes the broken content.
4. Writes a small managed block that only configures PSReadLine.
5. Leaves your working directory alone.

---

## 📦 Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- Internet access on the first run if PSReadLine or Terminal-Icons is not already installed
- **No Administrator access required** with the default `-Scope CurrentUser`
- Terminal-Icons is installed by default; a Nerd Font is needed to render its icons

---

## ⚡ Quick install

### One line

```powershell
irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1 | iex
```

That installs PSReadLine and Terminal-Icons if needed, writes the managed snippet, and adds the managed block to your PowerShell profile.

### Safer install: download, inspect, then run

```powershell
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$url  = 'https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1'
$file = Join-Path $env:TEMP 'powershell-auto-suggestions-setup.ps1'

Invoke-RestMethod -Uri $url -OutFile $file
Get-FileHash $file -Algorithm SHA256

& $file -DryRun   # preview
& $file           # apply
```

### Install from a clone

```powershell
git clone https://github.com/AliHamza-Coder/powershell-auto-suggestions.git
cd powershell-auto-suggestions
.\setup.ps1 -DryRun
.\setup.ps1
```

If your execution policy blocks local scripts:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup.ps1
```

Or run it in the current session:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup.ps1
```

> `irm ... | iex` executes a remote script. Review the source and prefer a pinned tag plus `Get-FileHash` when you need a verifiable install.

---

## 🔁 Repair an existing installation

```powershell
.\setup.ps1 -Repair
```

Repair:

- reinstalls missing modules
- regenerates the managed snippet
- cleans the legacy broken profile if present
- keeps your other profile content

From the internet:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1))) -Repair
```

---

## 🧹 Uninstall

Local clone:

```powershell
.\setup.ps1 -Uninstall
```

From the internet:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1))) -Uninstall
```

Remove the state directory, backups, and log too:

```powershell
.\setup.ps1 -Uninstall -Purge
```

Uninstall removes:

- the managed block from your profile(s)
- the managed snippet
- the state file

It does **not** remove PSReadLine or Terminal-Icons. Those are normal PowerShell modules and may be used by other tools.

### Manual uninstall

If you prefer to do it by hand:

1. Open your profile:
   ```powershell
   notepad $PROFILE
   ```
2. Delete everything between:
   ```powershell
   # >>> powershell-auto-suggestions >>>
   # <<< powershell-auto-suggestions <<<
   ```
3. Delete the state directory:
   ```powershell
   Remove-Item "$env:LOCALAPPDATA\powershell-auto-suggestions" -Recurse -Force
   ```

The old installer also left files named `Microsoft.PowerShell_profile.ps1.backup_<timestamp>` next to your profile. They still contain the broken `Set-Location $HOME` / `Clear-Host` lines. The new installer does not restore or delete them. Delete them manually if you do not need them:

```powershell
Get-ChildItem (Split-Path $PROFILE) -Filter 'Microsoft.PowerShell_profile.ps1.backup_*' | Remove-Item -Force
```

---

## 🔍 Check the current state

```powershell
.\setup.ps1 -Status
```

Example output:

```text
powershell-auto-suggestions status
Installer version : 1.0.0
State directory   : C:\Users\you\AppData\Local\powershell-auto-suggestions
Installed at      : 2026-10-28T12:53:14.8806975+05:00
Module scope      : CurrentUser
Prediction style  : InlineView
PSReadLine        : 2.4.5
Terminal-Icons    : 0.11.0
Profile           : C:\Users\you\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1 (managed block present)
```

If you see this warning, run `-Repair`:

```text
WARNING: Set-Location $HOME
WARNING: Clear-Host
```

---

## 🧪 Dry run

Preview every change without writing anything:

```powershell
.\setup.ps1 -DryRun
```

`-WhatIf` also works:

```powershell
.\setup.ps1 -WhatIf
```

`-DryRun` does not write profiles, state, backups, or install modules.

---

## ⚙️ Options

| Option | Description |
| --- | --- |
| `-DryRun` | Preview changes without writing anything |
| `-Repair` | Reapply and clean legacy content |
| `-Uninstall` | Remove the managed profile block and snippet |
| `-Purge` | With `-Uninstall`, also remove backups and logs |
| `-Status` | Show module versions and profile state |
| `-Scope CurrentUser` | Install modules for the current user (default, no admin) |
| `-Scope AllUsers` | Install modules for all users (requires Administrator) |
| `-PredictionViewStyle InlineView` | Ghost-text suggestions (default) |
| `-PredictionViewStyle ListView` | Dropdown-style suggestion list |
| `-Banner` | Print a one-line banner when the profile loads |
| `-SkipModules` | Do not install or update modules |
| `-SkipTerminalIcons` | Skip installing and loading Terminal-Icons |
| `-AllHosts` | Configure both Windows PowerShell 5.1 and PowerShell 7 profiles |
| `-Force` | Rewrite profiles even when they look unchanged |
| `-ProfilePath <path>` | Advanced/testing: target a specific profile |
| `-StateDirectory <path>` | Advanced/testing: use a custom state directory |
| `-Ref <git-ref>` | Git ref used to download the installer module |
| `-SourceBase <url>` | Custom base URL for the installer module |
| `-ModuleHash <sha256>` | Verify the downloaded module hash |

---

## 📥 What gets installed

### Managed snippet

```text
%LOCALAPPDATA%\powershell-auto-suggestions\auto-suggestions.ps1
```

This file contains the actual PSReadLine settings. It is separate from your profile so updates never overwrite your own configuration.

### State and backups

```text
%LOCALAPPDATA%\powershell-auto-suggestions\
├── auto-suggestions.ps1
├── state.json
├── install.log
└── backups\
    └── Microsoft.PowerShell_profile.ps1.<timestamp>.bak
```

The last five backups per profile are kept.

### Profile block

The installer appends only this to your profile:

```powershell
# >>> powershell-auto-suggestions >>>
# Managed by powershell-auto-suggestions v1.0.0. Do not edit this block.
. 'C:\Users\you\AppData\Local\powershell-auto-suggestions\auto-suggestions.ps1'
# <<< powershell-auto-suggestions <<<
```

Everything outside the markers is preserved.

### Modules

- `PSReadLine` 2.2.6 or newer
- `Terminal-Icons` (optional)

Modules are installed with `-Scope CurrentUser` by default. If you use `-SkipTerminalIcons`, Terminal-Icons is not installed and the managed snippet does not load it at startup.

---

## 🖥️ Supported hosts

| Host | Supported | Notes |
| --- | --- | --- |
| Windows PowerShell 5.1 | ✅ | Uses the `Documents\WindowsPowerShell` profile |
| PowerShell 7+ | ✅ | Uses the `Documents\PowerShell` profile |
| Windows Terminal | ✅ | Any profile that runs PowerShell |
| VS Code terminal | ✅ | Uses the integrated console host |
| PowerShell ISE | ❌ | PSReadLine is not used by the ISE |

The installer configures the current host and any other host that is installed. Use `-AllHosts` to configure both profiles even if one host is not installed.

---

## ⌨️ Keyboard shortcuts

| Key | Action |
| --- | --- |
| `Tab` | Open the completion menu (`MenuComplete`) |
| `Ctrl + Space` | Open the completion menu |
| `Right Arrow` | Move through an inline suggestion one character at a time |
| `Ctrl + Right Arrow` | Accept the next word |
| `End` | Move to the end of the line |
| `F2` | Switch between `InlineView` and `ListView` |
| `Up / Down` | Navigate history |
| `Ctrl + R` | Reverse-search history |

Suggestions come from your PowerShell history and PSReadLine plugins. A command that has never been typed will not appear until it is in your history.

---

## 📂 PowerShell history location

Ask PowerShell instead of relying on a hard-coded path:

```powershell
(Get-PSReadLineOption).HistorySavePath
```

Typical location:

```text
%APPDATA%\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

Back up that file if you want to preserve suggestions after reinstalling Windows.

---

## 🔧 Troubleshooting

### The terminal still opens in the home directory

Run:

```powershell
.\setup.ps1 -Status
```

If you see `WARNING: Set-Location $HOME`, run:

```powershell
.\setup.ps1 -Repair
```

Then close **all** PowerShell windows and open a new one. Existing terminals keep the old profile until restarted.

### No suggestions appear

Check the loaded settings:

```powershell
Get-PSReadLineOption |
    Select-Object PredictionSource, PredictionViewStyle, HistorySavePath
```

Expected on PowerShell 7.2 and newer:

```text
PredictionSource    : HistoryAndPlugin
PredictionViewStyle : InlineView
```

Expected on Windows PowerShell 5.1 and PowerShell 7.0/7.1:

```text
PredictionSource    : History
PredictionViewStyle : InlineView
```

Plugin predictions are a PowerShell 7.2+ feature. On older versions the installer deliberately falls back to history-only predictions instead of warning at startup.

Also check the version:

```powershell
(Get-Module PSReadLine).Version
```

It must be `2.2.6` or newer.

### PSReadLine errors on startup

Run:

```powershell
.\setup.ps1 -Repair
```

Then restart PowerShell. If the module was just upgraded, the old version remains loaded until a restart.

### "The prediction plugin source is not supported in this version of PowerShell"

Older versions of this installer always used `HistoryAndPlugin`. On Windows PowerShell 5.1 (and PowerShell 7.0/7.1) that produces:

```text
WARNING: powershell-auto-suggestions: The prediction plugin source is not supported
in this version of PowerShell. The 7.2 or a higher version of PowerShell is required
to use this source.
```

Run:

```powershell
.\setup.ps1 -Repair
```

The repaired snippet checks the host at startup:

- PowerShell 7.2+ → `HistoryAndPlugin`
- Windows PowerShell 5.1 / PowerShell 7.0–7.1 → `History`

Then restart PowerShell.

### Startup feels slow

Terminal-Icons is loaded at startup and can add noticeable time, especially on older machines. If you do not need the icons, reinstall without it:

```powershell
.\setup.ps1 -Repair -SkipTerminalIcons
```

### Icons show as boxes

Install a Nerd Font and select it in Windows Terminal or VS Code. Terminal-Icons needs a Nerd Font for its glyphs.

### `Install-Module` fails

- Update to TLS 1.2:
  ```powershell
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  ```
- Check that PSGallery is reachable:
  ```powershell
  Get-PSRepository
  ```
- If you are offline but the modules are already installed, use:
  ```powershell
  .\setup.ps1 -SkipModules
  ```

### Execution policy blocks the script

Use a process-only bypass:

```powershell
Set-ExecutionPolicy -Scope Process Bypass -Force
.\setup.ps1
```

Or use the `irm ... | iex` form, which does not write a script file.

---

## 🔐 Security notes

- `irm ... | iex` executes remote code. Review the script first.
- Prefer a pinned tag instead of `main`:
  ```powershell
  irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/v1.0.0/setup.ps1 | iex
  ```
- Verify the SHA256 of the downloaded script with `Get-FileHash`.
- The installer downloads `src/AutoSuggestions.psm1` to a temporary cache when run through `iex`. Use `-ModuleHash` to verify it:
  ```powershell
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/AliHamza-Coder/powershell-auto-suggestions/main/setup.ps1))) -ModuleHash 'PUT_SHA256_HERE'
  ```
- The installer temporarily trusts PSGallery while installing modules, then restores your previous repository policy.
- `-Scope AllUsers` requires Administrator. The default `CurrentUser` scope does not.

---

## 🗂️ Repository layout

```text
powershell-auto-suggestions/
├── setup.ps1                  # entrypoint for local and irm | iex use
├── src/
│   ├── AutoSuggestions.psm1   # install, repair, uninstall, status logic
│   └── AutoSuggestions.psd1   # module manifest
├── tests/
│   └── smoke.ps1              # end-to-end installer tests
├── .github/
│   └── workflows/
│       └── ci.yml
├── README.md
└── LICENSE
```

---

## 🧑‍💻 Development

Run the smoke tests:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\smoke.ps1
```

The tests use temporary profile and state directories. They do not touch your real profile.

Preview against your real profile without changing it:

```powershell
.\setup.ps1 -DryRun
```

---

## 🗺️ Roadmap

- [x] Remove the `Set-Location $HOME` / `Clear-Host` bug
- [x] Managed profile block
- [x] Uninstall / repair / status / dry-run
- [x] Legacy profile cleanup
- [x] PS 5.1 and PS 7 profile support
- [x] Smoke tests and CI
- [ ] Optional theme selection
- [ ] Optional zoxide / fzf / Oh My Posh integration
- [ ] Signed release with published SHA256

---

## ⭐ Support

If this project helped you, consider giving it a star ⭐ on GitHub.

---

## 👨‍💻 Author

Developed by Ali Hamza

GitHub: [https://github.com/AliHamza-Coder](https://github.com/AliHamza-Coder)

---

## 📄 License

MIT. See [LICENSE](LICENSE).
