# Pictographic Notation Guide

## Overview

Domain Storytelling uses a simple pictographic language to capture business processes. This guide documents the notation elements and conventions.

## Core Elements

### Actors

**Definition:** People or systems that perform activities in the story.

**Representation:**

```text
Human Actor:    🧑 or stick figure
System Actor:   🖥️ or box/rectangle
External Actor: 🌐 or cloud shape
```

**Naming Conventions:**

- Use roles, not names: "Sales Rep" not "John"
- Use singular form: "Customer" not "Customers"
- Be specific: "Warehouse Manager" not just "Employee"

**Actor Types:**

| Type | Description | Examples |
| --- | --- | --- |
| Internal Human | Employee of the organization | Sales Rep, Manager, Clerk |
| External Human | Person outside organization | Customer, Vendor, Auditor |
| Internal System | System owned by organization | Order System, CRM, ERP |
| External System | Third-party system | Payment Gateway, Shipping API |
| Time Trigger | Scheduled/time-based | Daily Scheduler, Month-End |

### Work Objects

**Definition:** Things that actors work with - documents, data, physical items.

**Representation:**

```text
Document:       📄 or rectangle with corner fold
Data:           🗃️ or cylinder (database)
Physical Item:  📦 or item icon
Reference:      📋 or list icon
```

**Naming Conventions:**

- Use business terms: "Order" not "OrderEntity"
- Include type hint if ambiguous: "Order (form)" vs "Order (record)"
- Be specific: "Customer Address" not just "Address"

**Work Object Types:**

| Type | Description | Examples |
| --- | --- | --- |
| Document | Paper or digital form | Order Form, Invoice, Contract |
| Data | Structured information | Customer Record, Order, Product |
| Reference | Read-only lookup | Product Catalog, Price List |
| Physical | Tangible item | Package, Product, Equipment |
| Message | Notification or request | Email, Alert, Request |

### Activities

**Definition:** Actions performed by actors, represented as labeled arrows.

**Representation:**

```text
Activity Arrow: Actor ──[verb phrase]──> Target

Examples:
  Customer ──[submits]──> Order Form
  Sales Rep ──[validates]──> Order Form
  System ──[creates]──> Order Record
```

**Naming Conventions:**

- Use active verbs: "submits", "validates", "creates"
- Present tense: "sends" not "sent"
- Third person: "reviews" not "review"

**Common Activity Verbs:**

| Category | Verbs |
| --- | --- |
| Create | creates, generates, submits, writes |
| Read | reads, views, checks, looks up |
| Update | updates, modifies, edits, changes |
| Delete | removes, cancels, voids, archives |
| Transfer | sends, forwards, routes, delivers |
| Transform | converts, calculates, processes |
| Decide | approves, rejects, validates, reviews |
| Notify | notifies, alerts, informs, confirms |

### Sequence Numbers

**Definition:** Numbers indicating the order of activities.

**Representation:**

```text
Circled numbers: ① ② ③ ④ ⑤ ⑥ ⑦ ⑧ ⑨ ⑩

For more than 10:
  ⑪ ⑫ ⑬ ⑭ ⑮ ⑯ ⑰ ⑱ ⑲ ⑳
  or use: (11) (12) (13)...
```

**Conventions:**

- Number activities sequentially
- Sub-steps use letters: ①a, ①b
- Alternative paths use same number with suffix: ③ vs ③'

### Annotations

**Definition:** Additional context, notes, or explanations.

**Representation:**

```text
Note:           💬 or callout shape
Question:       ❓ or question mark
Warning:        ⚠️ or exclamation
```

**When to Use:**

- Explain exceptions or special cases
- Note assumptions or uncertainties
- Document implicit knowledge
- Mark areas needing clarification

## Extended Notation

### Boundaries

**Definition:** Visual groupings that suggest organizational or system boundaries.

**Representation:**

