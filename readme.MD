# Everything Search Docker Container

This project runs the Everything Search software (Windows-only) inside a Docker container using Wine, and exposes the UI via a web-accessible VNC server (noVNC), similar to Unraid containers.

## Features
- Everything Search (Windows version) via Wine
- Separate images for x86 (32-bit) and amd64 (64-bit) architectures
- Professional GUI base image with secure web access
- TigerVNC server with noVNC web interface
- Everything HTTP Server, ETP Server, and Server components included

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

Each image is smaller because it only contains files for its specific architecture. The default executable is `Everything.exe` (mapped from `everything-1.5.exe`), but you can override it using the `EVERYTHING_BINARY` environment variable:

- `Everything.exe` (default) - Mapped from everything-1.5.exe
- `everything-1.5.exe` - Everything 1.5
- `everything-1.4.exe` - Everything 1.4
- `es.exe` - ES version
- Or any other executable available in the image

### Other Customization
- To change the VNC or web port, edit the `docker-compose.yml` file.
- To use a different Everything executable, set the `EVERYTHING_BINARY` environment variable (e.g., `EVERYTHING_BINARY=everything-1.5_x86.exe`).

## Notes
- This container uses Wine to run Everything Search, which is a Windows application.
- The UI is accessible via any modern web browser using noVNC.
- **All Everything Search data is persistent by default** and organized in the data directory:
  - `./.data/` - Everything Search data directory (mounted to `/opt/everything` in container, gitignored)
    - `Everything-1.5a.ini` - Settings and configuration (Everything 1.5a alpha format)
    - `Plugins-1.5a.ini` - Plugin configuration (ETP Server, Everything Server, HTTP Server)
    - `Everything.db` - Index database
    - `Everything.exe` - Executable (copied from image on first run)
    - `plugins/` - Everything Search plugins (HTTP Server, ETP Server, etc.)
  - Note: Wine configuration is stored inside the container and is not persisted by default
  - Note: For production use, you may want to use `./data/` instead of `./.data/` by updating the docker-compose volume mount

## Development

| Step  | Docker Hub | GHCR |
|-------|--------------------|--------------|
| Build | `docker build -t everything-wine:latest .` | `docker build -t everything-wine:latest .` |
| Repo | https://hub.docker.com/repository/create | `gh repo create mygithubuser/everything-wine` |
| Tag   | `docker tag everything-wine:latest mydockeruser/everything-wine:latest` | `docker tag everything-wine:latest ghcr.io/mygithubuser/everything-wine:latest` |
| Login | `docker login` | `echo <TOKEN> \| docker login ghcr.io -u mygithubuser --password-stdin` |
| Push  | `docker push mydockeruser/everything-wine:latest` | `docker push ghcr.io/mygithubuser/everything-wine:latest` |

## Credits
- [Everything Search](https://www.voidtools.com/)
- [Wine](https://www.winehq.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://tigervnc.org/) 