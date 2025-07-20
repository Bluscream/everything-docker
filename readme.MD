# Everything Search Docker Container

This project runs the Everything Search software (Windows-only) inside a Docker container using Wine, and exposes the UI via a web-accessible VNC server (noVNC), similar to Unraid containers.

## Features
- Everything Search (Windows version) via Wine
- Configurable architecture (x86/x64)
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
http://localhost:8080
```

This exposes the Everything HTTP Server web interface, which allows you to search and interact with Everything via HTTP requests.

### 4. Everything Server and ETP Server Ports

- Everything Server: `14630` (default)
- ETP Server: `21` (default)

If you enable or start these servers from the VNC desktop, they will be accessible on these ports.

## Configuration

### Architecture Selection

You can choose between 32-bit (x86) and 64-bit (x64) versions of Everything:

1. **Edit the `config.env` file**:
   ```bash
   # For 32-bit version (default)
   EVERYTHING_ARCH=x86
   
   # For 64-bit version
   EVERYTHING_ARCH=x64
   ```

2. **Or set the environment variable directly**:
   ```bash
   # For 32-bit version
   docker-compose build --build-arg EVERYTHING_ARCH=x86
   
   # For 64-bit version
   docker-compose build --build-arg EVERYTHING_ARCH=x64
   ```

3. **Or use the convenience scripts**:
   ```bash
   # Linux/Mac
   ./switch-arch.sh x86    # or ./switch-arch.sh 32
   ./switch-arch.sh x64    # or ./switch-arch.sh 64
   
   # Windows
   switch-arch.bat x86     # or switch-arch.bat 32
   switch-arch.bat x64     # or switch-arch.bat 64
   ```

### Other Customization
- To change the VNC or web port, edit the `docker-compose.yml` file.
- The Everything Search version can be updated by changing the `EVERYTHING_VERSION` build argument in the Dockerfile.

## Notes
- This container uses Wine to run Everything Search, which is a Windows application.
- The UI is accessible via any modern web browser using noVNC.
- Data is not persisted by default. For persistent settings or databases, mount a volume to `/opt/everything`.

## Development

| Step  | Docker Hub | GHCR |
|-------|--------------------|--------------|
| Build | `docker build -t everything-wine:latest .` | `docker build -t everything-wine:latest .` |
| Repo | https://hub.docker.com/repository/create | `gh repo create mygithubuser/everything-win` |
| Tag   | `docker tag everything-wine:latest mydockeruser/everything-wine:latest` | `docker tag everything-wine:latest ghcr.io/mygithubuser/everything-wine:latest` |
| Login | `docker login` | `echo <TOKEN> \| docker login ghcr.io -u mygithubuser --password-stdin` |
| Push  | `docker push mydockeruser/everything-wine:latest` | `docker push ghcr.io/mygithubuser/everything-wine:latest` |

## Credits
- [Everything Search](https://www.voidtools.com/)
- [Wine](https://www.winehq.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://tigervnc.org/) 