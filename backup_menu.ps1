Add-Type -AssemblyName System.Windows.Forms

# -------------------- Functions --------------------
# Validation
function Get-Sources([string]$Sources, [string]$ErrorMsg = "") {
    $sourcesArray = $Sources -split ','
    foreach ($s in $sourcesArray) {
        if ([string]::IsNullOrWhiteSpace($s)) {
            Log "ERROR" "Some source path is empty. $ErrorMsg"
            return $null
        }
        if (-not (Test-Path $s)) {
            Log "ERROR" "Source path '$s' does not exist. $ErrorMsg"
            return $null
        }
    }
    return , $sourcesArray   # ',' will force to return an array even if single item
}

function Test-Destination([string]$Destination, [string]$ErrorMsg = "") {
    if ([string]::IsNullOrWhiteSpace($Destination)) {
        Log "ERROR" "Destination path empty. $ErrorMsg"
        return $false
    }
    if (Test-Path $Destination -PathType Leaf) {
        Log "ERROR" "Destination is a file. $ErrorMsg"
        return $false
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    return $true
}

# Functionality
function Backup([string]$Type, [string]$Sources, [string]$Destination, [bool]$Compression) {
    $sourcesArray = Get-Sources $Sources "Backup skipped"
    if (-not $sourcesArray) { return }
    if (-not (Test-Destination $Destination "Backup skipped" -eq $false)) { return }

    $t = (Get-Date).ToString("HH.mm.ss")
    $d = (Get-Date).ToString("yyyy_MM_dd")
    $sourceName = Split-Path -Leaf $sourcesArray[0]
    $newName = "$sourceName $d $t $Type"

    if ($Compression) {
        Log "TRACE" "Compressing $newName.zip ..."
        Compress-Archive -Path $sourcesArray -DestinationPath "$Destination\$newName.zip" -Force
    }
    else {
        Log "TRACE" "Copying $newName ..."
        if ($sourcesArray.Count -gt 1) { New-Item -ItemType Directory -Path "$Destination\$newName" -Force | Out-Null }
        Copy-Item -Path $sourcesArray -Destination "$Destination\$newName" -Recurse -Force
    }
}

function Restore([string]$Backup, [string]$Destination) {
    $backupItem = Get-Item $Backup
    $backupName = $backupItem.Name    
    if ($backupItem.Extension -eq '.zip') {
        Log "TRACE" "Restoring '$backupName' to '$Destination' ..."
        Expand-Archive -Path $Backup -DestinationPath $Destination -Force
    } else {
        $parts = $backupName -split ' '
        if ($parts.Count -lt 4) {
            Log "ERROR" "Invalid backup name format for: '$backupName'. Should be: 'file name with extension YYYY_MM_DD HH.mm.ss MANUAL|AUTO|RESTORE'. Restore skipped."
            return
        }
        $targetName = ($parts[0..($parts.Count - 4)] -join ' ')
        Log "TRACE" "Restoring '$backupName' to '$Destination' ..."
        if ($backupItem.PSIsContainer) { $Backup += "\*" }
        Copy-Item -Path $Backup -Destination "$Destination\$targetName" -Force -Recurse
    }
}

# Selection
function Select-Folder {
    $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderDialog.Description = "Select a folder"
    $folderDialog.SelectedPath = $PSScriptRoot
    If ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $folderDialog.SelectedPath } Else { $null }
}

function Select-Files([bool]$MultiSelect) {
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $fileDialog.Title = If ($MultiSelect) { "Select one or more files" } Else { "Select a file" }
    $fileDialog.InitialDirectory = $PSScriptRoot
    $fileDialog.Multiselect = $MultiSelect
    If ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { $fileDialog.FileNames -join "," } Else { $null }
}

function Select-Files-Or-Folder([bool]$MultiSelect) {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "Select Type"
    $form.Size = New-Object System.Drawing.Size(240, 120)
    $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
    $form.MaximizeBox = $false
    $form.StartPosition = "CenterScreen"

    $label = New-Form-Item $form.Controls System.Windows.Forms.Label "Select what you want to choose:" @(25, 10) @(200, 20)
    $buttonFiles = New-Form-Item $form.Controls System.Windows.Forms.Button "File$(If ($MultiSelect) { '(s)' } Else { '' })" @(20, 40)
    $buttonFiles.Add_Click({ $form.Tag = "Files"; $form.Close() })
    $buttonFolder = New-Form-Item $form.Controls System.Windows.Forms.Button "Folder" @(120, 40)
    $buttonFolder.Add_Click({ $form.Tag = "Folder"; $form.Close() })

    $form.ShowDialog() | Out-Null
    If ($form.Tag -eq "Folder") { Select-Folder } Elseif ($form.Tag -eq "Files") { Select-Files $MultiSelect } Else { $null }
}

