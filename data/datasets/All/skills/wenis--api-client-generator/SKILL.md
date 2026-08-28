---
name: api-client-generator
description: Generates typed API client libraries from OpenAPI/Swagger specs, GraphQL schemas (using GraphQL Code Generator), or example API requests. Creates TypeScript/Python/Go clients with methods for each endpoint, request/response types, authentication handling (Bearer, OAuth2), error types, and retry logic. Supports REST and GraphQL APIs. Use when integrating external APIs (Stripe, GitHub, AWS), creating internal API clients, building SDK wrappers for public APIs, or generating type-safe API consumers.
allowed-tools: Read, Write, WebFetch, Bash
---

# API Client Generator

You generate type-safe, well-structured API client code from API specifications or examples.

## When to use
- Integrating with third-party APIs (Stripe, GitHub, etc.)
- Consuming internal microservices
- Building SDK/wrapper for an API
- Migrating from manual fetch/axios calls to typed clients
- When API documentation is available (OpenAPI, Swagger, GraphQL)

## Supported input formats

### 1. OpenAPI/Swagger Spec
Best for REST APIs with formal specifications.

**Example:**
```yaml
openapi: 3.0.0
info:
  title: User API
  version: 1.0.0
paths:
  /users/{id}:
    get:
      summary: Get user by ID
      parameters:
        - name: id
          in: path
          required: true
          schema:
            type: string
      responses:
        '200':
          description: User object
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/User'
components:
  schemas:
    User:
      type: object
      properties:
        id:
          type: string
        email:
          type: string
        name:
          type: string
```

### 2. GraphQL Schema
For GraphQL APIs.

**Example:**
```graphql
type User {
  id: ID!
  email: String!
  name: String!
  posts: [Post!]!
}

type Query {
  user(id: ID!): User
  users(limit: Int): [User!]!
}
```

### 3. Example requests
When no spec exists, use example curl commands or HTTP requests.

**Example:**
```bash
curl -X GET https://api.example.com/users/123 \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json"
```

## Output structure

Generate clients with this structure:
```
api/
  client.ts          # Main client class
  types.ts           # Type definitions
  errors.ts          # Custom error classes
  endpoints/
    users.ts         # User-related endpoints
    posts.ts         # Post-related endpoints
  __tests__/
    client.test.ts   # Client tests
```

## Code generation approach

### TypeScript/JavaScript client
```typescript
// api/types.ts
export interface User {
  id: string;
  email: string;
  name: string;
}

export interface APIError {
  message: string;
  code: string;
  statusCode: number;
}

// api/errors.ts
export class APIClientError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code?: string
  ) {
    super(message);
    this.name = 'APIClientError';
  }
}

// api/client.ts
export class APIClient {
  constructor(
    private baseURL: string,
    private apiKey?: string
  ) {}

  private async request<T>(
    endpoint: string,
    options: RequestInit = {}
  ): Promise<T> {
    const url = `${this.baseURL}${endpoint}`;
    const headers: HeadersInit = {
      'Content-Type': 'application/json',
      ...options.headers,
    };

    if (this.apiKey) {
      headers['Authorization'] = `Bearer ${this.apiKey}`;
    }

    const response = await fetch(url, {
      ...options,
      headers,
    });

    if (!response.ok) {
      const error = await response.json();
      throw new APIClientError(
        error.message || 'Request failed',
        response.status,
        error.code
      );
    }

    return response.json();
  }

  async getUser(id: string): Promise<User> {
    return this.request<User>(`/users/${id}`);
  }

  async listUsers(limit?: number): Promise<User[]> {
    const params = limit ? `?limit=${limit}` : '';
    return this.request<User[]>(`/users${params}`);
  }

  async createUser(data: Omit<User, 'id'>): Promise<User> {
    return this.request<User>('/users', {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }
}
```

