# Build stage
FROM rust:latest AS builder
ARG TARGETARCH

RUN apt-get update && apt-get install -y musl-tools && rm -rf /var/lib/apt/lists/*
RUN set -eux; \
    case "${TARGETARCH}" in \
        amd64) rust_target='x86_64-unknown-linux-musl' ;; \
        arm64) rust_target='aarch64-unknown-linux-musl' ;; \
        *) echo >&2 "ERROR: Unsupported TARGETARCH: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    rustup target add "${rust_target}"; \
    echo "${rust_target}" > /rust-target.txt

WORKDIR /app
COPY Cargo.toml Cargo.lock* ./
COPY src ./src

RUN set -eux; \
    rust_target="$(cat /rust-target.txt)"; \
    cargo build --release --target "${rust_target}"; \
    cp "target/${rust_target}/release/teleemix" /teleemix

# Docker CLI stage - grab just the docker binary
FROM docker:latest AS docker-cli

# Runtime stage
FROM scratch

# CA certificates for HTTPS
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

# Docker CLI for /updatearl rebuild trigger
COPY --from=docker-cli /usr/local/bin/docker /usr/local/bin/docker

# The bot binary
COPY --from=builder /teleemix /teleemix

CMD ["/teleemix"]
