ARG DEBIAN_VERSION=debian-11-v4
FROM jlesage/baseimage-gui:${DEBIAN_VERSION}

ARG DEBIAN_VERSION=Debian-11
ARG TARGETARCH

LABEL maintainer="bluscream"

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################

# User/Group Id gui app will be executed as default are 99 and 100
ENV USER_ID=99
ENV GROUP_ID=100

ENV UMASK=000

# Gui App Name default is "GUI_APPLICATION"
RUN set-cont-env APP_NAME "Everything"
RUN set-cont-env APP_VERSION 1.5-alpha

# Default resolution, change if you like
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720

# Use a secure connection to the GUI
ENV SECURE_CONNECTION=1

# Clean tmp on startup (can be overridden via environment variable)
# Default to 1, but allow users to disable for debugging
ENV CLEAN_TMP_DIR=1

# Set Wine architecture based on target architecture
# TARGETARCH will be "amd64" or "386" (for i386)
# Determine Wine architecture and install packages, then set WINEARCH
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        dpkg --add-architecture i386 && \
        apt-get update && \
        add-pkg wine wine64 wine32 xterm python3 python3-websockify git xvfb && \
        echo "WINEARCH=win64" >> /etc/environment; \
    elif [ "$TARGETARCH" = "386" ]; then \
        apt-get update && \
        add-pkg wine xterm python3 python3-websockify git xvfb && \
        echo "WINEARCH=win32" >> /etc/environment; \
    else \
        echo "ERROR: Unsupported architecture: $TARGETARCH" && exit 1; \
    fi

# Set WINEARCH environment variable (default, will be overridden by /etc/environment)
# The actual value is set in /etc/environment above based on TARGETARCH
ENV WINEARCH=win64

#########################################
##    REPOSITORIES AND DEPENDENCIES    ##
#########################################

# Create everything user with home directory
RUN useradd -m -u 99 -g 100 -d /home/everything -s /bin/sh everything || true

# Create directory structure
RUN mkdir -p /home/everything/plugins /home/everything/html /home/everything/cfg /home/everything/.wine /home/everything/.config /config

# Copy all binaries first (we'll select the right ones later)
COPY image/bin/ /tmp/bin/

# Copy binaries and static files to /home/everything/
# Copy common files (html, chm, lng)
COPY image/bin/html/ /home/everything/html/
COPY image/bin/everything.chm /home/everything/everything.chm
COPY image/bin/everything.lng /home/everything/everything.lng

# Copy architecture-specific executables (without arch suffix)
# Use TARGETARCH to determine which binaries to copy
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        cp /tmp/bin/everything-1.4_x64.exe /home/everything/everything-1.4.exe && \
        cp /tmp/bin/everything-1.5_x64.exe /home/everything/everything-1.5.exe && \
        cp /tmp/bin/es_x64.exe /home/everything/es.exe && \
        cp /tmp/bin/voidimageviewer_x64.exe /home/everything/voidimageviewer.exe; \
    elif [ "$TARGETARCH" = "386" ]; then \
        cp /tmp/bin/everything-1.4_x86.exe /home/everything/everything-1.4.exe && \
        cp /tmp/bin/everything-1.5_x86.exe /home/everything/everything-1.5.exe && \
        cp /tmp/bin/es_x86.exe /home/everything/es.exe && \
        cp /tmp/bin/voidimageviewer_x86.exe /home/everything/voidimageviewer.exe; \
    fi

# Copy architecture-specific plugins (without arch suffix)
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        cp /tmp/bin/plugins/etp_server64.dll /home/everything/plugins/etp_server.dll && \
        cp /tmp/bin/plugins/everything_server64.dll /home/everything/plugins/everything_server.dll && \
        cp /tmp/bin/plugins/http_server64.dll /home/everything/plugins/http_server.dll; \
    elif [ "$TARGETARCH" = "386" ]; then \
        cp /tmp/bin/plugins/etp_server32.dll /home/everything/plugins/etp_server.dll && \
        cp /tmp/bin/plugins/everything_server32.dll /home/everything/plugins/everything_server.dll && \
        cp /tmp/bin/plugins/http_server32.dll /home/everything/plugins/http_server.dll; \
    fi