### Python client
```python
# api/client.py
from typing import Optional, List
from dataclasses import dataclass
import requests


@dataclass
class User:
    id: str
    email: str
    name: str


class APIClientError(Exception):
    def __init__(self, message: str, status_code: int, code: Optional[str] = None):
        super().__init__(message)
        self.status_code = status_code
        self.code = code


class APIClient:
    def __init__(self, base_url: str, api_key: Optional[str] = None):
        self.base_url = base_url
        self.api_key = api_key
        self.session = requests.Session()

        if api_key:
            self.session.headers['Authorization'] = f'Bearer {api_key}'

    def _request(self, method: str, endpoint: str, **kwargs) -> dict:
        url = f'{self.base_url}{endpoint}'
        response = self.session.request(method, url, **kwargs)

        if not response.ok:
            error = response.json()
            raise APIClientError(
                error.get('message', 'Request failed'),
                response.status_code,
                error.get('code')
            )

        return response.json()

    def get_user(self, user_id: str) -> User:
        data = self._request('GET', f'/users/{user_id}')
        return User(**data)

    def list_users(self, limit: Optional[int] = None) -> List[User]:
        params = {'limit': limit} if limit else {}
        data = self._request('GET', '/users', params=params)
        return [User(**user) for user in data]

    def create_user(self, email: str, name: str) -> User:
        data = self._request('POST', '/users', json={'email': email, 'name': name})
        return User(**data)
```

## Features to include

### 1. Type safety
- Generate interfaces/types from schema
- Validate request/response shapes
- Type inference for better IDE support

### 2. Error handling
- Custom error classes
- Detailed error messages
- HTTP status code handling
- Retry logic for transient failures

### 3. Authentication
- API keys (header, query param)
- OAuth 2.0 flows
- JWT token management
- Token refresh logic

### 4. Request configuration
- Timeouts
- Custom headers
- Base URL configuration
- Request/response interceptors

### 5. Testing support
- Mock implementations
- Request recording
- Test fixtures

## Instructions

1. **Analyze input**: Read OpenAPI spec, GraphQL schema, or examples
2. **Extract types**: Generate type definitions for all models
3. **Design client structure**: Plan class/module organization
4. **Generate code**: Create client with all endpoints
5. **Add error handling**: Custom errors, validation
6. **Add tests**: Basic test coverage for client methods
7. **Document usage**: README with examples

## Example: Generating from OpenAPI

**Input:** OpenAPI spec URL or file

**Steps:**
1. Read spec (from file or fetch from URL)
2. Parse operations and schemas
3. Generate types from components/schemas
4. Generate methods for each operation
5. Add authentication based on securitySchemes
6. Create tests for each method
7. Write README with usage examples

**Output files:**
- `api/client.ts` - Main client class
- `api/types.ts` - Type definitions
- `api/errors.ts` - Error classes
- `api/__tests__/client.test.ts` - Tests
- `README.md` - Usage guide

## Tools and libraries

### Code generation
- TypeScript: `openapi-typescript`, `graphql-codegen`
- Python: `openapi-python-client`, `datamodel-code-generator`
- Go: `oapi-codegen`, `go-swagger`

### Usage in generated code
- TypeScript: `fetch`, `axios`, `ky`
- Python: `requests`, `httpx`, `aiohttp`
- Go: `net/http`, `resty`

## Example usage in README

```typescript
// Usage example
import { APIClient } from './api/client';

const client = new APIClient('https://api.example.com', 'your-api-key');

// Get a user
const user = await client.getUser('123');
console.log(user.name);

// List users with limit
const users = await client.listUsers(10);

// Create a new user
const newUser = await client.createUser({
  email: 'user@example.com',
  name: 'John Doe'
});

// Error handling
try {
  await client.getUser('invalid-id');
} catch (error) {
  if (error instanceof APIClientError) {
    console.error(`API Error: ${error.message} (${error.statusCode})`);
  }
}
```

## Best practices
- Generate code, don't write manually (use codegen tools when possible)
- Include type definitions for all inputs/outputs
- Add comprehensive error handling
- Provide usage examples in comments or README
- Version the generated client (track spec version)
- Add rate limiting/retry logic for production use
- Include request/response logging for debugging

## Constraints
- Do NOT include API keys or secrets in generated code
- Do NOT ignore error cases
- Always generate types (no `any` in TypeScript)
- Keep generated code readable and maintainable
- Add comments for non-obvious functionality
