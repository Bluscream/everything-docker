#!/usr/bin/env pwsh
# PowerShell test script for Everything Docker
# Builds, tests, and cleans up the container

param(
    [int]$WebVNCPort = 5800,
    [int]$VNCDirectPort = 5900,
    [int]$HttpServerPort = 14680,
    [int]$FtpServerPort = 14621,
    [int]$EverythingServerPort = 14630
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir

# Test results storage
$TestResults = @()

function Add-TestResult {
    param(
        [string]$TestName,
        [bool]$Success,
        [string]$ErrorCode = "",
        [string]$ErrorDescription = ""
    )
    
    $status = if ($Success) { 
        "OK" 
    }
    else { 
        if ($ErrorDescription) {
            "$ErrorCode ($ErrorDescription)"
        }
        else {
            $ErrorCode
        }
    }
    
    $result = [PSCustomObject]@{
        Test   = $TestName
        Status = $status
    }
    $script:TestResults += $result
}

function Test-Port {
    param(
        [int]$Port,
        [string]$Protocol = "TCP",
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $connection = Test-NetConnection -ComputerName localhost -Port $Port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction Stop
        return @{
            Success   = $connection
            ErrorCode = $null
        }
    }
    catch {
        $errorCode = $null
        if ($_.Exception -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.ErrorCode
        }
        elseif ($_.Exception.InnerException -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.InnerException.ErrorCode
        }
        return @{
            Success   = $false
            ErrorCode = $errorCode
        }
    }
}

function Test-HttpEndpoint {
    param(
        [string]$Url,
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $response = Invoke-WebRequest -Uri $Url -SkipCertificateCheck -TimeoutSec $TimeoutSeconds -UseBasicParsing -ErrorAction Stop
        $contentType = $response.Headers["Content-Type"]
        if (-not $contentType) {
            $contentType = $response.Content.Headers.ContentType.ToString()
        }
        if (-not $contentType) {
            $contentType = "unknown"
        }
        # Get content size
        $contentSize = 0
        if ($response.RawContentLength) {
            $contentSize = $response.RawContentLength
        }
        elseif ($response.Content -and $response.Content.Length) {
            $contentSize = $response.Content.Length
        }
        else {
            # Try to get size from content string if available
            try {
                $contentSize = $response.Content.ToString().Length
            }
            catch {
                $contentSize = 0
            }
        }
        
        $responseInfo = "GET $Url > $contentType ($contentSize bytes)"
        Write-Host "  $responseInfo" -ForegroundColor Gray
        
        return @{
            Success      = ($response.StatusCode -eq 200)
            ErrorCode    = if ($response.StatusCode -eq 200) { $null } else { $response.StatusCode }
            ResponseInfo = $responseInfo
        }
    }
    catch {
        # Check if it's an HTTP error response (has status code)
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode.value__
            $responseInfo = "GET $Url > HTTP $statusCode"
            Write-Host "  $responseInfo" -ForegroundColor Gray
            return @{
                Success      = $false
                ErrorCode    = $statusCode
                ResponseInfo = $responseInfo
            }
        }
        # Otherwise it's a connection error - get socket error code
        $errorCode = $null
        if ($_.Exception -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.ErrorCode
        }
        elseif ($_.Exception.InnerException -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.InnerException.ErrorCode
        }
        elseif ($_.Exception -is [System.Net.WebException]) {
            if ($_.Exception.InnerException -is [System.Net.Sockets.SocketException]) {
                $errorCode = $_.Exception.InnerException.ErrorCode
            }
        }
        return @{
            Success      = $false
            ErrorCode    = $errorCode
            ResponseInfo = $null
        }
    }
}

function Test-FtpMotd {
    param(
        [int]$Port,
        [int]$TimeoutSeconds = 5
    )
    
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $connectResult = $tcpClient.BeginConnect("localhost", $Port, $null, $null)
        $waitResult = $connectResult.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds), $false)
        
        if (-not $waitResult) {
            $tcpClient.Close()
            return @{
                Success   = $false
                ErrorCode = 10060  # WSAETIMEDOUT - Connection timed out
            }
        }
        
        $tcpClient.EndConnect($connectResult)
        
        # Read the MOTD (Message of the Day) - FTP servers typically send a greeting
        $stream = $tcpClient.GetStream()
        $stream.ReadTimeout = $TimeoutSeconds * 1000
        $buffer = New-Object byte[] 1024
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        
        $tcpClient.Close()
        
        if ($bytesRead -gt 0) {
            $response = [System.Text.Encoding]::ASCII.GetString($buffer, 0, $bytesRead)
            $motd = $response.Trim()
            
            # Check if response looks like FTP (typically starts with 220 or contains FTP keywords)
            if ($motd -match "220|FTP|Everything") {
                Write-Host "  MOTD: $motd" -ForegroundColor Gray
                return @{
                    Success   = $true
                    ErrorCode = $null
                    Motd      = $motd
                }
            }
            else {
                Write-Host "  Unexpected response: $motd" -ForegroundColor Gray
                return @{
                    Success   = $false
                    ErrorCode = 10054  # WSAECONNRESET - Connection reset by peer (unexpected response)
                    Motd      = $motd
                }
            }
        }
        else {
            return @{
                Success   = $false
                ErrorCode = 10054  # WSAECONNRESET - No response received
                Motd      = $null
            }
        }
    }
    catch {
        $errorCode = $null
        if ($_.Exception -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.ErrorCode
        }
        elseif ($_.Exception.InnerException -is [System.Net.Sockets.SocketException]) {
            $errorCode = $_.Exception.InnerException.ErrorCode
        }
        return @{
            Success   = $false
            ErrorCode = $errorCode
        }
    }
}

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Everything Docker Test Suite" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Clean up any existing container/image
Write-Host "[1/6] Cleaning up existing resources..." -ForegroundColor Yellow
try {
    docker-compose -f "$ProjectRoot\docker-compose.yml" down -v 2>&1 | Out-Null
    docker rmi everything-docker-everything:latest 2>&1 | Out-Null
    Add-TestResult -TestName "Cleanup" -Success $true
}
catch {
    Add-TestResult -TestName "Cleanup" -Success $true -ErrorCode "" -ErrorDescription "No existing resources to clean"
}

