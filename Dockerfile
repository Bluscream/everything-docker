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
RUN set-cont-env APP_VERSION 1.5-alpha

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
    add-pkg wine wine32 xterm python3 python3-websockify git xvfb jq

#########################################
##    REPOSITORIES AND DEPENDENCIES    ##
#########################################

# Copy all Everything files to temporary location (needed for mapping script to read)
COPY opt/everything/ /tmp/everything-source/

# Copy mapping script and apply mappings based on architecture
COPY --chmod=755 apply-mappings.sh /usr/local/bin/apply-mappings.sh

# Apply mappings to copy only files specified in mappings.json for this architecture
# This keeps the image smaller by excluding architecture-specific files not needed
ARG TARGETARCH=amd64
ARG BUILDPLATFORM=linux/amd64
RUN mkdir -p /opt/everything-image && \
    /usr/local/bin/apply-mappings.sh /tmp/everything-source /opt/everything-image "${TARGETARCH}" || \
    /usr/local/bin/apply-mappings.sh /tmp/everything-source /opt/everything-image "amd64" && \
    rm -rf /tmp/everything-source

# Copy X app start script to correct location
COPY --chmod=777 startapp.sh /startapp.sh

# Add everything init script
COPY --chmod=777 everything.sh /etc/cont-init.d/90-everything.sh

# Copy default Everything configuration templates directly (no need for separate defaults folder)
COPY opt/everything/Everything-1.5a.ini /opt/everything-defaults/Everything.ini
COPY opt/everything/Plugins-1.5a.ini /opt/everything-defaults/plugins.ini

#########################################
##         EXPORTS AND VOLUMES         ##
#########################################

# Place whatever volumes and ports you want exposed here:
VOLUME ["/config"]
