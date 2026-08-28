---
name: wp-rest-api
description: Use when building WordPress REST API endpoints, custom routes, controllers, or using the Abilities API. Covers register_rest_route, WP_REST_Controller, WP_REST_Request, WP_REST_Response, permission_callback, JSON schema validation, sanitize_callback, register_rest_field, register_post_meta with show_in_rest, wp_remote_get, wp-json endpoints (/wp/v2/), authentication (JWT, application passwords, OAuth, cookie nonce), response shaping, pagination, Batch API, custom post type REST exposure, and the Abilities API for declarative permissions.
---

# WP REST API & Abilities API

## Route Registration

Register routes on the `rest_api_init` hook using `register_rest_route()`. A **route** is the URL pattern; an **endpoint** is the method + callback bound to that route. For non-trivial endpoints, extend `WP_REST_Controller` for a structured CRUD pattern with built-in schema wiring.

<!-- See resources/route-registration.md for detailed examples -->

### Namespacing rules

- Always use a unique namespace: `vendor/v1` (e.g. `myplugin/v1`).
- Never use `wp/*` unless contributing to WordPress core.
- For non-pretty permalinks, routes are accessed via `?rest_route=/namespace/route`.

### HTTP method constants

| Constant | Methods |
|----------|---------|
| `WP_REST_Server::READABLE` | GET |
| `WP_REST_Server::CREATABLE` | POST |
| `WP_REST_Server::EDITABLE` | PUT, PATCH |
| `WP_REST_Server::DELETABLE` | DELETE |
| `WP_REST_Server::ALLMETHODS` | All of the above |

Multiple endpoints can share a route (one per method group).

## Schema & Validation

### JSON Schema

WordPress REST API uses a subset of JSON Schema (draft 4) for both resource definitions and argument validation. Schema serves as documentation AND validation.

- Provide schema via `get_item_schema()` on controllers or a `schema` callback on routes.
- Schema is returned on `OPTIONS` requests, enabling API discovery.
- Cache the schema on the controller instance (`$this->schema`) to avoid recomputation.

### Common formats and types

| Format | Example |
|--------|---------|
| `date-time` | `2025-01-15T10:30:00` |
| `uri` | `https://example.com` |
| `email` | `user@example.com` |
| `ip` | `192.168.1.1` |
| `uuid` | `550e8400-e29b-41d4-a716-446655440000` |
| `hex-color` | `#ff0000` |

For `array` types, define `items` schema. For `object` types, define `properties`.

### validate_callback and sanitize_callback

```php
'args' => [
    'email' => [
        'type'              => 'string',
        'format'            => 'email',
        'required'          => true,
        'validate_callback' => 'rest_validate_request_arg', // uses schema
        'sanitize_callback' => 'sanitize_email',
    ],
    'count' => [
        'type'              => 'integer',
        'minimum'           => 1,
        'maximum'           => 100,
        'default'           => 10,
        'validate_callback' => function ( $value, $request, $param ) {
            if ( ! is_numeric( $value ) ) {
                return new WP_Error( 'invalid_param', "$param must be numeric." );
            }
            return true;
        },
        'sanitize_callback' => 'absint',
    ],
],
```

**Important:** If you override `sanitize_callback`, built-in schema validation will not run automatically. Use `rest_validate_request_arg` as `validate_callback` to preserve it.

The controller method `get_endpoint_args_for_item_schema()` wires validation automatically from the schema.

## Permission & Authentication

### permission_callback is REQUIRED

Every route MUST have a `permission_callback`. Omitting it triggers a `_doing_it_wrong` notice.

- Public read endpoints: use `'permission_callback' => '__return_true'`.
- Write endpoints: NEVER use `__return_true`. Always check capabilities.
- Use `current_user_can()` for capability checks, not just "is logged in".
- **Hide sensitive endpoints** from the REST index with `'show_in_index' => false` — prevents API keys, tokens, or admin data from being discoverable via `GET /wp-json/`.

```php
'permission_callback' => function ( $request ) {
    return current_user_can( 'edit_post', $request['id'] );
},

// Sensitive admin endpoint — hide from /wp-json/ discovery.
register_rest_route( 'myplugin/v1', '/admin/config', [
    'methods'             => 'POST',
    'callback'            => 'myplugin_admin_config',
    'permission_callback' => function () {
        return current_user_can( 'manage_options' );
    },
    'show_in_index'       => false,  // Not listed in /wp-json/ index.
] );
```

### Authentication methods

**Cookie + nonce (logged-in frontend JS):**

```php
// Localize in PHP:
wp_localize_script( 'my-script', 'MyPlugin', [
    'root'  => esc_url_raw( rest_url() ),
    'nonce' => wp_create_nonce( 'wp_rest' ),
] );
```

```js
// In JS:
fetch( MyPlugin.root + 'myplugin/v1/items', {
    headers: { 'X-WP-Nonce': MyPlugin.nonce },
} );
```

