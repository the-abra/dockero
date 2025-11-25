# Multi-stage build for Dockero
# This Dockerfile allows building and using Dockero in a container environment

# Build stage - if needed for compilation
FROM alpine:latest AS builder

# Install dependencies
RUN apk add --no-cache \
    bash \
    docker-cli \
    findutils \
    coreutils

# Copy Dockero source
WORKDIR /app
COPY . .

# Make scripts executable
RUN find /app/core -name "*.sh" -exec chmod +x {} \; && \
    chmod +x /app/install.sh && \
    chmod +x /app/test_commands.sh

# Production stage
FROM alpine:latest

# Install required packages
RUN apk add --no-cache \
    bash \
    docker-cli \
    curl \
    git \
    findutils \
    coreutils \
    tput

# Create non-root user
RUN addgroup -g 1000 dockero && \
    adduser -D -u 1000 -G dockero dockero

# Set up dockero directory
WORKDIR /app
COPY --from=builder --chown=dockero:dockero /app/core /app/core

# Create necessary directories
RUN mkdir -p /opt/dockero && \
    chown -R dockero:dockero /opt/dockero

# Install Dockero to PATH by copying instead of symlinking
RUN cp /app/core/dockero.sh /usr/local/bin/dockero && \
    chmod +x /usr/local/bin/dockero

# Switch to non-root user
USER dockero

# Default command
CMD ["bash"]