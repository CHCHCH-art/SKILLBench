# Go Observability Setup

Complete implementation guide for observability in Go applications.

## Structured Logging with zerolog

```go
// logger.go
package main

import (
    "github.com/rs/zerolog"
    "github.com/rs/zerolog/log"
    "os"
)

func SetupLogger() {
    zerolog.TimeFieldFormat = zerolog.TimeFormatUnix

    if os.Getenv("ENV") == "development" {
        log.Logger = log.Output(zerolog.ConsoleWriter{Out: os.Stderr})
    }
}

// Usage
log.Info().
    Str("event", "user_login").
    Str("user_id", user.ID).
    Str("email", user.Email).
    Str("ip_address", r.RemoteAddr).
    Msg("User logged in")

log.Error().
    Err(err).
    Str("event", "payment_failed").
    Float64("amount", 100.00).
    Msg("Payment processing failed")
```

## Metrics with Prometheus

```go
// metrics.go
package main

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promhttp"
    "net/http"
)

var (
    httpRequestsTotal = prometheus.NewCounterVec(
        prometheus.CounterOpts{
            Name: "http_requests_total",
            Help: "Total HTTP requests",
        },
        []string{"method", "endpoint", "status"},
    )

    httpRequestDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name:    "http_request_duration_seconds",
            Help:    "HTTP request duration",
            Buckets: prometheus.DefBuckets,
        },
        []string{"method", "endpoint"},
    )
)

func init() {
    prometheus.MustRegister(httpRequestsTotal)
    prometheus.MustRegister(httpRequestDuration)
}

// Middleware
func metricsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()

        // Wrap response writer to capture status
        wrapped := &responseWriter{ResponseWriter: w, statusCode: http.StatusOK}
        next.ServeHTTP(wrapped, r)

        duration := time.Since(start).Seconds()
        httpRequestsTotal.WithLabelValues(r.Method, r.URL.Path, strconv.Itoa(wrapped.statusCode)).Inc()
        httpRequestDuration.WithLabelValues(r.Method, r.URL.Path).Observe(duration)
    })
}

// Metrics endpoint
http.Handle("/metrics", promhttp.Handler())
```

## Distributed Tracing with OpenTelemetry

```go
// tracing.go
package main

import (
    "context"
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc"
    "go.opentelemetry.io/otel/sdk/trace"
)

func SetupTracing(serviceName string) func() {
    ctx := context.Background()

    exporter, err := otlptracegrpc.New(ctx,
        otlptracegrpc.WithEndpoint("localhost:4317"),
        otlptracegrpc.WithInsecure(),
    )
    if err != nil {
        log.Fatal().Err(err).Msg("Failed to create exporter")
    }

    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String(serviceName),
        )),
    )

    otel.SetTracerProvider(tp)

    return func() {
        _ = tp.Shutdown(ctx)
    }
}

// Usage
func processOrder(ctx context.Context, orderID string) error {
    tracer := otel.Tracer("my-service")
    ctx, span := tracer.Start(ctx, "process_order")
    defer span.End()

    span.SetAttributes(attribute.String("order.id", orderID))

    // Business logic
    err := paymentService.Charge(ctx, order)
    if err != nil {
        span.RecordError(err)
        span.SetStatus(codes.Error, err.Error())
        return err
    }

    span.SetAttributes(attribute.String("payment.status", "success"))
    return nil
}
```

## Complete Integration Example

```go
// main.go
package main

import (
    "net/http"
    "github.com/rs/zerolog/log"
)

func main() {
    // Initialize observability
    SetupLogger()
    cleanup := SetupTracing("my-api")
    defer cleanup()

    // Add middleware
    mux := http.NewServeMux()
    mux.HandleFunc("/api/users", getUsersHandler)

    handler := metricsMiddleware(mux)

    log.Info().Msg("Starting server on :8080")
    http.ListenAndServe(":8080", handler)
}

func getUsersHandler(w http.ResponseWriter, r *http.Request) {
    ctx := r.Context()
    log.Info().Str("event", "fetching_users").Msg("Fetching users")

    // Handler logic
    w.Header().Set("Content-Type", "application/json")
    w.Write([]byte(`{"users": []}`))
}
```

## Dependencies

```bash
go get github.com/rs/zerolog
go get github.com/prometheus/client_golang/prometheus
go get go.opentelemetry.io/otel
go get go.opentelemetry.io/otel/exporters/otlp/otlptrace/otlptracegrpc
```
