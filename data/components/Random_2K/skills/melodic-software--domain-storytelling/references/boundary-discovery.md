# Boundary Discovery from Domain Stories

## Overview

Domain stories reveal natural boundaries in business processes. This guide explains how to identify bounded context candidates from collected stories.

## Discovery Signals in Stories

### Language Patterns

**Same term, different meaning:**

When actors use the same word differently:

```text
Story 1 (Sales):
  "Customer places Order"
  Order = request from buyer, may be modified/cancelled

Story 2 (Warehouse):
  "Pick items for Order"
  Order = confirmed instruction, immutable

Story 3 (Billing):
  "Invoice for Order"
  Order = financial record, basis for payment
```

**Different terms, same concept:**

When different actors use different words for the same thing:

```text
Sales: "Quote"
Customer: "Estimate"
Finance: "Proposal"
→ All refer to the same concept
```

**These language boundaries often indicate context boundaries.**

### Actor Clustering

Groups of actors that work closely together often belong to the same context:

```text
Cluster A (Sales Context):
  - Customer
  - Sales Rep
  - Sales Manager

Cluster B (Fulfillment Context):
  - Warehouse Staff
  - Shipping Coordinator
  - Carrier

Cluster C (Finance Context):
  - Accountant
  - Billing Clerk
  - CFO
```

### Work Object Ownership

Where work objects are created, modified, and consumed suggests boundaries:

```text
Order Form
  Created: Sales Context
  Modified: Sales Context
  Consumed: Fulfillment Context

Pick List
  Created: Fulfillment Context
  Modified: Fulfillment Context
  Consumed: (internal only)
```

### Handoff Points

Where work flows between actors/systems:

```text
① Customer → Sales Rep          (Sales Context)
② Sales Rep → Order System      (Sales Context)
③ Order System → Warehouse      ← HANDOFF POINT
④ Warehouse Staff → Inventory   (Fulfillment Context)
⑤ Warehouse → Shipping          (Fulfillment Context)
```

**Handoff points are strong boundary candidates.**

## Analysis Process

### Step 1: Map Actor Groups

From stories, group actors that:

- Communicate frequently
- Share vocabulary
- Work on same work objects
- Have similar responsibilities

```markdown
## Actor Groups

### Group: Sales
- Customer (external)
- Sales Rep
- Sales Manager
- Order System (primary)

### Group: Fulfillment
- Warehouse Staff
- Warehouse Manager
- Inventory System
- Shipping Coordinator

### Group: Finance
- Billing Clerk
- Accountant
- Billing System
```

### Step 2: Identify Language Boundaries

Note where terminology changes:

```markdown
## Language Analysis

| Concept | Sales Term | Fulfillment Term | Finance Term |
| --- | --- | --- | --- |
| Customer request | Order | Shipment | Invoice |
| Product | Item | SKU | Line Item |
| Location | (not used) | Warehouse | Cost Center |
| Status | Order Status | Shipment Status | Payment Status |
```

### Step 3: Trace Work Object Flow

Map how work objects move through the story:

```markdown
## Work Object Flow

Order Form:
  Sales → (transforms to) → Order Record

Order Record:
  Sales → (published as) → Shipment Request

Shipment Request:
  → Fulfillment (creates) → Pick List
  → Fulfillment (creates) → Shipping Label

Shipping Confirmation:
  Fulfillment → Finance (creates) → Invoice
```

### Step 4: Mark Handoff Points

Identify where work crosses actor groups:

```markdown
## Handoff Analysis

1. Customer → Sales Rep
   - Within Sales context
   - No context boundary

2. Sales Rep → Order System
   - Within Sales context
   - No context boundary

3. Order System → Warehouse System ← BOUNDARY
   - Cross-context handoff
   - Work object transformation (Order → Shipment)
   - Language shift

4. Warehouse → Shipping
   - Within Fulfillment context
   - No context boundary

5. Shipping → Billing System ← BOUNDARY
   - Cross-context handoff
   - Work object transformation (Shipment → Invoice)
```

### Step 5: Propose Context Boundaries

Based on analysis:

