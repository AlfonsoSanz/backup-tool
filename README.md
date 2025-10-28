# Timed Backup Tool for Windows
### Utility for performing backups on a timed interval
![Timed Backup Tool for Windows](image_exe.png)
<!-- ![alt text](image-ps.png) -->

## Features
- Allows backup of **one or more files** and/or folders simultaneously
- Can do Manual backups or Start/Stop a timer for Automatic backups at a configurable interval
- Supports compressing into **ZIP** files
- Current configuration can be saved to a file to be loaded on startup
- Fast links to configuration, backups and source folders
- Can **restore** from a selected backup
- Can be hidden to the taskbar tray (configurable)

## How to use (multiple options)
- Go to releases and download the exe file
- Download and run the powershell script (right click -> Run with PowerShell)
- Download the powershell and the Backup Launcher.vbs file to hide the console

Feel free to download/fork the repository and modify/improve/test it to your needs! (under non-commercial license, of course 😋)

## Notes on usage
- Browse to select sources will only let you select either a folder or multiple files (because of Windows dialog limitations), but **you can manually enter multiple sources** (mixed files and folders) separated by semicolons in the sources box
- Paths can be either **absolute, relative or mixed** to the script location
- Restore uses the path of the first "source" as destination

## Contributions
Bug reports, improvements and feature requests are welcome!

## Known issues
- None (yet):
    - Folders cannot be copied into files, backing up/restoring a folder - when the destination has a file with exactly the same name as the backup/restore - will fail (not perform the backup/restore)

### Compile powershell script into an executable
```
Install-Module -Name PS2EXE -Scope CurrentUser
Invoke-PS2EXE backup_menu.ps1 'Backup Tool.exe' -noConsole
```
