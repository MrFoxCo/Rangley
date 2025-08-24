# ---- build ----
FROM public.ecr.aws/docker/library/swift:6.0-jammy AS builder
WORKDIR /app
COPY . .
RUN swift build -c release --static-swift-stdlib

# ---- run ----
FROM public.ecr.aws/docker/library/ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates libatomic1 libxml2 zlib1g libssl3 curl && \
    rm -rf /var/lib/apt/lists/*

# Amazon RDS trust bundle for Postgres TLS
ADD https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem /etc/ssl/certs/rds-global-bundle.pem

WORKDIR /run
COPY --from=builder /app/.build/release/Run /run/Run

ENV PORT=8080
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD curl -fsS http://127.0.0.1:8080/health || exit 1

CMD ["/run/Run"]