# UI
function New-Form-Item($Form, $ItemType, [string]$Text, [int[]]$Position, [int[]]$Size) {
    $item = New-Object $ItemType
    if ($Text) { $item.Text = $Text }
    if ($Position) { $item.Location = New-Object System.Drawing.Point($Position[0], $Position[1]) }
    if ($Size) { $item.Size = New-Object System.Drawing.Size($Size[0], $Size[1]) }
    $Form.Add($item) | Out-Null
    return $item
}

function Log([string]$Level, [string]$Msg, [bool]$NewLine = $true) {
    $lineEnding = if ($NewLine) { "`r`n" } else { "" }
    $logBox.AppendText("[$Level]`t $(Get-Date -Format 'HH:mm:ss') - $Msg$lineEnding")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}


# -------------------- Configuration --------------------
Set-Location -Path $PSScriptRoot    # Working directory for relative paths
$configPath = "config.json"
$config = try { If (Test-Path $configPath -PathType Leaf) { Get-Content -Raw $configPath | ConvertFrom-Json } Else { "" } } catch { @{} }
$defaultSources = If ($config.sources -is [string]) { $config.sources } Else { "example.txt,C:\folder name" }
$defaultDestination = If ($config.destination -is [string]) { $config.destination } Else { "Backups" }
$defaultInterval = If ($config.interval -is [int]) { $config.interval } Else { 600 }   # in seconds
$defaultCompression = If ($config.compression -is [bool]) { [bool]$config.compression } Else { $false }
$minimizeToTray = If ($config.minimizeToTray -is [bool]) { $config.minimizeToTray } Else { $true }


# -------------------- UI --------------------
# TODO: Fixed sizes cause blurry text with Display Scaling != 100%, grid layout may solve it
$form = New-Object System.Windows.Forms.Form
$form.Text = "Backup tool"
$form.Size = New-Object System.Drawing.Size(500, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
[int[]]$rowPositions = @(30, 60, 90, 130)

# Toolstrip
$toolStrip = New-Form-Item $form.Controls System.Windows.Forms.ToolStrip
$saveConfigTool = New-Form-Item $toolStrip.Items System.Windows.Forms.ToolStripMenuItem "Save Config"
$openConfig = New-Form-Item $toolStrip.Items System.Windows.Forms.ToolStripMenuItem "Open Config"
$openSourceFolder = New-Form-Item $toolStrip.Items System.Windows.Forms.ToolStripMenuItem "Open Source"
$openBackupFolderTool = New-Form-Item $toolStrip.Items System.Windows.Forms.ToolStripMenuItem "Open Backups"
$restoreTool = New-Form-Item $toolStrip.Items System.Windows.Forms.ToolStripMenuItem "Restore"

# Sources
New-Form-Item $form.Controls System.Windows.Forms.Label "Source(s):" @(10, $rowPositions[0]) @(70, 20) | Out-Null
$sourceBox = New-Form-Item $form.Controls System.Windows.Forms.TextBox $defaultSources @(80, $rowPositions[0]) @(320, 20)
$sourcesButton = New-Form-Item $form.Controls System.Windows.Forms.Button "Browse" @(410, $rowPositions[0]) @(60, 20)
$sourcesToolTip = New-Object System.Windows.Forms.ToolTip
$sourcesToolTip.SetToolTip($sourceBox, "Can be mixed files and/or folders, separated by commas")

# Destination
New-Form-Item $form.Controls System.Windows.Forms.Label "Destination:" @(10, $rowPositions[1]) (70, 20) | Out-Null
$destinationBox = New-Form-Item $form.Controls System.Windows.Forms.TextBox $defaultDestination @(80, $rowPositions[1]) (320, 20)
$destinationButton = New-Form-Item $form.Controls System.Windows.Forms.Button "Browse" @(410, $rowPositions[1]) (60, 20)

# Buttons
$buttonSize = 110
$backupButton = New-Form-Item $form.Controls System.Windows.Forms.Button "Backup" @(10, $rowPositions[2]) ($buttonSize, 30)
$startButton = New-Form-Item $form.Controls System.Windows.Forms.Button "Start" @((20 + $buttonSize), $rowPositions[2]) ($buttonSize, 30)
$stopButton = New-Form-Item $form.Controls System.Windows.Forms.Button "Stop" @((30 + $buttonSize * 2), $rowPositions[2]) ($buttonSize, 30)

# Compression
$compressionBox = New-Form-Item $form.Controls System.Windows.Forms.CheckBox "Zip?" @(370, ($rowPositions[2] - 2)) (30, 32)
$compressionBox.Checked = $defaultCompression
$compressionBox.CheckAlign = 'BottomCenter'

# Interval
New-Form-Item $form.Controls System.Windows.Forms.Label "Interval(s):" @(410, ($rowPositions[2] - 3)) @(60, 15) | Out-Null
$intervalBox = New-Form-Item $form.Controls System.Windows.Forms.TextBox $defaultInterval @(410, ($rowPositions[2] + 12)) @(60, 20)
$intervalBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center

# Logging
$logBox = New-Form-Item $form.Controls System.Windows.Forms.TextBox "" @(10, $rowPositions[3]) @(460, 180)
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)


