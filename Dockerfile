# Solana Donation Contract - Development Dockerfile
# Multi-stage build for optimal image size

# Stage 1: Builder
FROM rust:1.75-slim as builder

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    pkg-config \
    libssl-dev \
    libudev-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Solana
ENV SOLANA_VERSION=1.18.0
RUN sh -c "$(curl -sSfL https://release.solana.com/v${SOLANA_VERSION}/install)" && \
    echo 'export PATH="/root/.local/share/solana/install/active_release/bin:$PATH"' >> /root/.bashrc

ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# Install Anchor
ENV ANCHOR_VERSION=0.30.1
RUN cargo install --git https://github.com/coral-xyz/anchor --tag v${ANCHOR_VERSION} anchor-cli --locked

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Build the program
RUN anchor build

# Stage 2: Runtime
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js
RUN curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y nodejs

# Install Solana CLI
ENV SOLANA_VERSION=1.18.0
RUN sh -c "$(curl -sSfL https://release.solana.com/v${SOLANA_VERSION}/install)"

ENV PATH="/root/.local/share/solana/install/active_release/bin:${PATH}"

# Copy built artifacts from builder
WORKDIR /app
COPY --from=builder /app/target/deploy /app/target/deploy
COPY --from=builder /app/target/idl /app/target/idl
COPY --from=builder /app/target/types /app/target/types
COPY --from=builder /root/.cargo/bin/anchor /usr/local/bin/anchor

# Copy project files
COPY package*.json ./
COPY Anchor.toml ./
COPY tests ./tests
COPY programs ./programs

# Install Node dependencies
RUN npm install

# Set Solana config
RUN solana config set --url localhost

# Expose ports
EXPOSE 8899 8900 9900

# Default command
CMD ["bash"]
