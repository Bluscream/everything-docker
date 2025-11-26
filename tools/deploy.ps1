#!/usr/bin/env pwsh
# PowerShell deployment script for Everything Docker
# Updates memory/restart settings and environment variable defaults across the project

param(
    [string]$RestartPolicy = "on-failure:2",
    [string]$MemoryMax = "8192m",
    [string]$MemoryReservation = "1024m",
    [string]$MemorySwap = "8192m",
    [string]$EverythingBinary = "everything-1.5.exe",
    [string]$EverythingConfig = "/home/everything/everything.ini",
    [string]$EverythingDatabase = "/home/everything/everything.db",
    [string]$Timezone = "Europe/Berlin",
    [string]$DisplayWidth = "1920",
    [string]$DisplayHeight = "945",
    [string]$SecureConnection = "1",
    [string]$UserId = "99",
    [string]$GroupId = "100",
    [string]$Umask = "000",
    [string]$Display = ":0",
    [string]$WineDebug = "-fixme-all",
    [string]$WineArch = "win64"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

Write-Host "Deploying Everything Docker configuration..." -ForegroundColor Cyan
Write-Host ""

# Display configuration
Write-Host "Memory Settings:" -ForegroundColor Yellow
Write-Host "  Max Memory: $MemoryMax"
Write-Host "  Memory Reservation: $MemoryReservation"
Write-Host "  Memory Swap: $MemorySwap"
Write-Host "  Restart Policy: $RestartPolicy"
Write-Host ""
Write-Host "Environment Variables:" -ForegroundColor Yellow
Write-Host "  EVERYTHING_BINARY: $EverythingBinary"
Write-Host "  EVERYTHING_CONFIG: $EverythingConfig"
Write-Host "  EVERYTHING_DATABASE: $EverythingDatabase"
Write-Host "  TZ: $Timezone"
Write-Host "  DISPLAY_WIDTH: $DisplayWidth"
Write-Host "  DISPLAY_HEIGHT: $DisplayHeight"
Write-Host "  SECURE_CONNECTION: $SecureConnection"
Write-Host "  USER_ID: $UserId"
Write-Host "  GROUP_ID: $GroupId"
Write-Host "  UMASK: $Umask"
Write-Host "  DISPLAY: $Display"
Write-Host "  WINEDEBUG: $WineDebug"
Write-Host "  WINEARCH: $WineArch"
Write-Host ""

# Convert memory values for docker-compose (uppercase M)
$MemoryMaxDocker = $MemoryMax -replace 'm$', 'M' -replace 'M$', 'M'
$MemoryReservationDocker = $MemoryReservation -replace 'm$', 'M' -replace 'M$', 'M'

# Update docker-compose.yml using YAML parsing
Write-Host "Updating docker-compose.yml..." -ForegroundColor Green
$DockerComposePath = Join-Path $ProjectRoot "docker-compose.yml"

# Try to use PowerShell YAML module if available, otherwise parse manually
$UseYamlModule = $false
try {
    Import-Module powershell-yaml -ErrorAction Stop
    $UseYamlModule = $true
}
catch {
    Write-Host "  Note: powershell-yaml module not found, using manual YAML parsing" -ForegroundColor Yellow
}

if ($UseYamlModule) {
    # Use YAML module for proper parsing
    $YamlContent = Get-Content $DockerComposePath -Raw | ConvertFrom-Yaml
    
    # Update restart policy
    $YamlContent.services.everything.restart = $RestartPolicy
    
    # Update memory limits
    $YamlContent.services.everything.mem_limit = $MemoryMaxDocker
    $YamlContent.services.everything.mem_reservation = $MemoryReservationDocker
    
    # Update environment variables
    $envVars = $YamlContent.services.everything.environment
    for ($i = 0; $i -lt $envVars.Count; $i++) {
        if ($envVars[$i] -match '^EVERYTHING_BINARY=') {
            $envVars[$i] = "EVERYTHING_BINARY=`${EVERYTHING_BINARY:-$EverythingBinary}"
        }
        elseif ($envVars[$i] -match '^EVERYTHING_CONFIG=') {
            $envVars[$i] = "EVERYTHING_CONFIG=`${EVERYTHING_CONFIG:-$EverythingConfig}"
        }
        elseif ($envVars[$i] -match '^EVERYTHING_DATABASE=') {
            $envVars[$i] = "EVERYTHING_DATABASE=`${EVERYTHING_DATABASE:-$EverythingDatabase}"
        }
        elseif ($envVars[$i] -match '^TZ=') {
            $envVars[$i] = "TZ=$Timezone"
        }
    }
    
    $YamlContent.services.everything.environment = $envVars
    $YamlContent | ConvertTo-Yaml | Set-Content -Path $DockerComposePath -NoNewline
}
else {
    # Manual YAML parsing (simple replacement for known patterns)
    $DockerComposeContent = Get-Content $DockerComposePath -Raw
    
    # Update restart policy
    $DockerComposeContent = $DockerComposeContent -replace 'restart:\s*"[^"]*"', "restart: `"$RestartPolicy`""
    
    # Update memory limits
    $DockerComposeContent = $DockerComposeContent -replace 'mem_limit:\s*\d+[Mm]', "mem_limit: $MemoryMaxDocker"
    $DockerComposeContent = $DockerComposeContent -replace 'mem_reservation:\s*\d+[Mm]', "mem_reservation: $MemoryReservationDocker"
    
    # Update environment variables
    $DockerComposeContent = $DockerComposeContent -replace 'EVERYTHING_BINARY=\$\{EVERYTHING_BINARY:-[^}]+\}', "EVERYTHING_BINARY=`${EVERYTHING_BINARY:-$EverythingBinary}"
    $DockerComposeContent = $DockerComposeContent -replace 'EVERYTHING_CONFIG=\$\{EVERYTHING_CONFIG:-[^}]+\}', "EVERYTHING_CONFIG=`${EVERYTHING_CONFIG:-$EverythingConfig}"
    $DockerComposeContent = $DockerComposeContent -replace 'EVERYTHING_DATABASE=\$\{EVERYTHING_DATABASE:-[^}]+\}', "EVERYTHING_DATABASE=`${EVERYTHING_DATABASE:-$EverythingDatabase}"
    $DockerComposeContent = $DockerComposeContent -replace 'TZ=[^\r\n]+', "TZ=$Timezone"
    $DockerComposeContent = $DockerComposeContent -replace 'WINEARCH=\$\{WINEARCH:-[^}]+\}', "WINEARCH=`${WINEARCH:-$WineArch}"
    
    Set-Content -Path $DockerComposePath -Value $DockerComposeContent -NoNewline
}
Write-Host "  ✓ docker-compose.yml updated" -ForegroundColor Green

# Update unraid/my-everything-search.xml using XML parsing
Write-Host "Updating unraid/my-everything-search.xml..." -ForegroundColor Green
$XmlPath = Join-Path $ProjectRoot "unraid\my-everything-search.xml"

# Read XML file - PowerShell will auto-detect encoding
# Use -Encoding UTF8 first, if that fails try Unicode (UTF-16)
try {
    $XmlContent = Get-Content $XmlPath -Raw -Encoding UTF8
    [xml]$XmlDoc = $XmlContent
}
catch {
    # If UTF-8 fails, try Unicode (UTF-16)
    $XmlContent = Get-Content $XmlPath -Raw -Encoding Unicode
    [xml]$XmlDoc = $XmlContent
}

# Update ExtraParams
$ExtraParams = "--restart=$RestartPolicy --memory=$MemoryMax --memory-reservation=$MemoryReservation --memory-swap=$MemorySwap"
$XmlDoc.Container.ExtraParams = $ExtraParams

# Update Config elements
$ConfigMap = @{
    "EVERYTHING_BINARY"   = $EverythingBinary
    "EVERYTHING_CONFIG"   = $EverythingConfig
    "EVERYTHING_DATABASE" = $EverythingDatabase
    "TZ"                  = $Timezone
    "DISPLAY_WIDTH"       = $DisplayWidth
    "DISPLAY_HEIGHT"      = $DisplayHeight
    "SECURE_CONNECTION"   = $SecureConnection
    "USER_ID"             = $UserId
    "GROUP_ID"            = $GroupId
    "UMASK"               = $Umask
    "DISPLAY"             = $Display
    "WINEDEBUG"           = $WineDebug
    "WINEARCH"            = $WineArch
}

foreach ($Config in $XmlDoc.Container.Config) {
    if ($Config.Target -and $ConfigMap.ContainsKey($Config.Target)) {
        # Update Default attribute
        $Config.SetAttribute("Default", $ConfigMap[$Config.Target])
        # Update inner text (the actual value)
        $Config.InnerText = $ConfigMap[$Config.Target]
    }
}

# Save XML as UTF-8 (preserve the working format - no encoding declaration or UTF-8)
# The working file uses UTF-8 without BOM and no encoding in declaration
$XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
$XmlWriterSettings.Indent = $true
$XmlWriterSettings.IndentChars = "  "
$XmlWriterSettings.NewLineChars = "`n"
$XmlWriterSettings.OmitXmlDeclaration = $false
$XmlWriterSettings.Encoding = New-Object System.Text.UTF8Encoding $false  # UTF-8 without BOM

$StringWriter = New-Object System.IO.StringWriter
$XmlWriter = [System.Xml.XmlWriter]::Create($StringWriter, $XmlWriterSettings)
$XmlDoc.Save($XmlWriter)
$XmlWriter.Close()

# Get the XML string and ensure it doesn't have encoding="utf-16" in declaration
$XmlString = $StringWriter.ToString()
# Remove encoding declaration or ensure it's utf-8 (or no encoding - defaults to UTF-8)
$XmlString = $XmlString -replace 'encoding="utf-16"', ''
$XmlString = $XmlString -replace 'encoding="UTF-16"', ''
# If no encoding is specified, that's fine (defaults to UTF-8 per XML spec)

# Save as UTF-8 without BOM to match the working file format
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($XmlPath, $XmlString, $Utf8NoBom)
Write-Host "  ✓ unraid/my-everything-search.xml updated" -ForegroundColor Green

# Update unraid/everything-search.plg if it exists
$PlgPath = Join-Path $ProjectRoot "unraid\everything-search.plg"
if (Test-Path $PlgPath) {
    Write-Host "Updating unraid/everything-search.plg..." -ForegroundColor Green
    [xml]$PlgDoc = Get-Content $PlgPath
    
    # Update ExtraParams
    $PlgDoc.Plugin.ExtraParams = "--restart=$RestartPolicy"
    
    # Update PostArgs
    $PostArgs = "--memory=$MemoryMax --memory-reservation=$MemoryReservation --memory-swap=$MemorySwap"
    $PlgDoc.Plugin.PostArgs = $PostArgs
    
    # Update Variable elements
    $VariableMap = @{
        "EVERYTHING_BINARY" = $EverythingBinary
        "TZ"                = $Timezone
        "DISPLAY_WIDTH"     = $DisplayWidth
        "DISPLAY_HEIGHT"    = $DisplayHeight
        "SECURE_CONNECTION" = $SecureConnection
        "USER_ID"           = $UserId
        "GROUP_ID"          = $GroupId
        "UMASK"             = $Umask
    }
    
    foreach ($Variable in $PlgDoc.Plugin.Environment.Variable) {
        if ($Variable.Name -and $VariableMap.ContainsKey($Variable.Name)) {
            $Variable.Value = $VariableMap[$Variable.Name]
        }
    }
    
    # Update Config Field elements
    foreach ($Field in $PlgDoc.Plugin.Config.Field) {
        if ($Field.Name -and $VariableMap.ContainsKey($Field.Name)) {
            $Field.Default = $VariableMap[$Field.Name]
        }
    }
    
    # Save PLG with proper formatting
    $PlgWriterSettings = New-Object System.Xml.XmlWriterSettings
    $PlgWriterSettings.Indent = $true
    $PlgWriterSettings.IndentChars = "  "
    $PlgWriterSettings.NewLineChars = "`n"
    $PlgWriterSettings.OmitXmlDeclaration = $false
    $PlgWriterSettings.Encoding = [System.Text.Encoding]::UTF8
    
    $PlgStringWriter = New-Object System.IO.StringWriter
    $PlgXmlWriter = [System.Xml.XmlWriter]::Create($PlgStringWriter, $PlgWriterSettings)
    $PlgDoc.Save($PlgXmlWriter)
    $PlgXmlWriter.Close()
    $PlgStringWriter.ToString() | Set-Content -Path $PlgPath -Encoding UTF8 -NoNewline
    Write-Host "  ✓ unraid/everything-search.plg updated" -ForegroundColor Green
}

Write-Host ""
Write-Host "Deployment complete!" -ForegroundColor Cyan
