# Start PocketBase server for AIKA x Shanuzz FMT
# Usage: .\start.ps1 [-Port <int>]

param([int]$Port = 8090)

Write-Host "Starting PocketBase on 127.0.0.1:$Port ..."
& "$PSScriptRoot\pocketbase.exe" serve --dir="$PSScriptRoot\pb_data" --http="127.0.0.1:$Port"