# Step 2: Build image
Write-Host "[2/6] Building Docker image..." -ForegroundColor Yellow
try {
    docker-compose -f "$ProjectRoot\docker-compose.yml" build 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Add-TestResult -TestName "Build Image" -Success $true
    }
    else {
        Add-TestResult -TestName "Build Image" -Success $false -ErrorCode $LASTEXITCODE -ErrorDescription "Build failed"
        throw "Build failed with exit code $LASTEXITCODE"
    }
}
catch {
    Add-TestResult -TestName "Build Image" -Success $false -ErrorCode "BUILD_ERROR" -ErrorDescription $_.Exception.Message
    throw
}

# Step 3: Start container
Write-Host "[3/6] Starting container..." -ForegroundColor Yellow
try {
    docker-compose -f "$ProjectRoot\docker-compose.yml" up -d 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Add-TestResult -TestName "Start Container" -Success $true
    }
    else {
        Add-TestResult -TestName "Start Container" -Success $false -ErrorCode $LASTEXITCODE -ErrorDescription "Start failed"
        throw "Container start failed with exit code $LASTEXITCODE"
    }
}
catch {
    Add-TestResult -TestName "Start Container" -Success $false -ErrorCode "START_ERROR" -ErrorDescription $_.Exception.Message
    throw
}

# Step 4: Wait for container to be ready
Write-Host "[4/6] Waiting for container to be ready..." -ForegroundColor Yellow
$maxWaitTime = 60
$waitInterval = 2
$elapsed = 0
$containerReady = $false

while ($elapsed -lt $maxWaitTime) {
    Start-Sleep -Seconds $waitInterval
    $elapsed += $waitInterval
    
    $containerStatus = docker ps --filter "name=everything-search" --format "{{.Status}}" 2>&1
    if ($containerStatus -match "Up") {
        # Check if Everything has started by looking at logs
        $logs = docker logs everything-search 2>&1 | Select-String -Pattern "Everything Search is running|Starting Everything" -Quiet
        if ($logs) {
            $containerReady = $true
            break
        }
    }
}

if (-not $containerReady) {
    Add-TestResult -TestName "Container Ready" -Success $false -ErrorCode "TIMEOUT" -ErrorDescription "Container did not become ready within $maxWaitTime seconds"
}
else {
    Add-TestResult -TestName "Container Ready" -Success $true
}

# Step 5: Test ports and services
Write-Host "[5/6] Testing ports and services..." -ForegroundColor Yellow

# Test VNC Web Interface - Check TCP then HTTP
Write-Host "Testing VNC Web Interface (port $WebVNCPort)..." -ForegroundColor Cyan
$tcpWebVNC = Test-Port -Port $WebVNCPort
if ($tcpWebVNC.Success) {
    $httpWebVNC = Test-HttpEndpoint -Url "https://localhost:$WebVNCPort/"
    if ($httpWebVNC.Success) {
        Add-TestResult -TestName "VNC Web Interface ($WebVNCPort)" -Success $true
    }
    else {
        $errorCode = if ($httpWebVNC.ErrorCode) { $httpWebVNC.ErrorCode.ToString() } else { "UNKNOWN" }
        Add-TestResult -TestName "VNC Web Interface ($WebVNCPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
    }
}
else {
    $errorCode = if ($tcpWebVNC.ErrorCode) { $tcpWebVNC.ErrorCode.ToString() } else { "UNKNOWN" }
    Add-TestResult -TestName "VNC Web Interface ($WebVNCPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
}

# Test VNC Direct
Write-Host "Testing VNC Direct (port $VNCDirectPort)..." -ForegroundColor Cyan
$tcpVNCDirect = Test-Port -Port $VNCDirectPort
if ($tcpVNCDirect.Success) {
    Add-TestResult -TestName "VNC Direct ($VNCDirectPort)" -Success $true
}
else {
    $errorCode = if ($tcpVNCDirect.ErrorCode) { $tcpVNCDirect.ErrorCode.ToString() } else { "UNKNOWN" }
    Add-TestResult -TestName "VNC Direct ($VNCDirectPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
}

