# Error Handling Rules

**Priority: Medium**

## Overview

Proper error handling ensures applications gracefully recover from failures and provide meaningful feedback to users.

## Rules

### ERR-01: Handle WebSocket Errors

```javascript
// ✅ GOOD - Comprehensive error handling
class ClearNodeConnection {
  constructor(url) {
    this.url = url;
  }
  
  connect() {
    this.ws = new WebSocket(this.url);
    
    this.ws.onerror = (error) => {
      console.error('WebSocket error:', error);
      this.emit('error', {
        type: 'websocket',
        message: 'Connection error',
        original: error,
      });
    };
    
    this.ws.onclose = (event) => {
      console.log(`WebSocket closed: ${event.code} ${event.reason}`);
      
      if (event.code !== 1000) {
        // Abnormal closure
        this.emit('error', {
          type: 'connection_lost',
          code: event.code,
          reason: event.reason,
        });
      }
      
      this.attemptReconnect();
    };
  }
}
```

### ERR-02: Handle RPC Errors

```javascript
// ✅ GOOD - Handle error responses
const handleMessage = (event) => {
  const message = JSON.parse(event.data);
  
  // Check for error response
  if (message.err) {
    const [requestId, errorCode, errorMessage] = message.err;
    
    console.error(`RPC Error [${errorCode}]: ${errorMessage}`);
    
    // Handle specific error codes
    switch (errorCode) {
      case 'AUTH_FAILED':
        this.handleAuthFailure(errorMessage);
        break;
      case 'INSUFFICIENT_FUNDS':
        this.handleInsufficientFunds(errorMessage);
        break;
      case 'SESSION_NOT_FOUND':
        this.handleSessionNotFound(errorMessage);
        break;
      default:
        this.emit('error', { code: errorCode, message: errorMessage });
    }
    
    // Reject pending request
    const handler = this.requestMap.get(requestId);
    if (handler) {
      handler.reject(new Error(errorMessage));
      this.requestMap.delete(requestId);
    }
  }
};
```

### ERR-03: Implement Retry Logic

```javascript
// ✅ GOOD - Retry with exponential backoff
async function retryWithBackoff(fn, maxRetries = 3, initialDelay = 1000) {
  let lastError;
  
  for (let attempt = 0; attempt < maxRetries; attempt++) {
    try {
      return await fn();
    } catch (error) {
      lastError = error;
      
      // Don't retry on certain errors
      if (isNonRetryableError(error)) {
        throw error;
      }
      
      const delay = initialDelay * Math.pow(2, attempt);
      console.log(`Attempt ${attempt + 1} failed, retrying in ${delay}ms`);
      await sleep(delay);
    }
  }
  
  throw lastError;
}

// Usage
const result = await retryWithBackoff(
  () => sendRequest(message),
  3,
  1000
);
```

### ERR-04: Clean Up Resources on Error

```javascript
// ✅ GOOD - Always clean up
const createSession = async (params) => {
  const handleMessage = (event) => { /* ... */ };
  
  ws.addEventListener('message', handleMessage);
  
  try {
    const result = await sendAndWait(message);
    return result;
  } catch (error) {
    console.error('Session creation failed:', error);
    throw error;
  } finally {
    // Always remove listener
    ws.removeEventListener('message', handleMessage);
  }
};
```

### ERR-05: Provide User-Friendly Messages

```javascript
// ✅ GOOD - Translate technical errors
const errorMessages = {
  'AUTH_FAILED': 'Authentication failed. Please reconnect your wallet.',
  'INSUFFICIENT_FUNDS': 'Not enough funds in your channel. Please deposit more.',
  'SESSION_NOT_FOUND': 'Session expired. Please create a new session.',
  'TIMEOUT': 'Request timed out. Please check your connection.',
  'NETWORK_ERROR': 'Unable to connect. Please check your internet.',
};

const getUserMessage = (error) => {
  return errorMessages[error.code] || 'An unexpected error occurred.';
};
```

### ERR-06: Log Errors Appropriately

```javascript
// ✅ GOOD - Structured logging
class Logger {
  error(context, error, metadata = {}) {
    console.error(JSON.stringify({
      level: 'error',
      timestamp: new Date().toISOString(),
      context,
      message: error.message,
      code: error.code,
      stack: error.stack,
      ...metadata,
    }));
  }
  
  warn(context, message, metadata = {}) {
    console.warn(JSON.stringify({
      level: 'warn',
      timestamp: new Date().toISOString(),
      context,
      message,
      ...metadata,
    }));
  }
}

// Usage
logger.error('createSession', error, { participantA, participantB });
```

## Common Errors and Solutions

| Error | Cause | Solution |
|-------|-------|----------|
| `AUTH_FAILED` | Invalid signature or expired session | Re-authenticate with fresh credentials |
| `INSUFFICIENT_FUNDS` | Channel balance too low | Deposit more funds or reduce amount |
| `SESSION_NOT_FOUND` | Session closed or invalid ID | Create a new session |
| `TIMEOUT` | Network issues or ClearNode unresponsive | Retry with backoff |
| `INVALID_SIGNATURE` | EIP-191 prefix or wrong key | Use plain JSON signing |
| `CONNECTION_LOST` | WebSocket disconnected | Reconnect with exponential backoff |

## Error Recovery Patterns

### Connection Recovery

```javascript
class ClearNodeConnection {
  async ensureConnected() {
    if (this.isConnected && this.isAuthenticated) {
      return;
    }
    
    await this.connect();
    await this.authenticate();
  }
  
  async sendWithRecovery(message) {
    try {
      await this.ensureConnected();
      return await this.send(message);
    } catch (error) {
      if (error.message.includes('not connected')) {
        await this.ensureConnected();
        return await this.send(message);
      }
      throw error;
    }
  }
}
```

### Session Recovery

```javascript
class SessionManager {
  async ensureSession() {
    const sessionId = this.getStoredSessionId();
    
    if (!sessionId) {
      return await this.createNewSession();
    }
    
    try {
      // Verify session is still valid
      await this.getSessionStatus(sessionId);
      return sessionId;
    } catch (error) {
      if (error.code === 'SESSION_NOT_FOUND') {
        // Session expired, create new one
        return await this.createNewSession();
      }
      throw error;
    }
  }
}
```

## Error Boundary (React)

```javascript
class ClearNodeErrorBoundary extends React.Component {
  state = { hasError: false, error: null };
  
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  
  componentDidCatch(error, errorInfo) {
    console.error('ClearNode error:', error, errorInfo);
  }
  
  render() {
    if (this.state.hasError) {
      return (
        <div className="error-container">
          <h2>Connection Error</h2>
          <p>{getUserMessage(this.state.error)}</p>
          <button onClick={() => window.location.reload()}>
            Retry
          </button>
        </div>
      );
    }
    
    return this.props.children;
  }
}
```
