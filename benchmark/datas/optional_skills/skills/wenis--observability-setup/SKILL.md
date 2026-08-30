---
name: observability-setup
description: Sets up production-ready observability stack with structured logging (JSON format), metrics collection (Prometheus), distributed tracing (OpenTelemetry/Jaeger), and alerting (Grafana/PagerDuty). Implements instrumentation for Python/Node.js/Go applications, creates Grafana dashboards with key metrics, sets up log aggregation (ELK/Loki), and configures alert rules. Use when deploying to production, debugging distributed systems, monitoring performance, implementing SLOs/SLIs, or setting up on-call alerting.
allowed-tools: Read, Write, Edit, Bash
---

# Observability Setup

You implement comprehensive observability (logs, metrics, traces, errors) to ensure production systems are visible, debuggable, and maintainable.

## When to use
- Setting up a new production service
- Investigating production issues
- Implementing SRE best practices
- Adding monitoring to existing services
- Preparing for scale/growth
- Improving incident response time

## The Three Pillars of Observability

### 1. Logs (What happened?)
Timestamped records of events. Use for debugging specific issues and audit trails.

### 2. Metrics (How much/how many?)
Numerical measurements over time. Use for dashboards, alerts, and capacity planning.

### 3. Traces (Where did time go?)
Request flow through distributed systems. Use for performance debugging and understanding dependencies.

**Plus:** Error tracking and alerting for proactive issue detection.

## Tech Stack Recommendations

### All-in-One Solutions (Easiest)
- **Datadog**: Complete platform, great UX, ~$15-$31/host/month
- **New Relic**: Full-stack observability with AI insights, ~$25-$99/user/month
- **Elastic (ELK)**: Self-hosted, powerful but complex

### Open Source Stack (Recommended for Startups)
- **Logs**: Loki (lightweight, Prometheus-style)
- **Metrics**: Prometheus + Grafana
- **Traces**: Tempo or Jaeger
- **Errors**: Sentry (free tier available)
- **Dashboards**: Grafana

**Pros:** Free, flexible, vendor-independent
**Cons:** Requires setup and maintenance

### Minimum Viable Stack
- **Logs**: CloudWatch Logs / Stackdriver
- **Metrics**: CloudWatch / Cloud Monitoring
- **Errors**: Sentry
- **Dashboards**: Grafana Cloud (free tier)

## Quick Start: Python Example

Here's a minimal structured logging setup with Python:

```python
# logging_config.py
import structlog
import logging

def setup_logging():
    logging.basicConfig(format="%(message)s", level=logging.INFO)

    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.processors.TimeStamper(fmt="iso"),
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

# Structured logging with context
logger.info(
    "user_login",
    user_id=user.id,
    email=user.email,
    ip_address=request.ip
)

# Bind context for multiple log statements
logger = logger.bind(request_id=request_id, user_id=user_id)
logger.info("processing_payment", amount=100.00, currency="USD")
logger.error("payment_failed", error=str(e))
```

## Language-Specific Implementation Guides

For complete implementation examples including logging, metrics, tracing, and error tracking:

- **Python**: See `examples/python-setup.md`
  - structlog for logging
  - prometheus_client for metrics
  - OpenTelemetry for tracing
  - Sentry for error tracking

- **Node.js/TypeScript**: See `examples/nodejs-setup.md`
  - Pino for logging
  - prom-client for metrics
  - OpenTelemetry for tracing
  - Sentry for error tracking

- **Go**: See `examples/go-setup.md`
  - zerolog for logging
  - prometheus/client_golang for metrics
  - OpenTelemetry for tracing

## Infrastructure Setup

Ready-to-use configuration templates:

- **Complete stack**: `templates/docker-compose.yml`
  - Prometheus, Grafana, Loki, Tempo all configured
  - Just run `docker-compose up -d`

- **Prometheus config**: `templates/prometheus.yml`
  - Scrape configuration for your services

- **Alerts**: `templates/alertmanager.yml`
  - Pre-configured alerts for high error rate, latency, downtime
  - Slack integration ready

- **Dashboards**: `reference/grafana-dashboards.md`
  - Sample dashboard JSON
  - Common PromQL queries

## Complete Setup Checklist

### Application Code
- [ ] Add structured logging (JSON format)
- [ ] Instrument metrics (requests, latency, errors)
- [ ] Add distributed tracing
- [ ] Integrate error tracking (Sentry)
- [ ] Add health check endpoint
- [ ] Add metrics endpoint (/metrics)

