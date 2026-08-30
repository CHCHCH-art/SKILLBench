---
name: data-modeling
description: Use when designing data models, database schemas, or choosing between modeling approaches. Covers dimensional modeling, star schema, data vault, entity-relationship design, and schema evolution.
allowed-tools: Read, Glob, Grep
---

# Data Modeling

Comprehensive guide to data modeling techniques for operational databases, data warehouses, and analytical systems.

## When to Use This Skill

- Designing database schemas
- Choosing between modeling approaches
- Building data warehouses
- Planning schema evolution
- Understanding trade-offs in data models
- Designing for analytics vs operations

## Data Modeling Fundamentals

### Types of Data Models

```text
Data Model Categories:

1. Conceptual Model
   Purpose: Business understanding
   Audience: Business stakeholders
   Content: Entities, relationships, business rules
   Detail: High-level, no implementation details

2. Logical Model
   Purpose: Structure definition
   Audience: Data architects
   Content: Tables, columns, keys, relationships
   Detail: Database-agnostic design

3. Physical Model
   Purpose: Implementation
   Audience: Database engineers
   Content: Indexes, partitions, storage
   Detail: Database-specific optimization

Model Evolution:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Business         Conceptual        Logical       Physical   │
│  Requirements ──► Model        ──► Model     ──► Model      │
│                                                              │
│  "Customers       Customer ─────►  customers    customers    │
│   make orders"    Order           ├── id        ├── id PK   │
│                   └──< makes      ├── name      ├── name    │
│                                   └── email     ├── email   │
│                                                 └── idx_*   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

### Operational vs Analytical

```text
Operational (OLTP) vs Analytical (OLAP):

┌────────────────────────────────────────────────────────────┐
│                      OLTP                                   │
│            (Online Transaction Processing)                  │
├────────────────────────────────────────────────────────────┤
│ Purpose:    Run the business                               │
│ Workload:   Many small transactions                        │
│ Model:      Normalized (3NF)                               │
│ Optimize:   Write performance, consistency                 │
│ Users:      Applications, services                         │
│ Example:    INSERT new order, UPDATE inventory             │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│                      OLAP                                   │
│            (Online Analytical Processing)                   │
├────────────────────────────────────────────────────────────┤
│ Purpose:    Analyze the business                           │
│ Workload:   Few complex queries                            │
│ Model:      Denormalized (star/snowflake)                  │
│ Optimize:   Read performance, aggregation                  │
│ Users:      Analysts, BI tools                             │
│ Example:    SUM(sales) GROUP BY region, month              │
└────────────────────────────────────────────────────────────┘

When to Use Each:
├── OLTP: User-facing applications, real-time operations
├── OLAP: Reporting, dashboards, machine learning
└── Hybrid: Some systems need both (HTAP)
```

## Normalization

### Normal Forms

```text
Database Normalization:

1NF (First Normal Form):
├── Eliminate repeating groups
├── Create separate table for related data
├── Identify each row with primary key
└── Each cell contains single value

Example (SQL Server - PascalCase):
❌ Orders (Id, Item1, Item2, Item3)
✓ Orders (Id, ...) + OrderItems (OrderId, ItemId)

2NF (Second Normal Form):
├── Meet 1NF requirements
├── Remove partial dependencies
└── Non-key columns depend on entire primary key

Example (SQL Server - PascalCase):
❌ OrderItems (OrderId, ProductId, ProductName)
✓ OrderItems (OrderId, ProductId) + Products (ProductId, ProductName)

3NF (Third Normal Form):
├── Meet 2NF requirements
├── Remove transitive dependencies
└── Non-key columns depend only on primary key

Example (SQL Server - PascalCase):
❌ Orders (Id, CustomerId, CustomerCity)
✓ Orders (Id, CustomerId) + Customers (Id, City)

BCNF (Boyce-Codd Normal Form):
├── Meet 3NF requirements
├── Every determinant is a candidate key
└── Handles multi-valued dependencies

