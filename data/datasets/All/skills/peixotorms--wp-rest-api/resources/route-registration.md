# Route Registration — Detailed Examples

## `register_rest_route()`

Register routes on the `rest_api_init` hook. A **route** is the URL pattern; an **endpoint** is the method + callback bound to that route.

```php
add_action( 'rest_api_init', function () {
    // Simple GET endpoint
    register_rest_route( 'myplugin/v1', '/items', [
        'methods'             => WP_REST_Server::READABLE, // GET
        'callback'            => 'myplugin_get_items',
        'permission_callback' => '__return_true',
    ] );

    // POST endpoint with args
    register_rest_route( 'myplugin/v1', '/items', [
        'methods'             => WP_REST_Server::CREATABLE, // POST
        'callback'            => 'myplugin_create_item',
        'permission_callback' => function ( $request ) {
            return current_user_can( 'edit_posts' );
        },
        'args' => [
            'title' => [
                'type'              => 'string',
                'required'          => true,
                'sanitize_callback' => 'sanitize_text_field',
            ],
            'status' => [
                'type'    => 'string',
                'default' => 'draft',
                'enum'    => [ 'draft', 'publish' ],
            ],
        ],
    ] );

    // Route with regex-constrained parameter
    register_rest_route( 'myplugin/v1', '/items/(?P<id>[\d]+)', [
        'methods'             => WP_REST_Server::EDITABLE, // PUT, PATCH
        'callback'            => 'myplugin_update_item',
        'permission_callback' => function ( $request ) {
            return current_user_can( 'edit_post', $request['id'] );
        },
        'args' => [
            'id' => [
                'type'              => 'integer',
                'required'          => true,
                'validate_callback' => 'rest_validate_request_arg',
                'sanitize_callback' => 'absint',
            ],
        ],
    ] );

    // DELETE endpoint
    register_rest_route( 'myplugin/v1', '/items/(?P<id>[\d]+)', [
        'methods'             => WP_REST_Server::DELETABLE,
        'callback'            => 'myplugin_delete_item',
        'permission_callback' => function ( $request ) {
            return current_user_can( 'delete_post', $request['id'] );
        },
    ] );
} );
```

## `WP_REST_Controller` pattern

Extend `WP_REST_Controller` for non-trivial endpoints. This gives you a structured CRUD pattern with built-in schema wiring.

```php
class MyPlugin_Items_Controller extends WP_REST_Controller {

    protected $namespace = 'myplugin/v1';
    protected $rest_base = 'items';

    public function register_routes() {
        register_rest_route( $this->namespace, '/' . $this->rest_base, [
            [
                'methods'             => WP_REST_Server::READABLE,
                'callback'            => [ $this, 'get_items' ],
                'permission_callback' => [ $this, 'get_items_permissions_check' ],
                'args'                => $this->get_collection_params(),
            ],
            [
                'methods'             => WP_REST_Server::CREATABLE,
                'callback'            => [ $this, 'create_item' ],
                'permission_callback' => [ $this, 'create_item_permissions_check' ],
                'args'                => $this->get_endpoint_args_for_item_schema( WP_REST_Server::CREATABLE ),
            ],
            'schema' => [ $this, 'get_public_item_schema' ],
        ] );

        register_rest_route( $this->namespace, '/' . $this->rest_base . '/(?P<id>[\d]+)', [
            [
                'methods'             => WP_REST_Server::READABLE,
                'callback'            => [ $this, 'get_item' ],
                'permission_callback' => [ $this, 'get_item_permissions_check' ],
                'args'                => [ 'context' => $this->get_context_param( [ 'default' => 'view' ] ) ],
            ],
            [
                'methods'             => WP_REST_Server::EDITABLE,
                'callback'            => [ $this, 'update_item' ],
                'permission_callback' => [ $this, 'update_item_permissions_check' ],
                'args'                => $this->get_endpoint_args_for_item_schema( WP_REST_Server::EDITABLE ),
            ],
            [
                'methods'             => WP_REST_Server::DELETABLE,
                'callback'            => [ $this, 'delete_item' ],
                'permission_callback' => [ $this, 'delete_item_permissions_check' ],
            ],
            'schema' => [ $this, 'get_public_item_schema' ],
        ] );
    }

    // Permission checks — use current_user_can() for write operations
    public function get_items_permissions_check( $request )    { return true; }
    public function get_item_permissions_check( $request )     { return true; }
    public function create_item_permissions_check( $request )  { return current_user_can( 'edit_posts' ); }
    public function update_item_permissions_check( $request )  { return current_user_can( 'edit_post', $request['id'] ); }
    public function delete_item_permissions_check( $request )  { return current_user_can( 'delete_post', $request['id'] ); }

    public function get_items( $request ) {
        $items = []; // fetch from DB
        return rest_ensure_response( array_map(
            fn( $item ) => $this->prepare_item_for_response( $item, $request ), $items
        ) );
    }

    public function get_item( $request ) {
        $item = null; // fetch by $request['id']
        if ( ! $item ) {
            return new WP_Error( 'not_found', 'Item not found.', [ 'status' => 404 ] );
        }
        return rest_ensure_response( $this->prepare_item_for_response( $item, $request ) );
    }

    public function create_item( $request ) {
        $item = null; // insert logic
        return new WP_REST_Response( $this->prepare_item_for_response( $item, $request ), 201 );
    }

    public function update_item( $request ) {
        $item = null; // update logic
        return rest_ensure_response( $this->prepare_item_for_response( $item, $request ) );
    }

    public function delete_item( $request ) {
        return new WP_REST_Response( null, 204 );
    }

    public function prepare_item_for_response( $item, $request ) {
        $data     = [];
        $fields   = $this->get_fields_for_response( $request );
        if ( rest_is_field_included( 'id', $fields ) )    { $data['id']    = $item->id; }
        if ( rest_is_field_included( 'title', $fields ) ) { $data['title'] = $item->title; }
        $response = rest_ensure_response( $data );
        $response->add_links( [
            'self'       => [ 'href' => rest_url( "{$this->namespace}/{$this->rest_base}/{$item->id}" ) ],
            'collection' => [ 'href' => rest_url( "{$this->namespace}/{$this->rest_base}" ) ],
        ] );
        return $response;
    }

    public function get_item_schema() {
        if ( $this->schema ) {
            return $this->add_additional_fields_schema( $this->schema );
        }
        $this->schema = [
            '$schema'    => 'http://json-schema.org/draft-04/schema#',
            'title'      => 'myplugin-item',
            'type'       => 'object',
            'properties' => [
                'id'    => [
                    'description' => 'Unique identifier.',
                    'type'        => 'integer',
                    'context'     => [ 'view', 'edit' ],
                    'readonly'    => true,
                ],
                'title' => [
                    'description' => 'Item title.',
                    'type'        => 'string',
                    'context'     => [ 'view', 'edit' ],
                    'required'    => true,
                ],
                'status' => [
                    'description' => 'Publication status.',
                    'type'        => 'string',
                    'enum'        => [ 'draft', 'publish' ],
                    'context'     => [ 'view', 'edit' ],
                    'default'     => 'draft',
                ],
            ],
        ];
        return $this->add_additional_fields_schema( $this->schema );
    }
}

// Register the controller:
add_action( 'rest_api_init', function () {
    $controller = new MyPlugin_Items_Controller();
    $controller->register_routes();
} );
```
