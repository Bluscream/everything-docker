FROM ubuntu:focal

# Enable multi-architecture support
RUN dpkg --add-architecture i386

# Install dependencies
RUN apt-get update && \
    apt-get install -y \
        wine-stable \
        winetricks \
        wget \
        cabextract \
        zenity \
        xvfb \
        fonts-wine \
        ttf-mscorefonts-installer \
        libwine:i386 \
        libwine-dbg:i386 \
        wine32 \
        wine64 \
        fonts-liberation \
        libvulkan1 \
        libvulkan1:i386 \
        libgbm1 \
        libgbm1:i386 \
        libgl1-mesa-glx \
        libgl1-mesa-glx:i386 \
        libegl1-mesa \
        libegl1-mesa:i386 \
        libxi6 \
        libxi6:i386 \
        libglib2.0-0 \
        libglib2.0-0:i386 \
        libsm6 \
        libsm6:i386 \
        libxinerama1 \
        libxinerama1:i386 \
        libxrandr2 \
        libxrandr2:i386 \
        libxcursor1 \
        libxcursor1:i386 \
        libxcomposite1 \
        libxcomposite1:i386 \
        libxfixes3 \
        libxfixes3:i386 \
        libxdamage1 \
        libxdamage1:i386 \
        libxext6 \
        libxext6:i386 \
        libxxf86vm1 \
        libxxf86vm1:i386 \
    && apt-get clean

# Set up Wine prefix
ENV WINEARCH=win64
ENV WINEPREFIX=/app/.everything
ENV HOME=/app

# Create directories
RUN mkdir -p ${WINEPREFIX}/drive_c/app/everything \
                ${WINEPREFIX}/dosdevices/c \
                ${WINEPREFIX}/dosdevices/z

# Link drives
RUN ln -sf /app ${WINEPREFIX}/dosdevices/z \
    && ln -sf /app/everything ${WINEPREFIX}/dosdevices/c/drive_c/app/everything

# Download Everything
WORKDIR /tmp
RUN wget https://www.voidtools.com/downloads/everything-1.4.1.1005.x64-setup.exe \
    && wine everything-1.4.1.1005.x64-setup.exe /S /D=C:\\everything

# Configure Everything
RUN [ "${WINEDEBUG}" = "" ] || export WINEDEBUG=-fixme-all \
    && wine C:\\everything\\Everything.exe -config \
    && echo "[Options]" > ${WINEPREFIX}/drive_c/everything/Everything.ini \
    && echo "db_location=z:" >> ${WINEPREFIX}/drive_c/everything/Everything.ini \
    && echo "start_minimized=true" >> ${WINEPREFIX}/drive_c/everything/Everything.ini \
    && echo "start_with_windows=false" >> ${WINEPREFIX}/drive_c/everything/Everything.ini

# Cleanup
RUN rm -rf /tmp/*

# Expose port for Everything service
EXPOSE 6373

# Start command
CMD ["wine", "C:\\everything\\Everything.exe"]