Higher Normal Forms (4NF, 5NF):
├── Handle complex multi-valued dependencies
├── Rarely used in practice
└── Can lead to over-normalization
```

### When to Denormalize

```text
Normalization Trade-offs:

Normalized (3NF):
├── Pros: Data integrity, no redundancy, smaller storage
├── Cons: Complex joins, slower reads
└── Use: OLTP, write-heavy workloads

Denormalized:
├── Pros: Faster reads, simpler queries
├── Cons: Redundancy, update anomalies, larger storage
└── Use: OLAP, read-heavy workloads

Denormalization Triggers:
1. Read performance is critical
2. Write frequency is low
3. Data changes infrequently
4. Queries frequently join same tables
5. Aggregations are common

Controlled Denormalization Patterns:
┌─────────────────────────────────────────────────────────────┐
│ Pattern: Summary Tables                                      │
│ Keep normalized + materialized aggregates                   │
│                                                              │
│  orders ──┐                                                 │
│  items  ──┼──► daily_sales_summary (materialized)          │
│  products─┘                                                 │
│                                                              │
│ Best of both: Write to normalized, read from summary        │
└─────────────────────────────────────────────────────────────┘
```

## Dimensional Modeling

### Star Schema

```text
Star Schema:
Central fact table surrounded by dimension tables.

                    ┌──────────────┐
                    │  dim_date    │
                    │──────────────│
                    │ date_key  PK │
                    │ date         │
                    │ month        │
                    │ quarter      │
                    │ year         │
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────┴───────┐    ┌──────────────┐
│ dim_product  │    │  fact_sales  │    │ dim_customer │
│──────────────│    │──────────────│    │──────────────│
│ product_key PK│◄──│ date_key  FK │───►│ customer_key PK│
│ product_name │    │ product_key FK│    │ customer_name│
│ category     │    │ customer_key FK│   │ segment      │
│ brand        │    │ store_key  FK │    │ region       │
└──────────────┘    │──────────────│    └──────────────┘
                    │ quantity     │
                    │ revenue      │           │
                    │ cost         │           │
                    └──────┬───────┘    ┌──────┴───────┐
                           │            │  dim_store   │
                           └───────────►│──────────────│
                                       │ store_key  PK│
                                       │ store_name   │
                                       │ city         │
                                       │ state        │
                                       └──────────────┘

Star Schema Benefits:
├── Simple queries (few joins)
├── Optimized for aggregation
├── Intuitive for business users
├── Works well with BI tools
└── Predictable query performance

Fact Table Types:
├── Transaction: One row per event (sale, click)
├── Periodic Snapshot: One row per period (daily balance)
├── Accumulating Snapshot: Track progress (order lifecycle)
└── Factless: Events without measures (attendance)
```

### Snowflake Schema

```text
Snowflake Schema:
Normalized dimensions (dimensions have sub-dimensions).

                    ┌──────────────┐
                    │  dim_date    │
                    └──────┬───────┘
                           │
┌──────────────┐    ┌──────┴───────┐    ┌──────────────┐
│ dim_category │◄───│ dim_product  │    │ dim_customer │
└──────────────┘    └──────┬───────┘    └──────┬───────┘
                           │                    │
        ┌──────────────────┼────────────────────┼──────┐
        │           ┌──────┴───────┐            │      │
        │           │  fact_sales  │            │      │
        │           └──────┬───────┘            │      │
        │                  │                    │      │
        │           ┌──────┴───────┐     ┌──────┴──────┐
        │           │  dim_store   │     │ dim_segment │
        │           └──────┬───────┘     └─────────────┘
        │                  │
        │           ┌──────┴───────┐
        │           │  dim_city    │
        │           └──────────────┘

