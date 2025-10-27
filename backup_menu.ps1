Add-Type -AssemblyName System.Windows.Forms

# -------------------- Configuration --------------------
$desktopPath = [Environment]::GetFolderPath("Desktop")
Set-Location -Path $desktopPath # For relative paths

$configPath = "$PSScriptRoot\config.json"
$config = try { If (Test-Path $configPath -PathType Leaf) { Get-Content -Raw $configPath | ConvertFrom-Json } Else { "" } } catch { @{} }
$defaultSources = If ($config.sources -is [string]) { $config.sources } Else { "C:\example.txt,relative folder path" }
$defaultDestination = If ($config.destination -is [string]) { $config.destination } Else { "$desktopPath\Backups" }
$defaultInterval = If ($config.interval -is [int]) { $config.interval } Else { 600 }   # in seconds
$minimizeToTray = If ($config.minimizeToTray -is [bool]) { $config.minimizeToTray } Else { $true }
$compression = If ($config.compression -is [bool]) { [bool]$config.compression } Else { $false }

function Test-Destination([string]$Destination, [string]$ErrorMsg = "") {
    if ([string]::IsNullOrWhiteSpace($Destination)) {
        Log "ERROR" "Destination path empty$ErrorMsg"
        return $false
    }
    if (Test-Path $Destination -PathType Leaf) {
        Log "ERROR" "Destination is a file$ErrorMsg"
        return $false
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    return $true
}

function Backup([string]$Type, [string]$Sources, [string]$Destination, [bool]$Compression) {
    $sourcesArray = $Sources -split ',' | Where-Object { $_ -ne '' }
    if ($sourcesArray.Count -eq 0) {
        Log "ERROR" "No valid source paths provided. Backup skipped"
        return
    }
    foreach ($s in $sourcesArray) {
        if (-not (Test-Path $s)) {
            Log "ERROR" "Source path '$s' does not exist. Backup skipped"
            return
        }
    }
    if (-not (Test-Destination $Destination ". Backup skipped" -eq $false)) { return }

    $t = (Get-Date).ToString("HH.mm.ss")
    $d = (Get-Date).ToString("dd_MM_yyyy")
    $sourceItem = Get-Item $sourcesArray[0]
    $newName = "$($sourceItem.Name) $d $t $Type"

    if ($Compression) {
        Log "TRACE" "Compressing $newName ..."
        Compress-Archive -Path $sourcesArray -DestinationPath "$Destination\$newName.zip" -Force
    }
    else {
        # Create directory if multiple sources
        if ($sourcesArray.Count -gt 1) {
            New-Item -ItemType Directory -Path "$Destination\$newName" -Force | Out-Null
        }
        Log "TRACE" "Copying $newName ..."
        Copy-Item -Path $sourcesArray -Destination "$Destination\$newName" -Recurse -Force
    }
}


# -------------------- Form --------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = "Backup tool"
$form.Size = New-Object System.Drawing.Size(440, 360)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedSingle
$form.MaximizeBox = $false
[int[]]$rowPositions = @(30, 60, 90, 130)

# Toolstrip
$toolStrip = New-Object System.Windows.Forms.ToolStrip
$form.Controls.Add($toolStrip)

$saveConfigTool = New-Object System.Windows.Forms.ToolStripMenuItem
$saveConfigTool.Text = "Save Config"
$toolStrip.Items.Add($saveConfigTool) | Out-Null

$openConfig = New-Object System.Windows.Forms.ToolStripMenuItem
$openConfig.Text = "Open Config"
$toolStrip.Items.Add($openConfig) | Out-Null

$openSourceFolder = New-Object System.Windows.Forms.ToolStripMenuItem
$openSourceFolder.Text = "Open Source"
$toolStrip.Items.Add($openSourceFolder) | Out-Null

$openBackupFolderTool = New-Object System.Windows.Forms.ToolStripMenuItem
$openBackupFolderTool.Text = "Open Backups"
$toolStrip.Items.Add($openBackupFolderTool) | Out-Null

$restoreTool = New-Object System.Windows.Forms.ToolStripMenuItem
$restoreTool.Text = "Restore"
$toolStrip.Items.Add($restoreTool) | Out-Null

function New-Form-Item($Form, $ItemType, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height) {
    $item = New-Object $ItemType
    $item.Text = $Text
    $item.SetBounds($X, $Y, $Width, $Height)
    $Form.Controls.Add($item)
    return $item
}

# Sources
New-Form-Item $form System.Windows.Forms.Label "Source(s):" 10 $rowPositions[0] 70 20 | Out-Null
$sourceBox = New-Form-Item $form System.Windows.Forms.TextBox $defaultSources 80 $rowPositions[0] 260 20
$sourcesButton = New-Form-Item $form System.Windows.Forms.Button "Browse" 350 $rowPositions[0] 60 20
$sourcesToolTip = New-Object System.Windows.Forms.ToolTip
$sourcesToolTip.SetToolTip($sourceBox, "Can be mixed files and/or folders, separated by commas")

# Destination
New-Form-Item $form System.Windows.Forms.Label "Destination:" 10 $rowPositions[1] 70 20 | Out-Null
$destinationBox = New-Form-Item $form System.Windows.Forms.TextBox $defaultDestination 80 $rowPositions[1] 260 20
$destinationButton = New-Form-Item $form System.Windows.Forms.Button "Browse" 350 $rowPositions[1] 60 20

# Buttons
$backupButton = New-Form-Item $form System.Windows.Forms.Button "Backup" 10 $rowPositions[2] 100 30
$startButton = New-Form-Item $form System.Windows.Forms.Button "Start" 120 $rowPositions[2] 100 30
$stopButton = New-Form-Item $form System.Windows.Forms.Button "Stop" 230 $rowPositions[2] 100 30

# Interval
New-Form-Item $form System.Windows.Forms.Label "Interval(s):" 350 ($rowPositions[2] - 3) 60 15 | Out-Null
$intervalBox = New-Form-Item $form System.Windows.Forms.TextBox $defaultInterval 350 ($rowPositions[2] + 12) 60 20
$intervalBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center

# Logging
$logBox = New-Form-Item $form System.Windows.Forms.TextBox "" 10 $rowPositions[3] 400 180
$logBox.Multiline = $true
$logBox.ScrollBars = "Vertical"
$logBox.ReadOnly = $true
$form.Controls.Add($logBox)

function Log([string]$Level, [string]$Msg, [bool]$NewLine = $true) {
    $lineEnding = if ($NewLine) { "`r`n" } else { "" }
    $logBox.AppendText("[$Level]`t $(Get-Date -Format 'HH:mm:ss') - $Msg$lineEnding")
    $logBox.SelectionStart = $logBox.Text.Length
    $logBox.ScrollToCaret()
}


# ---------- Actions ----------
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = $defaultInterval * 1000
$timer.Add_Tick({
        Backup "AUTO" $sourceBox.Text $destinationBox.Text $compression
    })

$saveConfigTool.Add_Click({
        Log "INFO" "Saving configuration to $configPath"
        $config = [ordered]@{
            sources        = $sourceBox.Text
            destination    = $destinationBox.Text
            interval       = [int]$intervalBox.Text
            minimizeToTray = $minimizeToTray
            compression    = $compression
        }
        New-Item -Path $configPath -ItemType File -Force | Out-Null
        $config | ConvertTo-Json | Set-Content -Path $configPath
    })

$openConfig.Add_Click({
        New-Item -Path $configPath -ItemType File -Force | Out-Null
        Invoke-Item $configPath
    })

$openSourceFolder.Add_Click({
        $sourcesArray = $sourceBox.Text -split ',' | Where-Object { $_ -ne '' }
        if ($sourcesArray.Count -eq 0) {
            Log "ERROR" "No valid source paths provided"
            return
        }
        if (-not (Test-Path $sourcesArray[0])) {
            Log "ERROR" "Source path '$($sourcesArray[0])' does not exist"
            return
        }
        $sourceItem = Get-Item $sourcesArray[0]
        Invoke-Item $sourceItem.DirectoryName
    })

$openBackupFolderTool.Add_Click({
        if (Test-Destination $destinationBox.Text -eq $false) { Invoke-Item $destinationBox.Text }
    })

$restoreTool.Add_Click({
        [System.Windows.Forms.MessageBox]::Show("TODO", "Reminder", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })

$sourcesButton.Add_Click({
        $chooseFolder = [System.Windows.Forms.MessageBox]::Show(
            "Do you want to select only one folder? (Click 'No' to select file(s))",
            "Select Type",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($chooseFolder -eq [System.Windows.Forms.DialogResult]::Yes) {
            $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
            $folderDialog.Description = "Select a folder"
            if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $sourceBox.Text = $folderDialog.SelectedPath
            }
        }
        else {
            $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $fileDialog.Title = "Select a file"
            $fileDialog.Multiselect = $true
            if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $sourceBox.Text = $fileDialog.FileNames -join ","
            }
        }
    })

$destinationButton.Add_Click({
        $folderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderDialog.Description = "Select a folder"
        if ($folderDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $destinationBox.Text = $folderDialog.SelectedPath
        }
    })

$backupButton.Add_Click({
        Log "INFO" "Manual backup"
        Backup "MANUAL" $sourceBox.Text $destinationBox.Text $compression
    })

$startButton.Add_Click({
        $intervalSec = [int]$intervalBox.Text
        if ($intervalSec -le 0) {
            Log "ERROR" "Select a positive interval"
            return
        }
        Log "INFO" "Starting backup"
        Backup "AUTO" $sourceBox.Text $destinationBox.Text $compression
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
