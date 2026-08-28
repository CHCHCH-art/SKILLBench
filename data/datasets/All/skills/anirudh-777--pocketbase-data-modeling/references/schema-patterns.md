# Schema Patterns

## Common Collection Roles
- Identity collections: users, organizations
- Transaction collections: orders, invoices, events
- Join collections: membership, assignment

## Field Strategy
- Prefer explicit timestamps (`created`, `updated`) and owner references.
- Use select/boolean fields for low-cardinality state.
- Use JSON fields only for truly flexible payloads.

## Relation Strategy
- One-to-many: foreign key relation in child collection.
- Many-to-many: explicit join collection with metadata.