Star vs Snowflake:
┌────────────────────────────────────────────────────────────┐
│ Factor          │ Star              │ Snowflake            │
├─────────────────┼───────────────────┼──────────────────────┤
│ Query simplicity│ Simpler           │ More complex         │
│ Query speed     │ Faster (fewer joins)│ Slower             │
│ Storage         │ More (redundancy) │ Less (normalized)    │
│ Maintenance     │ Easier            │ More complex         │
│ BI tool support │ Better            │ May need modeling    │
└────────────────────────────────────────────────────────────┘

Recommendation: Prefer star schema unless storage is critical concern.
```

### Slowly Changing Dimensions

```text
Slowly Changing Dimensions (SCD):
How to handle dimension changes over time.

Type 0: Retain Original
└── Never update dimension
└── Use for: Attributes that shouldn't change

Type 1: Overwrite
└── Update in place, lose history
└── Use for: Corrections, non-historical attributes

Type 2: Add New Row (Most Common)
┌─────────────────────────────────────────────────────────────┐
│ customer_key│ customer_id │ address      │ valid_from │ valid_to │ current│
├─────────────┼─────────────┼──────────────┼────────────┼──────────┼────────┤
│ 1001        │ C123        │ 123 Oak St   │ 2020-01-01 │ 2023-06-30│ false  │
│ 1002        │ C123        │ 456 Pine Ave │ 2023-07-01 │ 9999-12-31│ true   │
└─────────────────────────────────────────────────────────────┘
└── New surrogate key, track validity period
└── Use for: Full history required

Type 3: Add New Column
└── Previous and current value columns
└── Use for: Limited history (just previous)

Type 4: History Table
└── Current in main table, history in separate table
└── Use for: Frequent changes, large dimensions

Type 6: Hybrid (1+2+3)
└── Combines approaches for flexibility
└── Use for: Complex requirements
```

## Data Vault

### Data Vault Architecture

```text
Data Vault Modeling:
Enterprise data warehouse pattern for agility and auditability.

Components:
┌─────────────────────────────────────────────────────────────┐
│                         DATA VAULT                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  HUBS (Business Keys)                                       │
│  ┌────────────────────┐                                     │
│  │ hub_customer       │                                     │
│  │ ├── hub_key     PK │  ← Surrogate key                   │
│  │ ├── customer_id    │  ← Business key                    │
│  │ ├── load_date      │  ← When loaded                     │
│  │ └── source         │  ← Where from                      │
│  └────────────────────┘                                     │
│                                                              │
│  LINKS (Relationships)                                      │
│  ┌────────────────────┐                                     │
│  │ link_customer_order│                                     │
│  │ ├── link_key    PK │                                     │
│  │ ├── hub_customer_fk│                                     │
│  │ ├── hub_order_fk   │                                     │
│  │ ├── load_date      │                                     │
│  │ └── source         │                                     │
│  └────────────────────┘                                     │
│                                                              │
│  SATELLITES (Descriptive Data)                              │
│  ┌────────────────────┐                                     │
│  │ sat_customer_details│                                    │
│  │ ├── hub_customer_fk│                                     │
│  │ ├── load_date   PK │  ← Part of PK                      │
│  │ ├── name           │  ← Descriptive attributes          │
│  │ ├── email          │                                     │
│  │ ├── hash_diff      │  ← Change detection                │
│  │ └── source         │                                     │
│  └────────────────────┘                                     │
│                                                              │
└─────────────────────────────────────────────────────────────┘

Data Vault Benefits:
├── Full audit trail (all changes tracked)
├── Source system agnostic
├── Parallel loading possible
├── Handles schema changes gracefully
└── Good for regulatory requirements

Data Vault Challenges:
├── Complex queries (many joins)
├── Requires presentation layer
├── Steep learning curve
├── More storage than star schema
└── Not suitable for direct BI access
```

### When to Use Data Vault

```text
Data Vault Decision Matrix:

Use Data Vault When:
├── Multiple source systems with different schemas
├── Regulatory requirements for audit trails
├── Schema changes are frequent
├── Historical accuracy is critical
├── Large enterprise with complex data landscape
└── Data integration from acquisitions

