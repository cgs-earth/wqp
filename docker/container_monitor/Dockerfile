FROM golang:1.23 as builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . ./

ENV CGO_ENABLED=0
RUN go build -o slack-container-monitor

FROM debian:bullseye-slim

WORKDIR /app

# Install CA certificates. We need these to make HTTPS requests to the Slack API
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/slack-container-monitor ./

CMD ["/app/slack-container-monitor"]
