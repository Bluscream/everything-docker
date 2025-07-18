FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    wine64 \
    wget \
    unzip \
    fluxbox \
    tigervnc-standalone-server \
    tigervnc-common \
    xterm \
    python3 \
    python3-websockify \
    git \
    xvfb \
    && rm -rf /var/lib/apt/lists/*

# Install noVNC
RUN git clone https://github.com/novnc/noVNC.git /opt/novnc && \
    git clone https://github.com/novnc/websockify /opt/novnc/utils/websockify

# Download Everything portable
RUN wget -O /tmp/Everything.zip "https://www.voidtools.com/Everything-1.4.1.1024.x64.zip" && \
    unzip /tmp/Everything.zip -d /opt/everything && \
    rm /tmp/Everything.zip

# Create Plugins directory
RUN mkdir -p /opt/everything/Plugins

# Download Everything HTTP Server
RUN wget -O /tmp/Everything-HTTP-Server.zip "https://www.voidtools.com/Everything-HTTP-Server-1.0.3.4.x64.zip" && \
    unzip /tmp/Everything-HTTP-Server.zip -d /opt/everything/Plugins && \
    rm /tmp/Everything-HTTP-Server.zip

# Download Everything ETP Server
RUN wget -O /tmp/Everything-ETP-Server.zip "https://www.voidtools.com/Everything-ETP-Server-1.0.1.4.x64.zip" && \
    unzip /tmp/Everything-ETP-Server.zip -d /opt/everything/Plugins && \
    rm /tmp/Everything-ETP-Server.zip

# Create a script to start all services
RUN echo '#!/bin/bash\n\n# Start fluxbox\nfluxbox &\n\n# Start VNC server\nvncserver :1 -geometry 1280x800 -depth 24\n\n# Start noVNC\n/opt/novnc/utils/novnc_proxy --vnc localhost:5901 --listen 80 &\n\n# Start Everything HTTP Server via Wine\nexport DISPLAY=:1\nwine /opt/everything/Everything-HTTP-Server.exe &\n\n# Start Everything via Wine\nwine /opt/everything/Everything.exe\n' > /start.sh && chmod +x /start.sh

EXPOSE 80 8080 14630 21

CMD ["/start.sh"] 