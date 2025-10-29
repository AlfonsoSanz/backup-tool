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
- Open-code so you can adapt it (remove/add/change features) with little knowledge of powershell

### Usecases
- I use it for making backups of my videogame 👾 save files, for safety from save corruption or for games without saves loading.
- There are many more professional and advanced backup tools, but this one can still be used for any non-sensible files or data (documents, db files or similar)
- Fast and simple staff, the poweshell script is very fast to configure and versatile for file(s)/folder(s), with little menus and direct buttons to the folders
- For learning or adapting to your need, this is the first PS script I do (took me 12h or so) and the earlier versions are very simple (only 20 lines of code, as you can see in the first commits), you can go make one yourself or try to improve this one

## How to use (multiple options)
- Go to releases and download the exe file
- Download and run the powershell script (right click -> Run with PowerShell)
- Download the powershell and the Backup Launcher.vbs file to hide the console

Feel free to download/fork the repository and modify/improve/test it to your needs! (under non-commercial license, of course 😋)

### Notes on usage
- Browse to select sources will only let you select either a folder or multiple files (because of Windows dialog limitations), but **you can manually enter multiple sources** (mixed files and folders) separated by semicolons in the sources box
- Paths can be either **absolute, relative or mixed** to the script location
- Restore uses the path of the first "source" as destination

## Contributions
Bug reports, improvements and feature requests are welcome!

### Known issues
- None (yet):
    - Folders cannot be copied into files, backing up/restoring a folder - when the destination has a file with exactly the same name as the backup/restore - will fail (not perform the backup/restore)

### Compile powershell script into an executable
```
Install-Module -Name PS2EXE -Scope CurrentUser
Invoke-PS2EXE backup_menu.ps1 'Backup Tool.exe' -noConsole
```