# Copy helper scripts
COPY image/bin/copy_unix_path.cmd /home/everything/copy_unix_path.cmd

# Copy default config files to image location (for first-time initialization)
# Store defaults in /opt/everything-defaults so we can copy them during init if volume is empty
RUN mkdir -p /opt/everything-defaults
COPY image/config/everything.ini /opt/everything-defaults/everything.ini
COPY image/config/Plugins-1.5a.ini /opt/everything-defaults/Plugins-1.5a.ini

# Copy all files to a persistent location that won't be overwritten by volume mounts
# This allows us to copy them to /home/everything on first run
RUN mkdir -p /opt/everything-files
COPY image/bin/html/ /opt/everything-files/html/
COPY image/bin/everything.chm /opt/everything-files/everything.chm
COPY image/bin/everything.lng /opt/everything-files/everything.lng
COPY image/config/Plugins-1.5a.ini /opt/everything-files/Plugins-1.5a.ini

# Copy architecture-specific files to /opt/everything-files
RUN if [ "$TARGETARCH" = "amd64" ]; then \
        cp /tmp/bin/everything-1.4_x64.exe /opt/everything-files/everything-1.4.exe && \
        cp /tmp/bin/everything-1.5_x64.exe /opt/everything-files/everything-1.5.exe && \
        cp /tmp/bin/es_x64.exe /opt/everything-files/es.exe && \
        cp /tmp/bin/voidimageviewer_x64.exe /opt/everything-files/voidimageviewer.exe && \
        mkdir -p /opt/everything-files/plugins && \
        cp /tmp/bin/plugins/etp_server64.dll /opt/everything-files/plugins/etp_server64.dll && \
        cp /tmp/bin/plugins/everything_server64.dll /opt/everything-files/plugins/everything_server64.dll && \
        cp /tmp/bin/plugins/http_server64.dll /opt/everything-files/plugins/http_server64.dll; \
    elif [ "$TARGETARCH" = "386" ]; then \
        cp /tmp/bin/everything-1.4_x86.exe /opt/everything-files/everything-1.4.exe && \
        cp /tmp/bin/everything-1.5_x86.exe /opt/everything-files/everything-1.5.exe && \
        cp /tmp/bin/es_x86.exe /opt/everything-files/es.exe && \
        cp /tmp/bin/voidimageviewer_x86.exe /opt/everything-files/voidimageviewer.exe && \
        mkdir -p /opt/everything-files/plugins && \
        cp /tmp/bin/plugins/etp_server32.dll /opt/everything-files/plugins/etp_server32.dll && \
        cp /tmp/bin/plugins/everything_server32.dll /opt/everything-files/plugins/everything_server32.dll && \
        cp /tmp/bin/plugins/http_server32.dll /opt/everything-files/plugins/http_server32.dll; \
    fi

COPY image/bin/copy_unix_path.cmd /opt/everything-files/copy_unix_path.cmd

# Clean up temporary files
RUN rm -rf /tmp/bin

# Copy X app start script to correct location
COPY --chmod=777 startapp.sh /startapp.sh

# Add everything init script
COPY --chmod=777 everything.sh /etc/cont-init.d/90-everything.sh

# Generate and install favicons from Everything Search logo
# The install_app_icon.sh script generates all necessary icon sizes and favicons
RUN \
    APP_ICON_URL=https://www.voidtools.com/e2.png && \
    install_app_icon.sh "$APP_ICON_URL"

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################

# Print all environment variables during build
RUN echo "Build-time environment variables:" && env | sort && \
    echo "Target architecture: $TARGETARCH" && \
    echo "Wine architecture: $WINEARCH"

# Place whatever volumes and ports you want exposed here:
VOLUME ["/home/everything"]
