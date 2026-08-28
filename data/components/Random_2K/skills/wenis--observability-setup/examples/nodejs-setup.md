# Node.js/TypeScript Observability Setup

Complete implementation guide for observability in Node.js/TypeScript applications.

## Structured Logging with Pino

```typescript
// logger.ts
import pino from 'pino';

export const logger = pino({
  level: process.env.LOG_LEVEL || 'info',
  formatters: {
    level: (label) => ({ level: label }),
  },
  timestamp: pino.stdTimeFunctions.isoTime,
  ...(process.env.NODE_ENV === 'production'
    ? {}
    : { transport: { target: 'pino-pretty' } }),
});

// Usage
import { logger } from './logger';

logger.info({
  event: 'user_login',
  userId: user.id,
  email: user.email,
  ipAddress: req.ip,
}, 'User logged in');

logger.error({
  event: 'payment_failed',
  userId: user.id,
  amount: 100.00,
  error: error.message,
  stack: error.stack,
}, 'Payment processing failed');
```

## Metrics with Prometheus

```typescript
// metrics.ts
import promClient from 'prom-client';

// Enable default metrics (CPU, memory, etc.)
promClient.collectDefaultMetrics();

export const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total HTTP requests',
  labelNames: ['method', 'route', 'status'],
});

export const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'route'],
  buckets: [0.1, 0.5, 1, 2, 5],
});

export const activeConnections = new promClient.Gauge({
  name: 'active_connections',
  help: 'Number of active connections',
});

// Middleware
export function metricsMiddleware(req, res, next) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;

    httpRequestsTotal.labels(req.method, req.route?.path || req.path, res.statusCode).inc();
    httpRequestDuration.labels(req.method, req.route?.path || req.path).observe(duration);
  });

  next();
}

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

## Distributed Tracing with OpenTelemetry

```typescript
// tracing.ts
import { NodeSDK } from '@opentelemetry/sdk-node';
import { getNodeAutoInstrumentations } from '@opentelemetry/auto-instrumentations-node';
import { OTLPTraceExporter } from '@opentelemetry/exporter-trace-otlp-grpc';

export function setupTracing(serviceName: string) {
  const sdk = new NodeSDK({
    serviceName,
    traceExporter: new OTLPTraceExporter({
      url: 'http://localhost:4317',
    }),
    instrumentations: [getNodeAutoInstrumentations()],
  });

  sdk.start();

  process.on('SIGTERM', () => {
    sdk.shutdown().then(() => process.exit(0));
  });
}

// Manual spans
import { trace } from '@opentelemetry/api';

const tracer = trace.getTracer('my-service');

async function processOrder(orderId: string) {
  return await tracer.startActiveSpan('process_order', async (span) => {
    span.setAttribute('order.id', orderId);

    try {
      const result = await paymentService.charge(order);
      span.setAttribute('payment.status', 'success');
      return result;
    } catch (error) {
      span.recordException(error);
      span.setStatus({ code: SpanStatusCode.ERROR });
      throw error;
    } finally {
      span.end();
    }
  });
}
```

## Error Tracking with Sentry

```typescript
// sentry.ts
import * as Sentry from '@sentry/node';
import { ProfilingIntegration } from '@sentry/profiling-node';

export function setupSentry(app: Express) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 0.1,
    profilesSampleRate: 0.1,
    integrations: [
      new Sentry.Integrations.Http({ tracing: true }),
      new Sentry.Integrations.Express({ app }),
      new ProfilingIntegration(),
    ],
  });

  // Request handler must be first
  app.use(Sentry.Handlers.requestHandler());
  app.use(Sentry.Handlers.tracingHandler());

  // Routes...

  // Error handler must be last
  app.use(Sentry.Handlers.errorHandler());
}

// Manual error capture
import * as Sentry from '@sentry/node';

try {
  await riskyOperation();
} catch (error) {
  Sentry.captureException(error, {
    tags: { section: 'payment' },
    extra: { orderId, amount },
    user: { id: user.id, email: user.email },
  });
}

// Breadcrumbs
Sentry.addBreadcrumb({
  category: 'order',
  message: 'Order validation started',
  level: 'info',
});
```

## Complete Integration Example

```typescript
// app.ts
import express from 'express';
import { setupTracing } from './tracing';
import { setupSentry } from './sentry';
import { logger } from './logger';
import { metricsMiddleware } from './metrics';

const app = express();

// Initialize observability
setupTracing('my-api');
setupSentry(app);

// Add middleware
app.use(metricsMiddleware);

app.get('/api/users', async (req, res) => {
  logger.info({ event: 'fetching_users', endpoint: '/api/users' }, 'Fetching users');
  // Handler logic
  res.json({ users: [] });
});

app.listen(8080, () => {
  logger.info({ event: 'server_started', port: 8080 }, 'Server started');
});
```

## Dependencies

```json
{
  "dependencies": {
    "pino": "^8.0.0",
    "pino-pretty": "^10.0.0",
    "prom-client": "^15.0.0",
    "@opentelemetry/sdk-node": "^0.45.0",
    "@opentelemetry/auto-instrumentations-node": "^0.40.0",
    "@opentelemetry/exporter-trace-otlp-grpc": "^0.45.0",
    "@sentry/node": "^7.0.0",
    "@sentry/profiling-node": "^1.0.0"
  }
}
```