# ---------- Actions ----------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $defaultInterval * 1000
$timer.Add_Tick({
        Backup "AUTO" $sourceBox.Text $destinationBox.Text $compressionBox.Checked
    })

$saveConfigTool.Add_Click({
        Log "INFO" "Saving configuration to $configPath"
        $config = [ordered]@{
            sources        = $sourceBox.Text
            destination    = $destinationBox.Text
            interval       = [int]$intervalBox.Text
            compression    = $compressionBox.Checked
            minimizeToTray = $minimizeToTray
        }
        if (-not (Test-Path $configPath)) { New-Item -Path $configPath -ItemType File -Force | Out-Null }
        $config | ConvertTo-Json | Set-Content -Path $configPath
    })

$openConfig.Add_Click({
        if (-not (Test-Path $configPath)) { New-Item -Path $configPath -ItemType File -Force | Out-Null }
        Invoke-Item $configPath
    })

$openSourceFolder.Add_Click({
        $sourcesArray = Get-Sources $sourceBox.Text "Cannot open"
        if (-not $sourcesArray) { return }
        $sourceItem = Get-Item $sourcesArray[0]
        $parentPath = Split-Path -Path $sourceItem.FullName -Parent
        Invoke-Item $parentPath
    })

$openBackupFolderTool.Add_Click({
        if (Test-Destination $destinationBox.Text "Cannot open" -eq $false) { Invoke-Item $destinationBox.Text }
    })

$restoreTool.Add_Click({
        $backup = Select-Files-Or-Folder $false
        if (-not $backup) { return }
        $sourcesArray = Get-Sources $sourceBox.Text "Restore skipped"
        if (-not $sourcesArray) { return }
        $sourceItem = Get-Item $sourcesArray[0]
        $sourceFolder = Split-Path -Path $sourceItem.FullName -Parent
        $confirm = [System.Windows.Forms.MessageBox]::Show(
            "Are you sure you want to restore '$backup' to '$sourceFolder'?",
            "Confirm Restore",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($confirm -ne [System.Windows.Forms.DialogResult]::Yes) { return }
        $makeBackup = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to backup current files before restoring?",
            "Confirm Backup",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
        if ($makeBackup -eq [System.Windows.Forms.DialogResult]::Yes) {
            Backup "RESTORE" $sourceBox.Text $destinationBox.Text $compressionBox.Checked
        }
        Log "INFO" "Restoring backup"
        Restore $backup $sourceFolder
    })

$sourcesButton.Add_Click({
        $sources = Select-Files-Or-Folder $true
        if ($sources) { $sourceBox.Text = $sources }
    })

$destinationButton.Add_Click({
        $destinationFolder = Select-Folder
        if ($destinationFolder) { $destinationBox.Text = $destinationFolder }
    })

$backupButton.Add_Click({
        Log "INFO" "Manual backup"
        Backup "MANUAL" $sourceBox.Text $destinationBox.Text $compressionBox.Checked
    })

$startButton.Add_Click({
        $intervalSec = [int]$intervalBox.Text
        if ($intervalSec -le 0) {
            Log "ERROR" "Select a positive interval"
            return
        }
        Log "INFO" "Starting backup"
        Backup "AUTO" $sourceBox.Text $destinationBox.Text $compressionBox.Checked
        $timer.Interval = [int]$intervalSec * 1000
        $timer.Start()
    })

$stopButton.Add_Click({
        Log "INFO" "Stopping backup"
        $timer.Stop()
    })


# -------------------- Tray --------------------
if ($minimizeToTray) {
    $tray = New-Object System.Windows.Forms.NotifyIcon
    $tray.Icon = [System.Drawing.SystemIcons]::Application
    $tray.Visible = $false
    $tray.Text = "Backup tool"

    $global:firstMinimize = $true
    $form.add_Resize({
            if ($form.WindowState -eq [System.Windows.Forms.FormWindowState]::Minimized) {
                $form.Hide()
                $tray.Visible = $true
                if ($global:firstMinimize) {
                    $global:firstMinimize = $false
                    $ballonTipText = "Application minimized to tray, click to open (can be disabled in config)"
                    $tray.ShowBalloonTip(1000, "Backup Tool", $ballonTipText, [System.Windows.Forms.ToolTipIcon]::Info)
                }
            }
        })

    $tray.Add_Click({
            $form.Show()
            $form.WindowState = [System.Windows.Forms.FormWindowState]::Normal
            $tray.Visible = $false
        })
}


$form.Add_Shown({ $form.Activate() })
# [void]$form.ShowDialog()
$form.Show()    # Show the form and return control to the script
[System.Windows.Forms.Application]::Run($form) # Keep the application running