Use Star Schema When:
├── Simpler reporting requirements
├── Single source system
├── Fast query performance priority
├── Business users query directly
├── Smaller scale, simpler needs
└── Quick time to value needed

Hybrid Approach:
┌─────────────────────────────────────────────────────────────┐
│                                                              │
│  Source ──► Data Vault ──► Star Schema ──► BI Tools         │
│  Systems    (Raw Vault)   (Presentation)  (Reports)         │
│                                                              │
│  Benefits:                                                   │
│  ├── Raw vault: Full history, audit                        │
│  ├── Star schema: Query performance                         │
│  └── Decoupled: Change raw without breaking reports         │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Schema Evolution

### Schema Evolution Patterns

```text
Schema Evolution Strategies:

1. Additive Changes (Safest)
   ├── Add new columns with defaults
   ├── Add new tables
   └── Add new indexes

   Safe: Does not break existing queries

   ALTER TABLE users ADD COLUMN phone VARCHAR(20) DEFAULT NULL;

2. Non-Breaking Changes
   ├── Widen column types (VARCHAR(50) → VARCHAR(100))
   ├── Remove NOT NULL constraint
   └── Add optional foreign keys

   Usually safe, verify with testing

3. Breaking Changes (Dangerous)
   ├── Rename columns/tables
   ├── Remove columns
   ├── Change column types
   └── Add NOT NULL without default

   Requires migration strategy

Migration Patterns:
┌─────────────────────────────────────────────────────────────┐
│ Pattern: Expand-Contract                                     │
│                                                              │
│ Phase 1 (Expand):                                           │
│ ├── Add new column (name_new)                               │
│ ├── Write to both old and new                               │
│ └── Backfill new column                                     │
│                                                              │
│ Phase 2 (Migrate):                                          │
│ ├── Update readers to use new column                        │
│ └── Verify all systems migrated                             │
│                                                              │
│ Phase 3 (Contract):                                         │
│ └── Remove old column                                       │
│                                                              │
│ Timeline: Days to weeks per phase                           │
└─────────────────────────────────────────────────────────────┘
```

### Versioning Strategies

```text
Schema Versioning:

1. Single Schema (Most Common)
   ├── One schema, evolve in place
   ├── Use migrations (Flyway, Liquibase)
   └── All applications use same version

2. Multi-Version Schema
   ├── Multiple schema versions exist
   ├── Applications specify version
   └── Complex but allows gradual migration

   Example: v1_users, v2_users

3. Event Sourcing
   ├── Store events, not state
   ├── Replay to any schema version
   └── Most flexible, most complex

   Events: UserCreated, UserNameChanged, UserDeleted
   → Replay to construct current state

Migration Tools:
┌────────────────────────────────────────────────────────────┐
│ Tool        │ Language   │ Approach                        │
├─────────────┼────────────┼─────────────────────────────────┤
│ Flyway      │ Java/SQL   │ SQL migrations, versioned       │
│ Liquibase   │ Java/XML   │ Changelog format, rollback      │
│ Alembic     │ Python     │ SQLAlchemy integration          │
│ Entity Framework│ .NET   │ Code-first migrations           │
│ Prisma      │ TypeScript │ Declarative schema              │
│ Atlas       │ Go         │ Declarative + imperative        │
└────────────────────────────────────────────────────────────┘
```

## Keys and Identifiers

### Primary Key Strategies

