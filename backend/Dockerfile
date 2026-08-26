FROM dhi.io/golang:1-alpine AS builder

WORKDIR /app

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -ldflags="-w -s" -o devboard-backend .

FROM dhi.io/alpine-base:3.22

WORKDIR /app

COPY --chown=nonroot:nonroot --from=builder /app/devboard-backend ./devboard-backend
RUN chmod 550 ./devboard-backend

USER nonroot

EXPOSE 8080

ENTRYPOINT ["./devboard-backend"]