```markdown
## Proposed Bounded Contexts

### Sales Context
**Actors:** Customer, Sales Rep, Sales Manager
**Systems:** Order System, CRM
**Work Objects:** Order Form, Quote, Order
**Language:** Customer, Order, Quote, Discount, Approval

### Fulfillment Context
**Actors:** Warehouse Staff, Warehouse Manager, Shipping Coordinator
**Systems:** Inventory System, Warehouse Management
**Work Objects:** Pick List, Shipment, Tracking Number
**Language:** SKU, Location, Pick, Pack, Ship, Carrier

### Finance Context
**Actors:** Billing Clerk, Accountant
**Systems:** Billing System, ERP
**Work Objects:** Invoice, Payment, Credit
**Language:** Line Item, Tax, Payment Terms, Receivable
```

## Context Boundary Validation

### Checklist

For each proposed boundary:

- [ ] Language is consistent within the context
- [ ] Actors primarily interact within the context
- [ ] Work objects have clear ownership
- [ ] Handoffs at boundaries are well-defined
- [ ] Team ownership is assignable

### Questions to Ask

1. "Could a single team own this context?"
2. "Does the language remain consistent throughout?"
3. "Are the integration points at the boundary clear?"
4. "Would splitting this make things simpler or more complex?"

## Context Relationships

### Identifying Relationships

From handoff analysis, determine relationship types:

```markdown
## Context Relationships

Sales → Fulfillment
  Type: Customer-Supplier
  Direction: Sales upstream, Fulfillment downstream
  Integration: Order → Shipment Request event

Fulfillment → Finance
  Type: Customer-Supplier
  Direction: Fulfillment upstream, Finance downstream
  Integration: Shipment Complete → Invoice Trigger
```

### Common Relationship Patterns

| Pattern | Description | From Stories |
| --- | --- | --- |
| **Customer-Supplier** | One context serves another | Clear producer/consumer in handoffs |
| **Partnership** | Contexts evolve together | Frequent bidirectional communication |
| **Shared Kernel** | Common model subset | Same work objects with identical meaning |
| **Conformist** | Downstream adapts to upstream | No negotiation in handoff format |
| **ACL** | Protection layer | Translation happening at boundary |

## Integration with Event Storming

### Feeding into Event Storming

Story elements map to event storming elements:

| Story Element | Event Storm Element |
| --- | --- |
| Activity (verb) | Command or Event |
| Handoff point | Context boundary |
| Work object creation | Event (past tense of activity) |
| Actor | Actor (yellow sticky) |
| Annotation | Hot spot (if question/issue) |

### Example Transformation

```text
Story Step:
  ③ Sales Rep creates Order in Order System

Event Storm:
  🟦 Create Order (command)
  🟨 Sales Rep (actor)
  🟨 Order (aggregate)
  🟧 Order Created (event)
```

## Documentation Output

### Context Discovery Report

````markdown
# Bounded Context Discovery Report

**Domain:** [Domain Name]
**Stories Analyzed:** [List of stories]
**Date:** YYYY-MM-DD

## Discovered Contexts

### Context 1: [Name]

**Type:** Core Domain | Supporting | Generic

**Boundaries:**

- Actors: [List]
- Systems: [List]
- Work Objects: [List]

**Ubiquitous Language:**

| Term | Definition |
| --- | --- |
| [Term] | [Definition in this context] |

**Upstream Of:** [Contexts]
**Downstream Of:** [Contexts]

### Context 2: [Name]

...

## Context Map

```text
[ASCII or Mermaid diagram showing relationships]
```

## Integration Points

| Upstream | Downstream | Mechanism | Data Exchanged |
| --- | --- | --- | --- |
| [Context] | [Context] | Event/API/File | [Description] |

## Open Questions

- [Question requiring further analysis]

## Recommendations

1. [Recommendation based on findings]
````

## Anti-Patterns

### Premature Boundaries

**Problem:** Drawing boundaries before understanding stories fully.

**Fix:** Collect multiple stories, look for recurring patterns.

### One Context per Actor

**Problem:** Creating a context for each actor type.

**Fix:** Contexts group related actors and work objects, not individual actors.

### Ignoring Language

**Problem:** Focusing only on systems/data, not terminology.

**Fix:** Language differences are primary boundary indicators.

### Too Fine-Grained

**Problem:** Every process step becomes its own context.

**Fix:** Look for meaningful cohesion - contexts that make sense as deployable units.

### Too Coarse

**Problem:** Everything in one context to "keep it simple."

**Fix:** If language/ownership differs significantly, split.

---

**Related:** `pictographic-notation.md`, `story-templates.md`, `bounded-context-discovery.md` (in event-storming skill)
