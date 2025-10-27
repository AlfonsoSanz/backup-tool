' Allows running the powershell script without showing a console window
Set objShell = CreateObject("Wscript.Shell")
Set objFSO = CreateObject("Scripting.FileSystemObject")
scriptFolder = objFSO.GetParentFolderName(WScript.ScriptFullName)
objShell.Run "powershell -executionpolicy bypass -File """ & scriptFolder & "\backup_menu.ps1""", 0, False
