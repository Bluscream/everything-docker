# Everything Search Docker Container

This project runs the Everything Search software (Windows-only) inside a Docker container using Wine, and exposes the UI via a web-accessible VNC server (noVNC), similar to Unraid containers.

## Features
- Everything Search (Windows version) via Wine
- Lightweight window manager (fluxbox)
- TigerVNC server
- noVNC for browser-based access

## Usage

### 1. Build and Start the Container

```sh
docker-compose up --build
```

### 2. Access the UI

Open your browser and go to:

```
http://localhost/
```

You will see the Windows Everything Search UI running inside the container.

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

## Customization
- To change the VNC or web port, edit the `docker-compose.yml` file.
- The Everything Search version can be updated by changing the download URL in the Dockerfile.

## Notes
- This container uses Wine to run Everything Search, which is a Windows application.
- The UI is accessible via any modern web browser using noVNC.
- Data is not persisted by default. For persistent settings or databases, mount a volume to `/opt/everything`.

## Credits
- [Everything Search](https://www.voidtools.com/)
- [Wine](https://www.winehq.org/)
- [noVNC](https://github.com/novnc/noVNC)
- [TigerVNC](https://tigervnc.org/) 