# Test HTTP Server - Check TCP then HTTP
Write-Host "Testing HTTP Server (port $HttpServerPort)..." -ForegroundColor Cyan
$tcpHttp = Test-Port -Port $HttpServerPort
if ($tcpHttp.Success) {
    $httpResponse = Test-HttpEndpoint -Url "http://localhost:$HttpServerPort/"
    if ($httpResponse.Success) {
        Add-TestResult -TestName "HTTP Server ($HttpServerPort)" -Success $true
    }
    else {
        $errorCode = if ($httpResponse.ErrorCode) { $httpResponse.ErrorCode.ToString() } else { "UNKNOWN" }
        Add-TestResult -TestName "HTTP Server ($HttpServerPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
    }
}
else {
    $errorCode = if ($tcpHttp.ErrorCode) { $tcpHttp.ErrorCode.ToString() } else { "UNKNOWN" }
    Add-TestResult -TestName "HTTP Server ($HttpServerPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
}

# Test ETP/FTP Server - Check TCP then FTP MOTD
Write-Host "Testing ETP/FTP Server (port $FtpServerPort)..." -ForegroundColor Cyan
$tcpFtp = Test-Port -Port $FtpServerPort
if ($tcpFtp.Success) {
    $ftpResponse = Test-FtpMotd -Port $FtpServerPort
    if ($ftpResponse.Success) {
        Add-TestResult -TestName "ETP/FTP Server ($FtpServerPort)" -Success $true
    }
    else {
        $errorCode = if ($ftpResponse.ErrorCode) { $ftpResponse.ErrorCode.ToString() } else { "UNKNOWN" }
        Add-TestResult -TestName "ETP/FTP Server ($FtpServerPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
    }
}
else {
    $errorCode = if ($tcpFtp.ErrorCode) { $tcpFtp.ErrorCode.ToString() } else { "UNKNOWN" }
    Add-TestResult -TestName "ETP/FTP Server ($FtpServerPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
}

# Test Everything Server
Write-Host "Testing Everything Server (port $EverythingServerPort)..." -ForegroundColor Cyan
$tcpEverything = Test-Port -Port $EverythingServerPort
if ($tcpEverything.Success) {
    Add-TestResult -TestName "Everything Server ($EverythingServerPort)" -Success $true
}
else {
    $errorCode = if ($tcpEverything.ErrorCode) { $tcpEverything.ErrorCode.ToString() } else { "UNKNOWN" }
    Add-TestResult -TestName "Everything Server ($EverythingServerPort)" -Success $false -ErrorCode $errorCode -ErrorDescription ""
}

# Check container logs for errors
Write-Host "[6/6] Checking container logs..." -ForegroundColor Yellow
try {
    $logs = docker logs everything-search 2>&1
    $errorPatterns = @("page fault", "ERROR", "Error", "FATAL", "fatal", "exception", "Exception")
    $foundErrors = $false
    $errorMessages = @()
    
    foreach ($pattern in $errorPatterns) {
        $logMatches = $logs | Select-String -Pattern $pattern -CaseSensitive:$false
        if ($logMatches) {
            $foundErrors = $true
            $errorMessages += $logMatches | Select-Object -First 3 | ForEach-Object { $_.Line.Trim() }
        }
    }
    
    if ($foundErrors) {
        $errorDesc = ($errorMessages | Select-Object -First 1) -replace "`n", " " -replace "`r", ""
        if ($errorDesc.Length -gt 50) { $errorDesc = $errorDesc.Substring(0, 50) + "..." }
        Add-TestResult -TestName "Container Logs" -Success $false -ErrorCode "LOG_ERRORS" -ErrorDescription $errorDesc
    }
    else {
        Add-TestResult -TestName "Container Logs" -Success $true
    }
}
catch {
    Add-TestResult -TestName "Container Logs" -Success $false -ErrorCode "LOG_CHECK_ERROR" -ErrorDescription $_.Exception.Message
}

# Cleanup
Write-Host ""
Write-Host "Cleaning up..." -ForegroundColor Yellow
try {
    docker-compose -f "$ProjectRoot\docker-compose.yml" down -v 2>&1 | Out-Null
    docker rmi everything-docker-everything:latest 2>&1 | Out-Null
    Add-TestResult -TestName "Cleanup After Test" -Success $true
}
catch {
    Add-TestResult -TestName "Cleanup After Test" -Success $false -ErrorCode "CLEANUP_ERROR" -ErrorDescription $_.Exception.Message
}

# Display results table
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Test Results Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$TestResults | Format-Table -AutoSize -Property Test, Status

# Calculate summary
$totalTests = $TestResults.Count
$passedTests = ($TestResults | Where-Object { $_.Status -eq "OK" }).Count
$failedTests = $totalTests - $passedTests

Write-Host ""
Write-Host "Summary: $passedTests/$totalTests tests passed" -ForegroundColor $(if ($failedTests -eq 0) { "Green" } else { "Red" })

# Exit with appropriate code
if ($failedTests -gt 0) {
    exit 1
}
else {
    exit 0
}
