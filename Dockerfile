ARG DEBIAN_VERSION=debian-11-v4
FROM jlesage/baseimage-gui:${DEBIAN_VERSION}

ARG DEBIAN_VERSION=Debian-11

ARG EVERYTHING_VERSION=1.4.1.1024
ARG EVERYTHING_ARCH=x64

ARG EVERYTHING_HTTP_USE=0
ARG EVERYTHING_HTTP_VERSION=1.0.3.4

ARG EVERYTHING_ETP_USE=0
ARG EVERYTHING_ETP_VERSION=1.0.1.4

ARG EVERYTHING_SERVER_USE=0
ARG EVERYTHING_SERVER_VERSION=1.0.1.2

MAINTAINER bluscream

#########################################
##        ENVIRONMENTAL CONFIG         ##
#########################################

# User/Group Id gui app will be executed as default are 99 and 100
ENV USER_ID=99
ENV GROUP_ID=100

ENV UMASK=000

# Gui App Name default is "GUI_APPLICATION"
RUN set-cont-env APP_NAME "Everything"
RUN set-cont-env APP_VERSION $EVERYTHING_VERSION

# Default resolution, change if you like
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720

# Use a secure connection to the GUI
ENV SECURE_CONNECTION 0

# Clean tmp on startup
ENV CLEAN_TMP_DIR 1

# Enable multiarch and install packages needed for app
RUN \
    if [ "${EVERYTHING_ARCH}" = "x86" ]; then \
        dpkg --add-architecture i386 && \
        add-pkg wine wine32 wget unzip xterm python3 python3-websockify git xvfb; \
    else \
        add-pkg wine wget unzip xterm python3 python3-websockify git xvfb; \
    fi

RUN dpkg --add-architecture i386 && apt-get update -y && apt-get install wine32 -y

#########################################
##    REPOSITORIES AND DEPENDENCIES    ##
#########################################

# Create Plugins directory
RUN mkdir -p /opt/everything/Plugins

# Download Everything portable
RUN \
    add-pkg --virtual build-dependencies \
        wget ca-certificates && \
    wget -O /tmp/Everything.zip "https://www.voidtools.com/Everything-${EVERYTHING_VERSION}.${EVERYTHING_ARCH}.zip" && \
    unzip /tmp/Everything.zip -d /opt/everything && \
    rm /tmp/Everything.zip && \
    del-pkg build-dependencies

# Download Everything HTTP Server if enabled
RUN if [ "${EVERYTHING_HTTP_USE}" = "1" ]; then \
    add-pkg --virtual build-dependencies \
        wget ca-certificates && \
    wget -O /tmp/Everything-HTTP-Server.zip "https://www.voidtools.com/Everything-HTTP-Server-${EVERYTHING_HTTP_VERSION}.${EVERYTHING_ARCH}.zip" && \
    unzip /tmp/Everything-HTTP-Server.zip -d /opt/everything/Plugins && \
    rm /tmp/Everything-HTTP-Server.zip && \
    del-pkg build-dependencies; \
    fi

# Download Everything ETP Server if enabled
RUN if [ "${EVERYTHING_ETP_USE}" = "1" ]; then \
    add-pkg --virtual build-dependencies \
        wget ca-certificates && \
    wget -O /tmp/Everything-ETP-Server.zip "https://www.voidtools.com/Everything-ETP-Server-${EVERYTHING_ETP_VERSION}.${EVERYTHING_ARCH}.zip" && \
    unzip /tmp/Everything-ETP-Server.zip -d /opt/everything/Plugins && \
    rm /tmp/Everything-ETP-Server.zip && \
    del-pkg build-dependencies; \
    fi

# Download Everything Server if enabled
RUN if [ "${EVERYTHING_SERVER_USE}" = "1" ]; then \
    add-pkg --virtual build-dependencies \
        wget ca-certificates && \
    wget -O /tmp/Everything-Server.zip "https://www.voidtools.com/Everything-Server-${EVERYTHING_SERVER_VERSION}.${EVERYTHING_ARCH}.zip" && \
    unzip /tmp/Everything-Server.zip -d /opt/everything/Plugins && \
    rm /tmp/Everything-Server.zip && \
    del-pkg build-dependencies; \
    fi

# Copy X app start script to correct location
COPY --chmod=777 startapp.sh /startapp.sh

# Add everything init script
COPY --chmod=777 everything.sh /etc/cont-init.d/90-everything.sh

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################

# Place whatever volumes and ports you want exposed here:
VOLUME ["/config"]
VOLUME ["/cache"] 