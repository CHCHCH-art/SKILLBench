# ClearNode Connection Rules

**Priority: Critical**

## Overview

A ClearNode is a message broker for the Clearnet protocol, providing off-chain communication, message relay, and state validation.

## Rules

### CONN-01: Always Use Secure WebSocket

```javascript
// ✅ GOOD
const ws = new WebSocket('wss://clearnet.yellow.com/ws');

// ❌ BAD - Never use unencrypted connections
const ws = new WebSocket('ws://clearnet.yellow.com/ws');
```

### CONN-02: Implement Reconnection with Exponential Backoff

```javascript
// ✅ GOOD
attemptReconnect() {
  if (this.reconnectAttempts >= this.maxReconnectAttempts) {
    console.error('Maximum reconnection attempts reached');
    return;
  }
  
  this.reconnectAttempts++;
  const delay = this.reconnectInterval * Math.pow(2, this.reconnectAttempts - 1);
  
  setTimeout(() => this.connect(), delay);
}

// ❌ BAD - Fixed interval reconnection
attemptReconnect() {
  setTimeout(() => this.connect(), 1000); // Always 1 second
}
```

### CONN-03: Track Connection State

```javascript
// ✅ GOOD
class ClearNodeConnection {
  constructor(url) {
    this.url = url;
    this.isConnected = false;
    this.isAuthenticated = false;
  }
  
  handleOpen() {
    this.isConnected = true;
    this.emit('connected');
  }
  
  handleClose() {
    this.isConnected = false;
    this.isAuthenticated = false;
    this.emit('disconnected');
  }
}
```

### CONN-04: Implement Event System

```javascript
// ✅ GOOD - Use event emitter pattern
class ClearNodeConnection extends EventEmitter {
  constructor(url) {
    super();
    this.url = url;
  }
  
  handleMessage(event) {
    const message = JSON.parse(event.data);
    this.emit('message', message);
    
    // Emit specific events
    const messageType = message.res ? message.res[1] : 'unknown';
    this.emit(messageType, message);
  }
}

// Usage
connection.on('authenticated', () => {
  console.log('Ready to send requests');
});
```

### CONN-05: Set Connection Timeout

```javascript
// ✅ GOOD
connect() {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      if (!this.isConnected) {
        this.ws.close();
        reject(new Error('Connection timeout'));
      }
    }, 10000);
    
    this.ws = new WebSocket(this.url);
    this.ws.onopen = () => {
      clearTimeout(timeout);
      resolve();
    };
  });
}
```

### CONN-06: Clean Up on Disconnect

```javascript
// ✅ GOOD
disconnect() {
  // Clear all pending requests
  for (const [requestId, handler] of this.requestMap.entries()) {
    clearTimeout(handler.timeout);
    handler.reject(new Error('Connection closed'));
    this.requestMap.delete(requestId);
  }
  
  if (this.ws) {
    this.ws.close(1000, 'User initiated disconnect');
    this.ws = null;
  }
}
```

## Production Configuration

```javascript
const config = {
  url: 'wss://clearnet.yellow.com/ws',
  maxReconnectAttempts: 5,
  reconnectInterval: 3000,
  connectionTimeout: 10000,
  requestTimeout: 30000,
};
```

## Multi-Chain Support

ClearNodes support multiple EVM blockchains:
- Polygon
- Celo
- Base

The same WebSocket connection handles all chains through the unified balance system.
