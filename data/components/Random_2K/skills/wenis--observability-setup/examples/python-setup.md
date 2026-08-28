# Python Observability Setup

Complete implementation guide for observability in Python applications.

## Structured Logging with structlog

```python
# logging_config.py
import structlog
import logging

def setup_logging():
    logging.basicConfig(
        format="%(message)s",
        level=logging.INFO,
    )

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        context_class=dict,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )

# Usage
import structlog

logger = structlog.get_logger()

# Structured logging
logger.info(
    "user_login",
    user_id=user.id,
    email=user.email,
    ip_address=request.ip,
    user_agent=request.headers.get("User-Agent")
)

# With context
logger = logger.bind(request_id=request_id, user_id=user_id)
logger.info("processing_payment", amount=100.00, currency="USD")
logger.error("payment_failed", error=str(e), amount=100.00)
```

## Metrics with Prometheus

```python
# metrics.py
from prometheus_client import Counter, Histogram, Gauge, start_http_server
import time

# Define metrics
http_requests_total = Counter(
    'http_requests_total',
    'Total HTTP requests',
    ['method', 'endpoint', 'status']
)

http_request_duration_seconds = Histogram(
    'http_request_duration_seconds',
    'HTTP request duration',
    ['method', 'endpoint']
)

active_users = Gauge(
    'active_users',
    'Number of active users'
)

# Middleware
def track_request(method, endpoint):
    def decorator(func):
        def wrapper(*args, **kwargs):
            start = time.time()
            try:
                result = func(*args, **kwargs)
                status = 200
                return result
            except Exception as e:
                status = 500
                raise
            finally:
                duration = time.time() - start
                http_requests_total.labels(
                    method=method,
                    endpoint=endpoint,
                    status=status
                ).inc()
                http_request_duration_seconds.labels(
                    method=method,
                    endpoint=endpoint
                ).observe(duration)
        return wrapper
    return decorator

# Usage
@track_request('GET', '/api/users')
def get_users():
    # Handler logic
    return users

# Start metrics server
if __name__ == '__main__':
    start_http_server(8000)  # Metrics on :8000/metrics
```

## Distributed Tracing with OpenTelemetry

```python
# tracing.py
from opentelemetry import trace
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.sqlalchemy import SQLAlchemyInstrumentor

def setup_tracing(app, service_name="my-service"):
    # Set up tracer
    trace.set_tracer_provider(TracerProvider())
    tracer = trace.get_tracer(__name__)

    # Export to Tempo/Jaeger
    otlp_exporter = OTLPSpanExporter(
        endpoint="http://localhost:4317",
        insecure=True
    )
    span_processor = BatchSpanProcessor(otlp_exporter)
    trace.get_tracer_provider().add_span_processor(span_processor)

    # Auto-instrument FastAPI
    FastAPIInstrumentor.instrument_app(app)

    # Auto-instrument SQLAlchemy
    SQLAlchemyInstrumentor().instrument(engine=engine)

    return tracer

# Manual instrumentation
tracer = trace.get_tracer(__name__)

@tracer.start_as_current_span("process_order")
def process_order(order_id):
    span = trace.get_current_span()
    span.set_attribute("order.id", order_id)
    span.set_attribute("order.amount", order.amount)

    try:
        result = payment_service.charge(order)
        span.set_attribute("payment.status", "success")
        return result
    except Exception as e:
        span.set_status(Status(StatusCode.ERROR))
        span.record_exception(e)
        raise
```

## Error Tracking with Sentry

```python
# sentry_config.py
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from sentry_sdk.integrations.sqlalchemy import SqlalchemyIntegration

def setup_sentry(app):
    sentry_sdk.init(
        dsn=os.environ['SENTRY_DSN'],
        environment=os.environ.get('ENV', 'development'),
        traces_sample_rate=0.1,  # 10% of transactions traced
        profiles_sample_rate=0.1,
        integrations=[
            FastApiIntegration(),
            SqlalchemyIntegration(),
        ],
    )

# Usage - automatic for unhandled exceptions
# Manual error capture
from sentry_sdk import capture_exception, capture_message

try:
    risky_operation()
except Exception as e:
    capture_exception(e)
    # Also add context
    sentry_sdk.set_context("order", {
        "id": order.id,
        "amount": order.amount,
    })
    sentry_sdk.set_user({"id": user.id, "email": user.email})
    capture_exception(e)

# Breadcrumbs for debugging
sentry_sdk.add_breadcrumb(
    category='order',
    message='Order validation started',
    level='info',
)
```

## Complete Integration Example

```python
# app.py
from fastapi import FastAPI
from logging_config import setup_logging
from tracing import setup_tracing
from sentry_config import setup_sentry
from metrics import start_http_server
import structlog

app = FastAPI()

# Initialize observability
setup_logging()
setup_tracing(app, service_name="my-api")
setup_sentry(app)

# Start metrics server in background
import threading
threading.Thread(target=lambda: start_http_server(8000), daemon=True).start()

logger = structlog.get_logger()

@app.get("/api/users")
async def get_users():
    logger.info("fetching_users", endpoint="/api/users")
    # Handler logic
    return {"users": []}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
```

## Dependencies

```bash
pip install structlog prometheus-client opentelemetry-api opentelemetry-sdk \
    opentelemetry-instrumentation-fastapi opentelemetry-instrumentation-sqlalchemy \
    opentelemetry-exporter-otlp sentry-sdk
```
