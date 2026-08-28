# Grafana Dashboard Configuration

## Creating Dashboards

Grafana dashboards visualize metrics from Prometheus and other data sources.

## Sample Dashboard JSON

```json
{
  "dashboard": {
    "title": "Application Metrics",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total[5m])"
          }
        ],
        "type": "graph"
      },
      {
        "title": "Error Rate",
        "targets": [
          {
            "expr": "rate(http_requests_total{status=~\"5..\"}[5m])"
          }
        ],
        "type": "graph"
      },
      {
        "title": "P95 Latency",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))"
          }
        ],
        "type": "graph"
      }
    ]
  }
}
```

## Common PromQL Queries

### Request Rate
```
rate(http_requests_total[5m])
```

### Error Rate
```
rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m])
```

### Latency Percentiles
```
# P50
histogram_quantile(0.50, rate(http_request_duration_seconds_bucket[5m]))

# P95
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))

# P99
histogram_quantile(0.99, rate(http_request_duration_seconds_bucket[5m]))
```

### CPU Usage
```
rate(process_cpu_seconds_total[5m])
```

### Memory Usage
```
process_resident_memory_bytes
```

## Dashboard Best Practices

1. **Golden Signals**: Include latency, traffic, errors, saturation
2. **Time ranges**: Default to last 1 hour, allow customization
3. **Refresh rate**: 30s-1m for production dashboards
4. **Thresholds**: Visual indicators for normal/warning/critical
5. **Variables**: Make dashboards reusable across services
6. **Legends**: Clear metric labels
7. **Units**: Always specify (ms, requests/s, %, bytes)

## Provisioning Dashboards

Place dashboard JSON files in `./grafana/provisioning/dashboards/` to auto-load them on startup.
