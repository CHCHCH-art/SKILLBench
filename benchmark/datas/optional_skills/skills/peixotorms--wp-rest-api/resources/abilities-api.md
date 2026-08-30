# Abilities API (WordPress 6.9+) — Detailed Examples

The Abilities API is a declarative permission/feature system for exposing server-side capabilities to client-side code.

## Hooks (registration order matters)

Categories MUST be registered before abilities:

1. `wp_abilities_api_categories_init` -- register categories here.
2. `wp_abilities_api_init` -- register abilities here.

Registering abilities outside `wp_abilities_api_init` triggers `_doing_it_wrong()`.

## Registering categories and abilities

```php
// 1. Register category
add_action( 'wp_abilities_api_categories_init', function () {
    wp_register_ability_category( 'my-plugin', [
        'label' => __( 'My Plugin', 'my-plugin' ),
    ] );
} );

// 2. Register abilities
add_action( 'wp_abilities_api_init', function () {
    wp_register_ability( 'my-plugin/get-info', [
        'label'               => __( 'Get Site Info', 'my-plugin' ),
        'description'         => __( 'Returns basic site information.', 'my-plugin' ),
        'category'            => 'my-plugin',
        'callback'            => 'my_plugin_get_info_callback',
        'permission_callback' => function () {
            return current_user_can( 'manage_options' );
        },
        'input_schema'  => [
            'type'       => 'object',
            'properties' => [
                'include_stats' => [ 'type' => 'boolean', 'default' => false ],
            ],
        ],
        'output_schema' => [
            'type'       => 'object',
            'properties' => [
                'name' => [ 'type' => 'string' ],
                'url'  => [ 'type' => 'string', 'format' => 'uri' ],
            ],
        ],
        'meta' => [
            'show_in_rest' => true,
            'readonly'     => false,
        ],
    ] );

    // Informational / read-only ability (feature flag pattern)
    wp_register_ability( 'my-plugin/supports-feature-x', [
        'label'    => __( 'Supports Feature X', 'my-plugin' ),
        'category' => 'my-plugin',
        'meta'     => [ 'show_in_rest' => true, 'readonly' => true ],
    ] );
} );
```

## Key arguments for wp_register_ability()

| Argument | Description |
|----------|-------------|
| `label` | Human-readable name for UI (e.g., command palette) |
| `description` | What the ability does |
| `category` | Category ID (must already be registered) |
| `callback` | Function that executes the ability |
| `permission_callback` | Check if current user can execute (required for write abilities) |
| `input_schema` | JSON Schema for expected input |
| `output_schema` | JSON Schema for returned output |
| `meta.show_in_rest` | `true` to expose via REST (required for client visibility) |
| `meta.readonly` | `true` if ability is informational only |

## REST endpoints

The Abilities API exposes:

- `GET /wp-json/wp-abilities/v1/abilities` -- list all visible abilities
- `GET /wp-json/wp-abilities/v1/categories` -- list all categories

Abilities only appear if `meta.show_in_rest` is `true`.

## Client-side: @wordpress/abilities

```js
import { useAbility, hasAbility } from '@wordpress/abilities';

// In a React component:
function FeaturePanel() {
    const canGetInfo = useAbility( 'my-plugin/get-info' );
    if ( ! canGetInfo ) {
        return null; // Progressive disclosure
    }
    return <div>Feature panel content</div>;
}

// Imperative check:
if ( hasAbility( 'my-plugin/supports-feature-x' ) ) {
    enableFeatureX();
}
```

## Use cases

- **Feature flags:** Gate UI features based on server-declared abilities.
- **Progressive disclosure:** Show controls only when the user/site supports them.
- **Capability-driven UI:** Replace hardcoded role checks with declarative ability checks.
- **AI/agent integration:** `input_schema` and `output_schema` help external agents understand available operations.

## Best practices

- Namespace IDs (e.g. `my-plugin:feature.edit` or `my-plugin/feature`).
- Treat IDs as stable API; changing them is a breaking change.
- Always include `permission_callback` for abilities that modify data.
- Use `input_schema` and `output_schema` for validation and discoverability.
