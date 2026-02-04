# -----------------------------------------------------------------------------
# xTeVe Docker Image
#
# Builds a docker image for xTeVe M3U proxy server
# (https://xteve.de/)
#
# Multi-stage build for optimized image size
# -----------------------------------------------------------------------------

# First-stage build for xteve builder image
# -----------------------------------------------------------------------------
FROM golang:1.19-alpine AS builder

# Install build dependencies
RUN apk add --no-cache git ca-certificates tzdata

# Set working directory
WORKDIR /build

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the application
RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o xteve .

# -----------------------------------------------------------------------------
# Second-stage build for xteve runtime image
# -----------------------------------------------------------------------------
FROM alpine:latest

# Install runtime dependencies
RUN apk --no-cache add ca-certificates tzdata ffmpeg vlc

# Create non-root user
RUN addgroup -g 1001 -S xteve && \
    adduser -u 1001 -S xteve -G xteve

# Set environment variables
ENV XTEVE_HOME=/home/xteve
ENV XTEVE_PORT=34400
ENV XTEVE_TEMP=/tmp/xteve
ENV TZ=UTC

# Create necessary directories
RUN mkdir -p ${XTEVE_HOME} ${XTEVE_TEMP} && \
    chown -R xteve:xteve ${XTEVE_HOME} ${XTEVE_TEMP}

# Set working directory
WORKDIR ${XTEVE_HOME}

# Copy binary from builder stage
COPY --from=builder /build/xteve /usr/local/bin/xteve

# Copy static files
COPY --from=builder /build/html ./html

# Change ownership
RUN chown -R xteve:xteve /usr/local/bin/xteve ${XTEVE_HOME}

# Switch to non-root user
USER xteve

# Expose port
EXPOSE ${XTEVE_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost:${XTEVE_PORT}/ || exit 1

# Run the application
ENTRYPOINT ["/usr/local/bin/xteve"]
CMD ["-config", "/home/xteve"]