### Infrastructure
- [ ] Deploy Prometheus for metrics
- [ ] Deploy Grafana for dashboards
- [ ] Deploy Loki for logs (or use CloudWatch)
- [ ] Deploy Tempo/Jaeger for traces
- [ ] Set up AlertManager
- [ ] Configure log aggregation

### Dashboards
- [ ] Request rate
- [ ] Error rate
- [ ] Latency (P50, P95, P99)
- [ ] Resource usage (CPU, memory)
- [ ] Database performance
- [ ] Business metrics (signups, purchases, etc.)

### Alerts
- [ ] High error rate (> 5%)
- [ ] High latency (P95 > 1s)
- [ ] Service down
- [ ] High memory usage (> 80%)
- [ ] Database connection pool exhausted

## Best Practices

✅ **DO:**
- Use structured logging (JSON)
- Include request IDs in all logs for correlation
- Sample traces (10-30%) to reduce overhead
- Create dashboards for your SLIs (Service Level Indicators)
- Alert on symptoms, not causes
- Set up on-call rotation
- Review dashboards regularly
- Use consistent metric naming conventions
- Add units to metric names (seconds, bytes, etc.)
- Set appropriate retention periods

❌ **DON'T:**
- Log sensitive data (passwords, tokens, PII)
- Trace 100% of requests (too expensive)
- Create alerts that fire constantly
- Alert on metrics you can't act on
- Ignore alert fatigue
- Log excessively (DEBUG in production)
- Use string formatting in log messages
- Hardcode thresholds without testing

## Key Metrics to Track

### Golden Signals (SRE)
1. **Latency**: How long requests take
2. **Traffic**: How much demand on your system
3. **Errors**: Rate of failed requests
4. **Saturation**: How "full" your service is

### Application Metrics
- Request rate (requests/second)
- Error rate (errors/second, percentage)
- Response time (P50, P95, P99)
- Active connections
- Queue depth
- Cache hit rate

### System Metrics
- CPU usage
- Memory usage
- Disk I/O
- Network I/O
- File descriptors
- Thread/goroutine count

### Business Metrics
- User signups
- Successful transactions
- Revenue
- Active users
- Feature usage

## Instructions

1. **Choose your stack**
   - All-in-one (Datadog/New Relic) vs open source (Prometheus + Grafana)
   - Consider budget, team size, and infrastructure preferences

2. **Implement logging**
   - Pick language-specific logging library from examples/
   - Configure JSON output for structured logs
   - Add request ID middleware for correlation

3. **Add metrics**
   - Instrument HTTP handlers (request count, duration, errors)
   - Add business metrics (signups, purchases, etc.)
   - Expose `/metrics` endpoint for Prometheus

4. **Set up tracing**
   - Use OpenTelemetry auto-instrumentation when possible
   - Add manual spans for critical paths
   - Configure sampling (10-30%)

5. **Integrate error tracking**
   - Set up Sentry or equivalent
   - Configure environment (dev/staging/prod)
   - Add user context to errors

6. **Deploy infrastructure**
   - Use `templates/docker-compose.yml` for local/small deployments
   - Or use cloud-managed services (CloudWatch, Cloud Monitoring)
   - Configure retention periods

7. **Create dashboards**
   - Start with golden signals (latency, traffic, errors, saturation)
   - Add application-specific metrics
   - Use `reference/grafana-dashboards.md` for examples

8. **Configure alerts**
   - Use `templates/alertmanager.yml` as starting point
   - Set thresholds based on your SLOs
   - Route to Slack/PagerDuty/email

9. **Test everything**
   - Generate load, verify metrics appear
   - Trigger errors, verify alerts fire
   - Check trace visualization
   - Ensure logs are searchable

10. **Document runbooks**
    - Create guides for common alerts
    - Document dashboard usage
    - Train team on debugging with observability tools

## Constraints

- Must not log sensitive data (PII, passwords, API keys, tokens)
- Metrics endpoint must not require auth (for Prometheus scraping)
- Tracing overhead must be < 5% (use sampling, typically 10-30%)
- Logs must be structured (JSON format)
- Must include request IDs for log correlation
- Dashboards must load in < 3 seconds
- Alert fatigue must be avoided (tune thresholds carefully)
- Must comply with data retention policies (GDPR, etc.)
- Metric cardinality must be controlled (avoid unbounded labels)
- Observability infrastructure must be reliable (monitor the monitors)
