# Docker Desktop Log Analysis

## Summary of Issues Found

Based on the analysis of Docker Desktop logs, here are the main problems identified:

### 🔴 Critical Issues

#### 1. **Junction Link Causing Service Startup Failure** ⚠️ **ROOT CAUSE IDENTIFIED**

- **Location**: `C:\Users\Bluscream\AppData\Local\Docker`
- **Issue**: This directory is a **Junction Link** pointing to `D:\Coding\Docker\AppdataLocal`
- **Details**:
  - Link Type: Junction
  - Source: `C:\Users\Bluscream\AppData\Local\Docker`
  - Target: `D:\Coding\Docker\AppdataLocal`
  - Attributes: Directory, ReparsePoint
- **Why This Causes Problems**:
  - Windows services often have issues accessing files through junction links
  - Service processes may not resolve junction links correctly during startup
  - Security/permission contexts can be different when accessing through junctions
  - Service installation/registration may fail when paths contain junctions
- **Impact**: This is preventing the Docker Desktop Service from starting, which blocks all Docker functionality

#### 2. **Docker Desktop Service Cannot Start** (Symptom of Issue #1)

- **Location**: Windows Services / Event Logs
- **Status**: Service is **Stopped** and cannot be started
- **Error**: `Cannot open com.docker.service service on computer '.'`
- **Service Details**:
  - Service Name: `com.docker.service`
  - Display Name: `Docker Desktop Service`
  - Status: **Stopped**
  - Start Type: Automatic
  - Dependencies: Requires `LanmanServer` (Server service)
- **Impact**: This is preventing Docker Desktop from initializing properly

#### 3. **Docker Engine Stuck in "Starting" State**

- **Location**: `com.docker.backend.exe.log`
- **Root Cause**: Related to issue #1 (junction link) and #2 (service cannot start)
- **Symptoms**:
  - Backend state remains `{"docker":"starting","dockerAPI":"starting",...}` for extended periods (3+ minutes)
  - Multiple timeout errors: `Get "http://ipc/ping": context deadline exceeded`
  - Engine initialization API not responding: `still waiting for init control API to respond after 3m18.1287889s`
  - API proxy errors: `still waiting for the engine to respond to _ping after 3m42.2453429s: HTTP 500`

#### 4. **IPC Communication Failures**

- **Location**: `com.docker.backend.exe.log`
- **Root Cause**: Related to issue #1 (junction link) and #2 (service cannot start)
- **Symptoms**:
  - Repeated connection timeouts: `ConnectionClosed GET /ping (1.000XXXs): Get "http://ipc/ping": context deadline exceeded`
  - Socket forwarder waiting for non-existent socket: `/run/guest-services/socketforwarder-receive-fds.sock: does not exist yet, waiting for it to be created`

#### 5. **Cache Access Denied Errors**

- **Location**: `Docker Desktop.exe.stderr.log`
- **Symptoms**:
  - `ERROR:net\disk_cache\cache_util_win.cc:20] Unable to move the cache: Access is denied. (0x5)`
  - `ERROR:net\disk_cache\disk_cache.cc:216] Unable to create cache`
  - `ERROR:gpu\ipc\host\gpu_disk_cache.cc:723] Gpu Cache Creation failed: -2`

#### 6. **Network Service Crashes**

- **Location**: `Docker Desktop.exe.stderr.log`
- **Symptoms**:
  - `ERROR:content\browser\network_service_instance_impl.cc:597] Network service crashed, restarting service.`

### ✅ Positive Findings

- **WSL2 Status**: Working correctly (Default Version: 2)
- **Docker Desktop WSL Distribution**: `docker-desktop` distribution is **Running**
- **Hyper-V Virtual Switches**: Successfully initialized for WSL
- **Service Installation**: Docker Desktop Service is properly installed

### ⚠️ Minor Issues

#### 6. **Deprecation Warnings**

- **Location**: `Docker Desktop.exe.stderr.log`
- **Symptoms**:
  - `(node:XXXX) [DEP0044] DeprecationWarning: The util.isArray API is deprecated. Please use Array.isArray() instead.`
  - These are warnings, not critical errors

## Recommended Solutions

### Solution 1: Fix Docker Desktop Service (PRIORITY) 🔴

The service cannot start, which is blocking everything. Try these steps:

