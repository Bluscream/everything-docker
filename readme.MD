# [![Icon](https://www.voidtools.com/e2.png)](https://www.voidtools.com/) Everything Search Docker Container

This project runs the Everything Search software (Windows-only) inside a Docker container using Wine, and exposes the UI via a web-accessible VNC server (noVNC), similar to Unraid containers.

## Features

- Everything Search (Windows version) via Wine
- Multi-arch support (amd64 and i386) using a single Dockerfile with Docker Buildx
- jlesage/baseimage-gui base image for GUI applications
- TigerVNC server with noVNC web interface
- Everything HTTP Server, ETP Server, and Server components included
- Architecture-specific binaries automatically selected during build (smaller images)

## Usage

### 1. Build and Start the Container

```sh
docker-compose build --no-cache
docker-compose up
```

### 2. Access the UI

Open your browser and go to:

```
http://localhost:5800
```

You will see the Windows Everything Search UI running inside the container via a secure web interface. The default VNC password is `vncpassword`.

### 3. Access the Everything HTTP Server

Open your browser and go to:

```
http://localhost:14680
```

This exposes the Everything HTTP Server web interface, which allows you to search and interact with Everything via HTTP requests.

### 4. Everything Server and ETP Server Ports

- Everything Server: `14630` (default)
- ETP Server: `14620` (default)

If you enable or start these servers from the VNC desktop, they will be accessible on these ports.

## Configuration

### Architecture Selection

This project uses a single Dockerfile with Docker Buildx for multi-arch builds. The Dockerfile automatically selects the correct binaries and Wine configuration based on the target architecture:

- **amd64 (x64)**: Uses 64-bit executables and plugins, Wine configured for win64
- **i386 (x86)**: Uses 32-bit executables and plugins, Wine configured for win32

Docker automatically selects the correct image variant based on your system's architecture. Each image is optimized and only contains files for its specific architecture. The default executable is `everything-1.5.exe`, but you can override it using the `EVERYTHING_BIN` environment variable:

- `everything-1.5.exe` (default) - Everything 1.5
- `everything-1.4.exe` - Everything 1.4
- `es.exe` - ES version
- `voidimageviewer.exe` - Void Image Viewer
- Or any other executable available in the image

### Other Customization

- To change the VNC or web port, edit the `docker-compose.yml` file.
- To use a different Everything executable, set the `EVERYTHING_BIN` environment variable (e.g., `EVERYTHING_BIN=everything-1.5_x86.exe`).
- To change display resolution, set `DISPLAY_WIDTH` and `DISPLAY_HEIGHT` environment variables.

### Custom Context Menu: "Copy Linux Path"

This container includes a custom context menu item that converts Windows paths (as seen by Wine) to Linux paths and copies them to the clipboard. This is useful when working with mounted volumes (e.g., Unraid shares) where you need the actual Linux path.

**How it works:**

- The "Copy Linux Path" custom verb is registered in Wine's registry and appears in the context menu for all files and folders
- The `copy_unix_path.cmd` script converts paths like `Z:\mnt\user\appdata` to `/mnt/user/appdata` and copies it to the clipboard
- The script uses Windows' built-in `clip.exe` utility (available in Wine)

**Configuration:**

- The custom verb is automatically registered in Wine's registry on container startup via `startapp.sh`
- Registry entries are added for both all file types (`HKCR\*\shell\CopyLinuxPath`) and directories (`HKCR\Directory\shell\CopyLinuxPath`)
- The script `copy_unix_path.cmd` is included in the container at `/home/everything/copy_unix_path.cmd` (accessible as `Z:\home\everything\copy_unix_path.cmd` in Wine)
- No additional setup is required - it works out of the box

**Usage:**
Right-click on any file or folder → Select "Copy Linux Path" from the context menu. The Linux path (e.g., `/mnt/user/appdata/...`) will be copied to your clipboard.

## Technical Details

### Base Image

This container uses **Debian Bullseye Slim** as the base image with:

- Wine (with multiarch support for amd64)
- Xvfb (virtual framebuffer X server)
- x11vnc (VNC server)
- noVNC (web-based VNC client)
- Supervisor (process management)
- Fluxbox (lightweight window manager)

### Process Management

The container uses **supervisor** to manage multiple processes:

- `xvfb`: Virtual X server
- `fluxbox`: Window manager
- `x11vnc`: VNC server on port 5900
- `websockify`: noVNC web interface on port 5800
- `everything`: Everything Search application

All processes are automatically restarted if they exit unexpectedly.

### Wine Configuration

- Wine prefix is located at `/home/everything/.wine`
- Wine architecture is set at build time (win64 for amd64, win32 for i386)
- Registry tweaks are applied on startup to prevent deadlocks and improve compatibility
- Custom context menu items are registered automatically

## Notes

- This container uses Wine to run Everything Search, which is a Windows application.
- The UI is accessible via any modern web browser using noVNC.
- **All data is persistent by default** and organized in the following structure:
  - `./cfg/` - Everything Search config directory (mounted to `/home/everything/cfg` in container)
    - `everything.ini` - Settings and configuration
  - `./db/` - Everything Search database directory (mounted to `/home/everything/db` in container)
    - `everything.db` - Index database
  - `/home/everything/` - Everything Search home directory (contains executables and plugin config)
    - `everything-1.5.exe` - Executable (copied from image on first run, default)
    - `Plugins-1.5a.ini` - Plugin configuration (ETP Server, Everything Server, HTTP Server) - must be next to executable
    - `plugins/` - Everything Search plugins (HTTP Server, ETP Server, etc.)
    - `.wine/` - Wine prefix (persistent Wine configuration)
  - Note: In Unraid, the structure is:
    - `/mnt/user/appdata/everything-search/data/` - Everything data
    - `/mnt/user/appdata/everything-search/.wine/` - Wine prefix

## Development

| Step  | Docker Hub                                                              | GHCR                                                                               |
| ----- | ----------------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Build | `docker build -t everything-wine:latest -f Dockerfile .`                | `docker buildx build --platform linux/amd64,linux/386 -t everything-wine:latest .` |
| Repo  | https://hub.docker.com/repository/create                                | `gh repo create mygithubuser/everything-wine`                                      |
| Tag   | `docker tag everything-wine:latest mydockeruser/everything-wine:latest` | `docker tag everything-wine:latest ghcr.io/mygithubuser/everything-wine:latest`    |
| Login | `docker login`                                                          | `echo <TOKEN> \| docker login ghcr.io -u mygithubuser --password-stdin`            |
| Push  | `docker push mydockeruser/everything-wine:latest`                       | `docker push ghcr.io/mygithubuser/everything-wine:latest`                          |

## Credits

- [Everything Search](https://www.voidtools.com/)
- [Wine](https://www.winehq.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://tigervnc.org/)
- [Supervisor](http://supervisord.org/)
