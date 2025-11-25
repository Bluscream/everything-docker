ARG DEBIAN_VERSION=debian-11-v4
FROM jlesage/baseimage-gui:${DEBIAN_VERSION}

ARG DEBIAN_VERSION=Debian-11

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
RUN set-cont-env APP_VERSION 1.4.1.1024

# Default resolution, change if you like
ENV DISPLAY_WIDTH=1280
ENV DISPLAY_HEIGHT=720

# Use a secure connection to the GUI
ENV SECURE_CONNECTION=1

# Clean tmp on startup
ENV CLEAN_TMP_DIR=1

# Install packages needed for app
# Enable multiarch and install Wine (needed for both x64 and x86 executables)
RUN dpkg --add-architecture i386 && \
    add-pkg wine wine32 xterm python3 python3-websockify git xvfb

#########################################
##    REPOSITORIES AND DEPENDENCIES    ##
#########################################

# Copy all Everything files (all architectures included) to image source location
COPY opt/everything/ /opt/everything-image/

# Set default executable to x64 (can be overridden at runtime)
RUN if [ -f /opt/everything-image/everything-1.5_x64.exe ]; then \
        cp /opt/everything-image/everything-1.5_x64.exe /opt/everything-image/Everything.exe; \
    elif [ -f /opt/everything-image/es_x64.exe ]; then \
        cp /opt/everything-image/es_x64.exe /opt/everything-image/Everything.exe; \
    fi

# Copy X app start script to correct location
COPY --chmod=777 startapp.sh /startapp.sh

# Add everything init script
COPY --chmod=777 everything.sh /etc/cont-init.d/90-everything.sh

# Copy default Everything configuration templates
COPY opt/everything/Everything-1.5a.ini /opt/everything-defaults/Everything.ini
COPY opt/everything/Plugins-1.5a.ini /opt/everything-defaults/plugins.ini

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################

# Place whatever volumes and ports you want exposed here:
VOLUME ["/config"]
