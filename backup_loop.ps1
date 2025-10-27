# Set file or folder to copy (without ending \)
$source = "C:\Users\test3"
$destination = "C:\Users\Backups"

# Delay in seconds
$period = 600

# Extract file path and name
$sourceInfo = Get-Item $source
$sourceLocation = $sourceInfo.DirectoryName
$sourceName = $sourceInfo.Name

while ($true) {
    # Create destination directory (Copy-Item does with -Recurse only for folders)
    if (-not (Test-Path $destination)) {
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
    }

    $t = (Get-Date).ToString("HH.mm.ss")
    $d = (Get-Date).ToString("dd_MM_yyyy")

    Write-Output "Copying $sourceName $d $t ..."
    Copy-Item -Path $source -Destination "$destination\$sourceName $d $t" -Recurse -Force

    Start-Sleep -Seconds $period
}
