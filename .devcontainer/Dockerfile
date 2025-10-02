FROM ghcr.io/cirruslabs/flutter:3.27.1

# Instalar dependencias adicionales (opcional)
RUN apt-get update && apt-get install -y \
    curl git unzip xz-utils zip libglu1-mesa \
    cmake ninja-build libgtk-3-dev \
    android-tools-adb \
    && rm -rf /var/lib/apt/lists/*