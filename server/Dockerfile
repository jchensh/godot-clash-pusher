# Multi-stage build for V4 server binaries.
# V4-S0c: builds all 4 cmd binaries into a single Alpine image.
# Each docker-compose service picks one binary via `command:`.

# -------- Build stage --------
FROM golang:1.23-alpine AS builder

WORKDIR /src

# Use China-friendly Go module proxy by default (proxy.golang.org is unreachable from CN).
# Override at build time via --build-arg GOPROXY=... if you're outside CN.
ARG GOPROXY=https://goproxy.cn,direct
ENV GOPROXY=${GOPROXY}

# Cache module deps first.
COPY go.mod go.sum ./
RUN go mod download

# Build all 4 cmd binaries.
COPY . .
RUN CGO_ENABLED=0 GOOS=linux \
 && go build -trimpath -ldflags="-s -w" -o /out/gateway ./cmd/gateway \
 && go build -trimpath -ldflags="-s -w" -o /out/api     ./cmd/api \
 && go build -trimpath -ldflags="-s -w" -o /out/battle  ./cmd/battle \
 && go build -trimpath -ldflags="-s -w" -o /out/migrate ./cmd/migrate

# -------- Runtime stage --------
FROM alpine:3.20

# CA certs for TLS to PG/Redis if remote, tzdata for log timestamps.
RUN apk add --no-cache ca-certificates tzdata

COPY --from=builder /out/gateway /usr/local/bin/gateway
COPY --from=builder /out/api     /usr/local/bin/api
COPY --from=builder /out/battle  /usr/local/bin/battle
COPY --from=builder /out/migrate /usr/local/bin/migrate

# Default to gateway; compose services override via `command:`.
CMD ["/usr/local/bin/gateway"]