```text
Dashed rectangle around related actors/activities:

┌─ ─ ─ ─ ─ ─ ─ ─ ─ ─┐
│  Sales Context     │
│  ① ② ③            │
└─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘
```

**Purpose:**

- Suggest bounded context candidates
- Show organizational boundaries
- Indicate system boundaries

### Parallel Activities

**Definition:** Activities that happen simultaneously.

**Representation:**

```text
Same sequence number:
  ③ Actor A ──[does X]──> Object
  ③ Actor B ──[does Y]──> Object

Or parallel notation:
  ③a Actor A ──[does X]──> Object
  ③b Actor B ──[does Y]──> Object
```

### Conditional Activities

**Definition:** Activities that depend on conditions.

**Representation:**

```text
Diamond decision point:
  ③ ◇ [condition?]
     │
     ├─ yes ─> ④ [action A]
     │
     └─ no ─> ④' [action B]
```

### Loops and Repetition

**Definition:** Activities that repeat.

**Representation:**

```text
Loop arrow:
  ③ ─[repeats until]─┐
     │               │
     └───────────────┘

Or annotation:
  ③ [action] 🔄 (repeats daily)
```

## Text Representation

For text-based documentation, use structured format:

### Numbered List Format

```markdown
① **Customer** submits **Order Form** to **Sales Rep**
② **Sales Rep** validates **Order Form** using **Product Catalog**
③ **Sales Rep** creates **Order** in **Order System**
④ **Order System** notifies **Warehouse** with **Pick List**
```

### Table Format

| Step | Actor | Activity | Work Object | Target |
| --- | --- | --- | --- | --- |
| ① | Customer | submits | Order Form | Sales Rep |
| ② | Sales Rep | validates | Order Form | (using Catalog) |
| ③ | Sales Rep | creates | Order | Order System |
| ④ | Order System | notifies | Pick List | Warehouse |

### Sentence Format

For narrative documentation:

```text
The Customer (①) submits an Order Form to the Sales Rep. The Sales Rep
(②) validates the Order Form by checking the Product Catalog, then (③)
creates an Order in the Order System. The Order System (④) automatically
notifies the Warehouse with a Pick List.
```

## Visual Diagram Tools

### ASCII Art

Simple text-based diagrams:

```text
  Customer          Sales Rep         Order System      Warehouse
     │                  │                  │                │
     │─① Order Form ─>│                  │                │
     │                  │─② validates ──>│                │
     │                  │<─ Product Cat ──│                │
     │                  │─③ creates ────>│                │
     │                  │                  │─④ Pick List ─>│
```

### Mermaid Sequence Diagrams

```text
sequenceDiagram
    participant C as Customer
    participant SR as Sales Rep
    participant OS as Order System
    participant W as Warehouse

    C->>SR: ① submits Order Form
    SR->>OS: ② validates (checks Product Catalog)
    SR->>OS: ③ creates Order
    OS->>W: ④ notifies with Pick List
```

### PlantUML Activity Diagrams

```text
@startuml
|Customer|
start
:① Submit Order Form;
|Sales Rep|
:② Validate Order Form;
:③ Create Order in System;
|Order System|
:④ Notify Warehouse;
|Warehouse|
:⑤ Pick Items;
stop
@enduml
```

## Anti-Patterns

### Too Technical

❌ "The OrderController receives the POST request and validates the DTO"

✅ "The Customer submits an Order Form to the Sales Rep"

### Too Abstract

❌ "Someone does something with the data"

✅ "The Warehouse Manager updates Inventory Levels in the Inventory System"

### Missing Sequence

❌ Unnumbered activities with unclear order

✅ Numbered sequence: ① ② ③ ④

### Mixed Levels

❌ Mixing system implementation details with business activities

✅ Consistent business-level language throughout

### Incomplete Stories

❌ Story ends abruptly without resolution

✅ Story has clear beginning, middle, and end

---

**Related:** `story-templates.md`, `boundary-discovery.md`