If the nonce is missing, the request is treated as unauthenticated even if cookies exist.

**Application Passwords (external clients, WP 5.6+):**

```bash
# HTTPS required. Use Basic Auth with the application password.
curl -u "username:xxxx xxxx xxxx xxxx xxxx xxxx" \
  https://example.com/wp-json/myplugin/v1/items
```

**OAuth/JWT (via plugins):** Use only when required. Follow the specific plugin's documentation.

**`rest_authentication_errors` filter:** Hook into this to add custom authentication or block unauthenticated access globally. Return `WP_Error` to deny, `true` to approve, or pass through existing results.

## Response Shaping

### WP_REST_Response

```php
function myplugin_get_items( $request ) {
    $items = []; // fetch data
    $total = 100;
    $pages = 10;

    $response = new WP_REST_Response( $items, 200 );
    $response->header( 'X-WP-Total', $total );
    $response->header( 'X-WP-TotalPages', $pages );
    return $response;
}
```

Use `rest_ensure_response()` to wrap arrays/scalars into `WP_REST_Response` automatically.

### Field registration with register_rest_field()

Add computed fields to existing endpoints. Do NOT remove or change core fields (breaks clients including wp-admin).

```php
add_action( 'rest_api_init', function () {
    register_rest_field( 'post', 'word_count', [
        'get_callback' => function ( $post_arr ) {
            return str_word_count( wp_strip_all_tags( $post_arr['content']['rendered'] ) );
        },
        'update_callback' => null, // read-only
        'schema'          => [
            'description' => 'Word count of the post content.',
            'type'        => 'integer',
            'context'     => [ 'view', 'edit' ],
            'readonly'    => true,
        ],
    ] );
} );
```

### Meta fields with register_meta()

```php
register_post_meta( 'post', 'myplugin_rating', [
    'type'          => 'integer',
    'single'        => true,
    'show_in_rest'  => true,
    'auth_callback' => function () {
        return current_user_can( 'edit_posts' );
    },
] );

// For object/array meta, provide a schema:
register_post_meta( 'post', 'myplugin_settings', [
    'type'         => 'object',
    'single'       => true,
    'show_in_rest' => [
        'schema' => [
            'type'       => 'object',
            'properties' => [
                'color' => [ 'type' => 'string' ],
                'size'  => [ 'type' => 'integer' ],
            ],
        ],
    ],
] );
```

### Links and embedding

```php
$response->add_link( 'author', rest_url( 'wp/v2/users/' . $post->post_author ), [
    'embeddable' => true, // allows ?_embed to inline this
] );
```

Register CURIEs (compact URIs) via the `rest_response_link_curies` filter.

### Sparse responses with `_fields`

Clients can request `?_fields=id,title,meta.myplugin_rating` to receive only specific fields. Supports nested keys.

### Pagination

Collections should return these headers:

| Header | Purpose |
|--------|---------|
| `X-WP-Total` | Total number of items |
| `X-WP-TotalPages` | Total number of pages |

Standard params: `page`, `per_page` (capped at 100), `offset`.

### Raw vs rendered content

`content.rendered` reflects filters (plugins may inject HTML). Use `?context=edit&_fields=content.raw` (authenticated) to access raw content.

## Custom Post Types & Taxonomies

### Exposing a CPT

```php
register_post_type( 'book', [
    'label'               => 'Books',
    'public'              => true,
    'show_in_rest'        => true,            // Required for REST
    'rest_base'           => 'books',          // Custom URL slug
    'rest_controller_class' => 'WP_REST_Posts_Controller', // Default
    'supports'            => [ 'title', 'editor', 'custom-fields' ],
] );
```

### Exposing a custom taxonomy

```php
register_taxonomy( 'genre', 'book', [
    'label'          => 'Genres',
    'show_in_rest'   => true,
    'rest_base'      => 'genres',
    // rest_controller_class defaults to WP_REST_Terms_Controller
] );
```

### Adding REST to existing types you do not control

Use `register_post_type_args` or `register_taxonomy_args` filters to set `show_in_rest => true` and `rest_base` on types you do not own.

### Custom controllers

Set `rest_controller_class` to a class extending `WP_REST_Controller`. Use `rest_route_for_post` or `rest_route_for_term` filters for discovery links.

## Discovery & Features

### API discovery

REST API root is discovered via the `Link: <.../wp-json/>; rel="https://api.w.org/"` header or the equivalent `<link>` element in HTML. The `/wp-json/` index lists all namespaces and routes. For non-pretty permalinks use `?rest_route=/`.

### Global parameters

| Parameter | Purpose |
|-----------|---------|
| `_fields` | Sparse field selection |
| `_embed` | Include linked resources in `_embedded` |
| `_method` | Simulate PUT/DELETE via POST |
| `_envelope` | Wrap status + headers in response body |
| `_jsonp` | JSONP for legacy clients |