```text
Primary Key Options:

1. Natural Keys
   ├── Business identifier (email, SSN, ISBN)
   ├── Pros: Meaningful, unique in business
   ├── Cons: Can change, privacy concerns
   └── Use: When truly immutable

2. Surrogate Keys (Recommended)
   ├── Auto-increment integer
   ├── Pros: Simple, performant, stable
   ├── Cons: Meaningless, DB-specific
   └── Use: Most operational systems

3. UUIDs
   ├── Universally unique identifier
   ├── Pros: Globally unique, distributed generation
   ├── Cons: Larger, less performant
   └── Use: Distributed systems, external exposure

4. ULIDs / Snowflake IDs
   ├── Time-sortable unique identifiers
   ├── Pros: Sortable, unique, distributed
   ├── Cons: More complex generation
   └── Use: Time-series, event systems

Comparison:
┌────────────────────────────────────────────────────────────┐
│ Type          │ Size    │ Sortable │ Distributed │ Example │
├───────────────┼─────────┼──────────┼─────────────┼─────────┤
│ Auto-increment│ 4-8 bytes│ Yes     │ No          │ 12345   │
│ UUID v4       │ 16 bytes│ No       │ Yes         │ a1b2c...│
│ UUID v7       │ 16 bytes│ Yes      │ Yes         │ 0188... │
│ ULID          │ 16 bytes│ Yes      │ Yes         │ 01H5... │
│ Snowflake     │ 8 bytes │ Yes      │ Yes         │ 7890... │
└────────────────────────────────────────────────────────────┘
```

### Composite Keys

```text
Composite Keys:
Primary keys with multiple columns.

Use Cases:
├── Junction tables (many-to-many)
├── Time-series with partitioning
├── Multi-tenant systems
└── Natural business keys

Example: Order Items (SQL Server - PascalCase)
┌─────────────────────────────────────────────────────────────┐
│ OrderItems                                                   │
│ ├── OrderId     PK, FK                                      │
│ ├── LineNumber  PK       (composite with OrderId)           │
│ ├── ProductId   FK                                          │
│ ├── Quantity                                                │
│ └── Price                                                   │
└─────────────────────────────────────────────────────────────┘

Trade-offs:
├── Pros: Enforces uniqueness, natural ordering
├── Cons: Complex foreign keys, ORM challenges
└── Alternative: Surrogate key + unique constraint
```

## Best Practices

```text
Data Modeling Best Practices:

1. Understand the Use Case First
   ├── OLTP vs OLAP requirements
   ├── Query patterns expected
   ├── Write vs read ratio
   └── Growth expectations

2. Start Normalized, Denormalize with Reason
   ├── Begin with 3NF for operational
   ├── Denormalize only for proven performance needs
   ├── Document denormalization decisions
   └── Consider materialized views first

3. Use Consistent Naming (Database-Specific)
   ├── Singular table names (User, not Users)
   ├── SQL Server: PascalCase (CustomerId, OrderDate, CreatedAt)
   ├── PostgreSQL: snake_case (customer_id, order_date, created_at)
   ├── Foreign keys: {Entity}Id or {entity}_id per convention
   └── Avoid reserved words

4. Document Everything
   ├── Column descriptions
   ├── Relationship meanings
   ├── Business rules
   └── Change history

5. Plan for Change
   ├── Use surrogate keys
   ├── Design for schema evolution
   ├── Version your schemas
   └── Test migrations thoroughly

6. Consider Performance Early
   ├── Index strategy
   ├── Partitioning needs
   ├── Data types (smallest sufficient)
   └── Query patterns
```

## Anti-Patterns

```text
Data Modeling Anti-Patterns:

1. "One Table to Rule Them All"
   ❌ Single table with many nullable columns
   ✓ Proper entity separation

2. "Entity-Attribute-Value (EAV)"
   ❌ Generic key-value tables
   ✓ Proper columns or JSON fields

3. "CSV in a Column"
   ❌ Comma-separated values in one field
   ✓ Proper junction table

4. "Premature Denormalization"
   ❌ Denormalize without measuring
   ✓ Start normalized, optimize with data

5. "No Foreign Keys"
   ❌ Skipping FK for 'performance'
   ✓ Use FK for integrity, consider indexes

6. "Meaningless Names"
   ❌ table1, field_a, temp_data
   ✓ Descriptive, consistent naming
```

## Related Skills

- `data-architecture` - Data lake, lakehouse, data mesh
- `stream-processing` - Real-time data modeling
- `database-scaling` - Scaling data systems
- `etl-elt-patterns` - Data transformation
