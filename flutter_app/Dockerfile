# Stage 1: Build the Flutter Web App
FROM debian:bookworm-slim AS build-env

# Install dependencies for Flutter
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Clone Flutter SDK
ENV FLUTTER_CHANNEL=stable
ENV FLUTTER_VERSION=3.27.1
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter -b ${FLUTTER_CHANNEL}

# Set flutter path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Enable web support
RUN flutter config --enable-web

# Run flutter doctor to ensure everything is set up
RUN flutter doctor

# Copy the app files
WORKDIR /app
COPY . .

# Get dependencies
RUN flutter pub get

# Build the web app
RUN flutter build web --release

# Stage 2: Serve the App with Nginx
FROM nginx:alpine

# Copy the build artifacts from the build stage
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose port (Nginx defaults to 80)
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
