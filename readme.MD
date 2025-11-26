# Everything Search Docker Container

This project runs the Everything Search software (Windows-only) inside a Docker container using Wine, and exposes the UI via a web-accessible VNC server (noVNC), similar to Unraid containers.

## Features

- Everything Search (Windows version) via Wine
- Multi-arch support (amd64 and i386) with optimized architecture-specific images
- Professional GUI base image with secure web access
- TigerVNC server with noVNC web interface
- Everything HTTP Server, ETP Server, and Server components included
- Each architecture image only contains files for that architecture (smaller images)

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

You will see the Windows Everything Search UI running inside the container via a secure web interface.

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

This project uses Docker multi-arch builds with separate optimized images for each architecture. Docker automatically selects the correct image based on your system's architecture:

- **amd64 (x64)**: Optimized image containing only 64-bit executables and plugins
- **i386 (x86)**: Optimized image containing only 32-bit executables and plugins

Each image is smaller because it only contains files for its specific architecture. The default executable is `everything-1.5.exe`, but you can override it using the `EVERYTHING_BINARY` environment variable:

- `everything-1.5.exe` (default) - Everything 1.5
- `everything-1.4.exe` - Everything 1.4
- `es.exe` - ES version
- `voidimageviewer.exe` - Void Image Viewer
- Or any other executable available in the image

### Other Customization

- To change the VNC or web port, edit the `docker-compose.yml` file.
- To use a different Everything executable, set the `EVERYTHING_BINARY` environment variable (e.g., `EVERYTHING_BINARY=everything-1.5_x86.exe`).

### Custom Context Menu: "Copy Linux Path"

This container includes a custom context menu item that converts Windows paths (as seen by Wine) to Linux paths and copies them to the clipboard. This is useful when working with mounted volumes (e.g., Unraid shares) where you need the actual Linux path.

**How it works:**
- The "Copy Linux Path" custom verb is registered in Wine's registry and appears in the context menu for all files and folders
- Additionally, the "Explore Path" context menu item is configured to run the same script
- The `copy_unix_path.cmd` script converts paths like `Z:\mnt\user\appdata` to `/mnt/user/appdata` and copies it to the clipboard
- The script uses Windows' built-in `clip.exe` utility (available in Wine)

**Configuration:**
- The custom verb is automatically registered in Wine's registry on container startup via `startapp.sh`
- Registry entries are added for both all file types (`HKCR\*\shell\CopyLinuxPath`) and directories (`HKCR\Directory\shell\CopyLinuxPath`)
- The "Explore Path" command is also pre-configured in `image/config/everything.ini` via `explore_path_command2`
- The script `copy_unix_path.cmd` is included in the container at `/bin/copy_unix_path.cmd` (accessible as `Z:\bin\copy_unix_path.cmd` in Wine)
- No additional setup is required - it works out of the box

**Usage:**
You have two options to copy Linux paths:
1. **Custom Verb (Recommended):** Right-click on any file or folder → Select "Copy Linux Path" from the context menu
2. **Modified Explore Path:** Right-click on any file or folder → Select "Explore Path" from the context menu

Both methods will copy the Linux path (e.g., `/mnt/user/appdata/...`) to your clipboard.

## Notes

- This container uses Wine to run Everything Search, which is a Windows application.
- The UI is accessible via any modern web browser using noVNC.
- **All data is persistent by default** and organized in the following structure:
  - `./.data/` - Everything Search data directory (mounted to `/opt/everything` in container, gitignored)
    - `Everything-1.5a.ini` - Settings and configuration (Everything 1.5a alpha format)
    - `Plugins-1.5a.ini` - Plugin configuration (ETP Server, Everything Server, HTTP Server)
    - `Everything.db` - Index database
    - `everything-1.5.exe` - Executable (copied from image on first run, default)
    - `plugins/` - Everything Search plugins (HTTP Server, ETP Server, etc.)
  - `./.wine/` - Wine prefix (mounted directly to `/config/.wine` in container, gitignored)
  - `./.config/` - Container configuration (mounted to `/config` in container, contains VNC passwords/certificates, gitignored)
  - Note: For production use, you may want to use `./wine/` and `./config/` instead of `./.wine/` and `./.config/` by updating the docker-compose volume mounts
  - Note: In Unraid, the structure is:
    - `/mnt/user/appdata/everything-search/data/` - Everything data
    - `/mnt/user/appdata/everything-search/.wine/` - Wine prefix (direct mount, not nested)
    - `/mnt/user/appdata/everything-search/.config/` - Container config (VNC passwords, certificates)

## Development

| Step  | Docker Hub                                                              | GHCR                                                                            |
| ----- | ----------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| Build | `docker build -t everything-wine:latest .`                              | `docker build -t everything-wine:latest .`                                      |
| Repo  | https://hub.docker.com/repository/create                                | `gh repo create mygithubuser/everything-wine`                                   |
| Tag   | `docker tag everything-wine:latest mydockeruser/everything-wine:latest` | `docker tag everything-wine:latest ghcr.io/mygithubuser/everything-wine:latest` |
| Login | `docker login`                                                          | `echo <TOKEN> \| docker login ghcr.io -u mygithubuser --password-stdin`         |
| Push  | `docker push mydockeruser/everything-wine:latest`                       | `docker push ghcr.io/mygithubuser/everything-wine:latest`                       |

## Credits

- [Everything Search](https://www.voidtools.com/)
- [Wine](https://www.winehq.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://tigervnc.org/)