1. **Check Server Service (Dependency)**:

   ```powershell
   Get-Service -Name LanmanServer
   ```

   - Ensure it's running (Docker Desktop Service depends on it)

2. **Try Starting Docker Desktop Service**:

   ```powershell
   Start-Service -Name com.docker.service
   ```

   - If this fails, proceed to step 3

3. **Repair Service Registration**:

   - Open PowerShell as Administrator
   - Navigate to Docker Desktop installation: `cd "C:\Program Files\Docker\Docker"`
   - Re-register the service:
     ```powershell
     .\com.docker.service --uninstall
     .\com.docker.service --install
     ```

4. **Restart Docker Desktop Application**:
   - Fully quit Docker Desktop (right-click system tray icon → Quit Docker Desktop)
   - Wait 30 seconds
   - Restart Docker Desktop as Administrator
   - The service should start automatically

### Solution 3: Restart Docker Desktop

1. Fully quit Docker Desktop (right-click system tray icon → Quit Docker Desktop)
2. Wait 30 seconds
3. Restart Docker Desktop as Administrator
4. Wait 2-3 minutes for full initialization

### Solution 4: Fix Cache Permissions

The cache access denied errors suggest permission issues. Try:

1. Run Docker Desktop as Administrator
2. Check if antivirus/security software is blocking Docker Desktop
3. Clear Docker Desktop cache:
   - Close Docker Desktop
   - Delete: `%LOCALAPPDATA%\Docker\cache`
   - Restart Docker Desktop

### Solution 5: Reset Docker Desktop

If the above doesn't work:

1. Export any important Docker configurations
2. Uninstall Docker Desktop
3. Delete: `%LOCALAPPDATA%\Docker` and `%APPDATA%\Docker`
4. Reinstall Docker Desktop
5. Restart your computer

### Solution 5: Check WSL2/Hyper-V Status

Since Docker Desktop uses WSL2 or Hyper-V on Windows:

1. ✅ WSL2 is working: `wsl --status` shows Version 2
2. ✅ Docker Desktop WSL distribution is running: `wsl --list --verbose` shows `docker-desktop` as Running
3. Update WSL2 if needed: `wsl --update`
4. Check Hyper-V is enabled (if using Hyper-V backend)
5. Verify virtualization is enabled in BIOS

### Solution 6: Check System Resources

- Ensure sufficient disk space (Docker needs several GB)
- Check available RAM (Docker Desktop requires at least 4GB)
- Close other resource-intensive applications

## Next Steps

1. **IMMEDIATE PRIORITY**: Try Solution 1 (Remove Junction Link) - **This is the actual root cause**
   - The junction link at `C:\Users\Bluscream\AppData\Local\Docker` → `D:\Coding\Docker\AppdataLocal` is preventing the service from starting
   - Remove the junction and use the default location, or find an alternative method to redirect Docker data
2. **If junction removed**: Restart Docker Desktop as Administrator - service should start automatically
3. **If service still won't start**: Try Solution 2 (repair service registration)
4. **If persists**: Try Solution 4 (fix cache permissions)
5. **If still failing**: Try Solution 5 (reset Docker Desktop)
6. **Check logs again**: After applying solutions, check if errors persist

## Event Log Summary

### System Log Findings:

- ✅ Hyper-V virtual switches for WSL are successfully initialized
- ✅ Docker Desktop Service was installed and configured for auto-start
- ✅ No error-level events found related to Docker/WSL/Hyper-V
- ⚠️ Service is installed but not running (cannot be started manually)

### Application Log Findings:

- No error-level events found in Application log related to Docker

### Junction Link Discovery:

- **Critical Finding**: `C:\Users\Bluscream\AppData\Local\Docker` is a junction link
- **Target**: `D:\Coding\Docker\AppdataLocal`
- **Impact**: Windows services cannot reliably access files through junction links, causing service startup failures
- **This is the root cause** of all the service-related issues

## Log File Locations

- Main logs: `%LOCALAPPDATA%\Docker\log\host\`
- Error logs: `%LOCALAPPDATA%\Docker\log\host\Docker Desktop.exe.stderr.log`
- Backend logs: `%LOCALAPPDATA%\Docker\log\host\com.docker.backend.exe.log`
- Main log: `%LOCALAPPDATA%\Docker\log\host\Docker Desktop.exe.log`