Also: `X-HTTP-Method-Override` header as alternative to `_method`.

### Batch API

Send multiple requests in one call: `POST /wp-json/batch/v1` with a `requests` array of `{ "method", "path" }` objects.

## Abilities API (WordPress 6.9+)

The Abilities API is a declarative permission/feature system for exposing server-side capabilities to client-side code. Register categories on `wp_abilities_api_categories_init` (first), then abilities on `wp_abilities_api_init`. Set `meta.show_in_rest => true` to expose abilities via `GET /wp-json/wp-abilities/v1/abilities`. Use `@wordpress/abilities` (`useAbility`, `hasAbility`) on the client side.

<!-- See resources/abilities-api.md for detailed examples -->

## Error Handling

### WP_Error for error responses

```php
// In a callback:
$post = get_post( $request['id'] );
if ( ! $post ) {
    return new WP_Error(
        'myplugin_not_found',
        __( 'Item not found.', 'myplugin' ),
        [ 'status' => 404 ]
    );
}

// In permission_callback (returning WP_Error gives the client a reason):
if ( ! current_user_can( 'edit_posts' ) ) {
    return new WP_Error(
        'rest_forbidden',
        __( 'You do not have permission to create items.', 'myplugin' ),
        [ 'status' => 403 ]
    );
}
```

Always include `status` in the `data` array. Standard codes:

| HTTP Status | When |
|-------------|------|
| 400 | Invalid parameters / bad request |
| 401 | Not authenticated |
| 403 | Authenticated but insufficient permissions |
| 404 | Resource not found |
| 500 | Server error |

Use `rest_validate_request_arg()` to validate individual args against their schema (returns `WP_Error` on failure).

Do NOT call `wp_send_json()` or `die()` inside REST callbacks. Always return data, `WP_REST_Response`, or `WP_Error`.

## Common Patterns

### Custom collection parameters (filtering, sorting)

```php
public function get_collection_params() {
    $params = parent::get_collection_params();
    $params['status'] = [
        'description' => 'Limit results to a specific status.',
        'type'        => 'string',
        'enum'        => [ 'draft', 'publish', 'archived' ],
        'default'     => 'publish',
    ];
    $params['orderby'] = [
        'description' => 'Sort collection by attribute.',
        'type'        => 'string',
        'enum'        => [ 'date', 'title', 'rating' ],
        'default'     => 'date',
    ];
    return $params;
}
```

### Registering custom REST fields on existing endpoints

```php
add_action( 'rest_api_init', function () {
    register_rest_field( 'comment', 'author_avatar_url', [
        'get_callback' => function ( $comment_arr ) {
            return get_avatar_url( $comment_arr['author_email'], [ 'size' => 48 ] );
        },
        'schema' => [
            'type'        => 'string',
            'format'      => 'uri',
            'description' => 'Avatar URL for the comment author.',
            'context'     => [ 'view', 'embed' ],
        ],
    ] );
} );
```

## Common Mistakes

| Mistake | Consequence | Fix |
|---------|-------------|-----|
| Omitting `permission_callback` | `_doing_it_wrong` notice; route may not work | Always provide it; use `__return_true` for public reads |
| Using `__return_true` on write endpoints | Any visitor can create/update/delete data | Check capabilities with `current_user_can()` |
| Reading `$_GET`/`$_POST` directly | Bypasses validation and sanitization | Use `$request->get_param()` or `$request['key']` |
| Calling `wp_send_json()` or `die()` | Breaks response lifecycle, no proper headers | Return data, `WP_REST_Response`, or `WP_Error` |
| Missing `status` in `WP_Error` data | Client receives 500 instead of correct code | Always pass `['status' => 4xx]` in error data |
| Using `wp/*` namespace | Conflicts with WordPress core routes | Use your own vendor namespace |
| Forgetting `show_in_rest` on CPT | Post type not exposed in REST API | Set `show_in_rest => true` |
| Missing `custom-fields` support on CPT | Meta fields not available via REST | Add `'supports' => ['custom-fields']` |
| Not sending `X-WP-Nonce` with cookie auth | Request treated as unauthenticated | Send nonce as header or `_wpnonce` param |
| Setting `per_page` above 100 | WP rejects the request | Cap at 100; use pagination |
| Removing core fields from default endpoints | Breaks wp-admin and other clients | Add new fields instead; clients use `_fields` to limit |
| Registering abilities outside proper hooks | `_doing_it_wrong()`; registration fails | Use `wp_abilities_api_init` / `wp_abilities_api_categories_init` |
| Missing `meta.show_in_rest` on abilities | Ability invisible to REST clients | Set `meta.show_in_rest => true` |
| Registering abilities before categories | Ability has no category association | Register categories on `wp_abilities_api_categories_init` first |
