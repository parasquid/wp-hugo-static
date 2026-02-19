# Dockerfile.builder - Build container with all tools for wp-hugo-static
# Replaces the simple ruby:3.4-slim image
#
# Usage in docker-compose.yml:
#   builder:
#     build:
#       context: .
#       dockerfile: Dockerfile.builder
#     container_name: wp-builder
#     volumes:
#       - .:/app
#       - builder-gems:/usr/local/bundle
#     env_file:
#       - .env
#     profiles:
#       - dev
#     command: tail -f /dev/null

FROM ruby:3.4-slim

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV RUBY_VERSION=3.4

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    wget \
    ca-certificates \
    gnupg \
    && rm -rf /var/lib/apt/lists/*

# Install Hugo (extended version for SCSS support)
# Using official binary releases
ENV HUGO_VERSION=0.131.0
RUN wget -O /tmp/hugo.tar.gz "https://github.com/gohugoio/hugo/releases/download/v${HUGO_VERSION}/hugo_extended_${HUGO_VERSION}_linux-amd64.tar.gz" \
    && tar -xzf /tmp/hugo.tar.gz -C /tmp \
    && mv /tmp/hugo /usr/local/bin/hugo \
    && chmod +x /usr/local/bin/hugo \
    && rm -f /tmp/hugo.tar.gz

# Install Go (required for Hugo modules)
ENV GO_VERSION=1.24.4
RUN wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"
ENV GOPATH="/go"
ENV GO111MODULE="on"

# Install Ruby dependencies and image processing tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    ruby-dev \
    build-essential \
    libxml2-dev \
    libcurl4-openssl-dev \
    imagemagick \
    libmagickwand-dev \
    webp \
    libavif-bin \
    jpegoptim \
    optipng \
    pngquant \
    && rm -rf /var/lib/apt/lists/*

# Set up bundler
WORKDIR /app
RUN mkdir -p /app/vendor/bundle

# Default command - keep container running for exec
CMD ["tail", "-f", "/dev/null"]