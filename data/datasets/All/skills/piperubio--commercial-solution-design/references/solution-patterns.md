# Solution Patterns — Technology Consulting Engagements

Common solution architecture patterns organized by domain. Use this reference when mapping discovered pain points to consulting solution designs.

---

## Software Engineering Patterns

### Legacy Modernization

Migrate from monolithic or outdated architectures to modern, scalable systems.

**Sub-patterns**:
- **Lift-and-Shift**: Move workloads to cloud with minimal changes. Fastest, lowest risk, least benefit.
- **Re-platform**: Lift-and-shift plus targeted optimizations (managed databases, containers). Moderate effort, moderate benefit.
- **Re-architect (Strangler Fig)**: Gradually extract services from monolith. Highest effort, highest long-term benefit.

**Typical Phases and Duration**:
- Phase 0 — Assessment & architecture audit (2-3 weeks)
- Phase 1 — CI/CD setup + first extracted service or migrated workload (4-6 weeks)
- Phase 2 — Core services extraction / migration (8-16 weeks, iterative)
- Phase 3 — Optimization, decommission legacy components, KT (4-6 weeks)
- Total: 4-8 months

**Typical Team Composition**:
- Solution Architect (senior) — 1
- Senior Backend Engineers — 1-2
- DevOps/SRE Engineer — 1
- Optional: QA Engineer — 1
- Team size: 3-5

**Common Risks**:
- Hidden coupling in monolith delays extraction
- Legacy data models incompatible with new architecture
- Team resistance to new patterns and tooling
- Parallel operation of old and new systems increases operational burden

**Engagement Model Recommendation**: T&M or Hybrid (Phase 0 fixed, rest T&M). Scope evolves as legacy complexity is uncovered.

**Key Questions to Validate Applicability**:
- How old is the current system? What technologies?
- What is the deployment frequency today?
- Are there existing automated tests?
- What is the team's experience with microservices/cloud?
- Is there a hard deadline driving the migration?

---

### Custom Application Development (MVP → Iterate)

Build a new application from scratch, starting with an MVP and iterating.

**Typical Phases and Duration**:
- Phase 0 — Requirements validation & technical discovery (2-3 weeks)
- Phase 1 — MVP with core user flows (4-8 weeks)
- Phase 2 — Feature expansion, integrations (6-12 weeks)
- Phase 3 — Hardening, performance, KT (3-4 weeks)
- Total: 4-7 months

**Typical Team Composition**:
- Tech Lead (senior) — 1
- Full-stack or Backend Engineers — 1-3
- Frontend Engineer (if applicable) — 1
- Designer/UX (if applicable) — 0.5
- QA — 0.5-1
- Team size: 3-6

**Common Risks**:
- Scope creep from undefined requirements
- Stakeholder misalignment on MVP scope
- Integration complexity with third-party systems
- Underestimated UX/design effort

**Engagement Model Recommendation**: T&M for Phase 0-1 (scope discovery), then Fixed-Price for Phase 2 if scope stabilizes.

**Key Questions to Validate Applicability**:
- Is the product concept validated with users?
- What existing systems must this integrate with?
- What is the expected user volume at launch?
- Does the client have internal dev capacity for post-handoff maintenance?
- Are there regulatory or compliance requirements?

---

### API-First Platform Development

Build a platform with API as the primary interface, enabling integrations and ecosystem growth.

**Typical Phases and Duration**:
- Phase 0 — API strategy & domain modeling (2-3 weeks)
- Phase 1 — Core API design, auth, developer portal (4-6 weeks)
- Phase 2 — API implementation, integrations, rate limiting (6-10 weeks)
- Phase 3 — Documentation, SDK generation, KT (3-4 weeks)
- Total: 4-6 months

**Typical Team Composition**:
- Solution Architect (senior) — 1
- Backend Engineers — 2-3
- DevOps Engineer — 1
- Technical Writer — 0.5
- Team size: 3-5

**Common Risks**:
- API design changes late in development cascade through consumers
- Versioning strategy not defined upfront
- Security and rate-limiting underestimated
- Developer experience (DX) neglected

**Engagement Model Recommendation**: Hybrid — Phase 0 fixed, Phase 1-2 T&M, Phase 3 fixed.

**Key Questions to Validate Applicability**:
- Who are the API consumers (internal, partners, public)?
- What authentication/authorization model is needed?
- What throughput and latency requirements exist?
- Is there an existing API to evolve or is this greenfield?

---

### DevOps / CI-CD Transformation

Establish or mature CI/CD pipelines, infrastructure automation, and DevOps practices.

**Typical Phases and Duration**:
- Phase 0 — Current state assessment & DevOps maturity audit (2-3 weeks)
- Phase 1 — CI pipeline, automated testing foundation (3-4 weeks)
- Phase 2 — CD pipeline, IaC, monitoring & alerting (4-8 weeks)
- Phase 3 — Team enablement, runbook creation, KT (2-3 weeks)
- Total: 3-5 months

**Typical Team Composition**:
- DevOps/SRE Lead (senior) — 1
- DevOps Engineer — 1-2
- Optional: Backend Engineer for test automation — 1
- Team size: 2-4

**Common Risks**:
- Legacy infrastructure not automatable without refactoring
- Team adoption resistance to new workflows
- Security/compliance constraints on pipeline design
- Insufficient test coverage makes CD risky

**Engagement Model Recommendation**: T&M. Scope depends heavily on current maturity and tooling.

**Key Questions to Validate Applicability**:
- What is the current deployment frequency and process?
- What CI/CD tools are in use, if any?
- What is the current test coverage?
- Are there compliance requirements for deployments (audit trails, approvals)?
- Cloud or on-prem? Multi-environment?

---

### Technical Debt Remediation

Systematically address accumulated technical debt to restore development velocity.

**Typical Phases and Duration**:
- Phase 0 — Tech debt audit & prioritization (2-3 weeks)
- Phase 1 — Critical debt items (security, stability) (4-6 weeks)
- Phase 2 — High-impact debt items (velocity blockers) (6-10 weeks)
- Phase 3 — Process improvements to prevent reaccumulation, KT (2-3 weeks)
- Total: 3-6 months

**Typical Team Composition**:
- Tech Lead / Architect (senior) — 1
- Senior Engineers — 1-2
- QA Engineer — 0.5-1
- Team size: 2-4

**Common Risks**:
- Debt items larger than estimated once investigated
- Fixing debt introduces regressions
- Business pressure to stop remediation and ship features
- Debt is symptomatic of process issues that persist after remediation

**Engagement Model Recommendation**: T&M. Debt scope is inherently uncertain until investigated.

**Key Questions to Validate Applicability**:
- What are the top 3 pain points caused by tech debt?
- Is there automated test coverage to catch regressions?
- Does the team have time allocated for remediation, or is it competing with feature work?
- Is this a one-time cleanup or an ongoing improvement program?

---

## Data Platform Patterns

### Data Warehouse Modernization (On-Prem → Cloud)

Migrate from on-premises data warehouses to cloud-based solutions.

**Typical Phases and Duration**:
- Phase 0 — Data landscape assessment & migration strategy (2-4 weeks)
- Phase 1 — Cloud infrastructure setup, first data domain migrated (4-6 weeks)
- Phase 2 — Remaining data domains, ETL/ELT pipeline migration (8-14 weeks)
- Phase 3 — Reporting migration, optimization, KT (4-6 weeks)
- Total: 5-8 months

**Typical Team Composition**:
- Data Architect (senior) — 1
- Data Engineers — 1-3
- BI/Analytics Engineer — 1
- Optional: DevOps/DataOps — 0.5
- Team size: 3-5

**Common Risks**:
- Data quality issues surfaced during migration
- Legacy ETL logic undocumented or overly complex
- Downstream report breakage during cutover
- Licensing and cost model surprises in cloud

**Engagement Model Recommendation**: Hybrid — Phase 0 fixed, Phases 1-3 T&M. Data migrations always uncover surprises.

**Key Questions to Validate Applicability**:
- What is the current data warehouse technology and size?
- How many data sources feed into it?
- What BI tools are in use downstream?
- Are there data governance or compliance requirements (GDPR, HIPAA)?
- Is there a preferred cloud provider?

---

### Data Lake / Lakehouse Implementation

Build a data lake or lakehouse architecture for centralized, scalable data storage and analytics.

**Typical Phases and Duration**:
- Phase 0 — Data strategy & architecture design (2-3 weeks)
- Phase 1 — Lakehouse infrastructure, ingestion framework, first sources (4-8 weeks)
- Phase 2 — Additional sources, transformation layer, data catalog (6-12 weeks)
- Phase 3 — Self-service access, governance, KT (3-5 weeks)
- Total: 4-7 months

**Typical Team Composition**:
- Data Architect (senior) — 1
- Data Engineers — 2-3
- Analytics Engineer — 0.5-1
- DataOps / DevOps — 0.5
- Team size: 3-5

**Common Risks**:
- "Data swamp" if governance not established early
- Source system access delays
- Schema evolution challenges
- Performance issues with large-scale queries

**Engagement Model Recommendation**: T&M. Scope evolves as data sources are onboarded.

**Key Questions to Validate Applicability**:
- What use cases will the lakehouse serve (analytics, ML, reporting)?
- How many and what types of data sources?
- What data volumes and velocity?
- Is there a preferred cloud platform?
- What is the team's experience with distributed data systems?

---

### ETL/ELT Pipeline Development

Build or refactor data pipelines for extraction, transformation, and loading.

**Typical Phases and Duration**:
- Phase 0 — Pipeline audit & requirements (1-2 weeks)
- Phase 1 — Pipeline framework, first 2-3 pipelines (3-5 weeks)
- Phase 2 — Remaining pipelines, error handling, monitoring (4-8 weeks)
- Phase 3 — Documentation, operational handoff, KT (2-3 weeks)
- Total: 3-5 months

**Typical Team Composition**:
- Data Engineer Lead (senior) — 1
- Data Engineers — 1-2
- Team size: 2-3

**Common Risks**:
- Source system API instability or rate limits
- Data quality issues requiring transformation rework
- Pipeline scheduling conflicts and dependencies
- Monitoring gaps leading to silent failures

**Engagement Model Recommendation**: Fixed-Price per pipeline batch if scope is clear. T&M otherwise.

**Key Questions to Validate Applicability**:
- How many source systems and target destinations?
- What is the data freshness requirement (real-time, hourly, daily)?
- Are there existing pipelines to refactor or is this greenfield?
- What orchestration tools are in use or preferred?

---

### Business Intelligence & Dashboarding

Implement BI solutions and self-service analytics capabilities.

**Typical Phases and Duration**:
- Phase 0 — Analytics requirements & data model review (2-3 weeks)
- Phase 1 — Data model, core dashboards (3-6 weeks)
- Phase 2 — Advanced analytics, self-service enablement (4-8 weeks)
- Phase 3 — Training, adoption support, KT (2-3 weeks)
- Total: 3-5 months

**Typical Team Composition**:
- Analytics/BI Lead (senior) — 1
- BI Developer — 1-2
- Data Engineer (for data model support) — 0.5
- Team size: 2-3

**Common Risks**:
- Stakeholder disagreement on metrics definitions
- Data model not ready for analytics use cases
- Low adoption if UX and training are neglected
- Scope creep from "one more dashboard" requests

**Engagement Model Recommendation**: Fixed-Price for defined dashboard set. T&M for self-service enablement.

**Key Questions to Validate Applicability**:
- What BI tools are currently in use?
- How are reports produced today (manual, automated)?
- Who are the primary dashboard consumers?
- Is the underlying data model analytics-ready?
- What are the top 5 questions the business needs answered?

---

### Data Governance & Quality Framework

Establish data governance policies, data quality monitoring, and stewardship processes.

**Typical Phases and Duration**:
- Phase 0 — Governance maturity assessment (2-3 weeks)
- Phase 1 — Governance framework, data catalog, ownership model (4-6 weeks)
- Phase 2 — Quality monitoring, lineage, policy enforcement (4-8 weeks)
- Phase 3 — Training, stewardship rollout, KT (2-3 weeks)
- Total: 3-5 months

**Typical Team Composition**:
- Data Governance Lead / Architect (senior) — 1
- Data Engineer — 1
- Analyst / Stewardship coordinator — 0.5
- Team size: 2-3

**Common Risks**:
- Organizational resistance to governance processes
- Unclear data ownership across departments
- Tooling overinvestment without process adoption
- Governance seen as bureaucracy rather than enablement

**Engagement Model Recommendation**: T&M. Governance is as much organizational as technical.

**Key Questions to Validate Applicability**:
- Is there an existing data governance function or is this new?
- What regulatory requirements apply (GDPR, HIPAA, SOX)?
- How is data quality measured today?
- Who owns data assets currently?

---

## AI/ML Patterns

### ML Model Development Lifecycle (POC → Production)

Take an ML use case from proof-of-concept through production deployment.

**Typical Phases and Duration**:
- Phase 0 — Use case validation & data assessment (2-3 weeks)
- Phase 1 — Data preparation, feature engineering, POC model (4-6 weeks)
- Phase 2 — Model iteration, evaluation, production pipeline (6-10 weeks)
- Phase 3 — Deployment, monitoring, KT (3-4 weeks)
- Total: 4-6 months

**Typical Team Composition**:
- ML Engineer / Data Scientist Lead (senior) — 1
- ML Engineer / Data Scientist — 1-2
- Data Engineer (for pipeline support) — 0.5-1
- MLOps / DevOps — 0.5
- Team size: 3-4

**Common Risks**:
- Data insufficient or too noisy for the use case
- POC results do not transfer to production data
- Model performance expectations misaligned with reality
- Production serving infrastructure complexity underestimated

**Engagement Model Recommendation**: Outcome-Based or Hybrid. Define POC success criteria upfront; Phase 0-1 T&M, Phase 2-3 outcome-linked if POC validates.

**Key Questions to Validate Applicability**:
- What business decision will the model inform?
- Is labeled training data available?
- What is the current baseline (human or rule-based)?
- What latency and throughput requirements for serving?
- Is there an existing ML infrastructure?

---

### NLP / Document Processing Automation

Automate text extraction, classification, summarization, or document processing workflows.

**Typical Phases and Duration**:
- Phase 0 — Document corpus analysis & requirements (2-3 weeks)
- Phase 1 — Pipeline setup, initial model/LLM integration (4-6 weeks)
- Phase 2 — Accuracy tuning, edge case handling, workflow integration (4-8 weeks)
- Phase 3 — Production deployment, monitoring, KT (2-4 weeks)
- Total: 3-5 months

**Typical Team Composition**:
- ML Engineer / NLP Specialist (senior) — 1
- Backend Engineer — 1
- Data Engineer (if pipeline-heavy) — 0.5
- Team size: 2-3

**Common Risks**:
- Document variability higher than expected
- Accuracy requirements difficult to meet for edge cases
- LLM cost/latency trade-offs in production
- Integration with document management systems

**Engagement Model Recommendation**: Hybrid — Phase 0 fixed, Phase 1-2 T&M with accuracy milestones.

**Key Questions to Validate Applicability**:
- What document types and volumes?
- What accuracy is acceptable vs. human review?
- Is structured output required (JSON, database)?
- Are there regulatory constraints on automated decisions?
- LLM usage acceptable, or must models be on-premise?

---

### Computer Vision Applications

Build image or video analysis solutions for inspection, detection, classification, or tracking.

**Typical Phases and Duration**:
- Phase 0 — Image/video data assessment & feasibility (2-3 weeks)
- Phase 1 — Data labeling, model training POC (4-8 weeks)
- Phase 2 — Model refinement, edge deployment or API (6-10 weeks)
- Phase 3 — Production integration, monitoring, KT (3-4 weeks)
- Total: 4-7 months

**Typical Team Composition**:
- CV / ML Engineer Lead (senior) — 1
- ML Engineer — 1-2
- Data Engineer / Backend Engineer — 0.5-1
- Team size: 2-4

**Common Risks**:
- Insufficient or biased training data
- Edge deployment hardware constraints
- Lighting/environment variability in production
- Labeling cost and time underestimated

**Engagement Model Recommendation**: Outcome-Based if success criteria are measurable (accuracy, detection rate). T&M for exploratory/research-heavy engagements.

**Key Questions to Validate Applicability**:
- What is the visual task (detection, classification, segmentation)?
- Is labeled data available? How much?
- Where will inference run (cloud, edge, mobile)?
- What is the real-time requirement?
- What is the consequence of a wrong prediction?

---

### Recommendation Systems

Build personalized recommendation engines for content, products, or actions.

**Typical Phases and Duration**:
- Phase 0 — Data assessment & strategy (2-3 weeks)
- Phase 1 — Baseline model, A/B testing framework (4-6 weeks)
- Phase 2 — Advanced models, real-time serving (6-10 weeks)
- Phase 3 — Optimization, KT (2-4 weeks)
- Total: 4-6 months

**Typical Team Composition**:
- ML Engineer Lead (senior) — 1
- ML Engineer — 1
- Backend Engineer (for serving layer) — 1
- Data Engineer — 0.5
- Team size: 3-4

**Common Risks**:
- Cold start problem for new users/items
- Data sparsity limiting model quality
- A/B testing infrastructure not in place
- Filter bubbles and fairness concerns

**Engagement Model Recommendation**: Outcome-Based tied to engagement/conversion metrics. Phase 0 T&M.

**Key Questions to Validate Applicability**:
- What is being recommended (products, content, actions)?
- What interaction data is available (clicks, purchases, ratings)?
- What is the catalog size?
- Is real-time recommendation required?
- Is there an existing A/B testing framework?

---

### MLOps Implementation

Establish infrastructure and processes for ML model lifecycle management in production.

**Typical Phases and Duration**:
- Phase 0 — MLOps maturity assessment (2-3 weeks)
- Phase 1 — Experiment tracking, model registry, CI/CD for ML (4-6 weeks)
- Phase 2 — Automated training pipelines, monitoring, feature store (6-10 weeks)
- Phase 3 — Team enablement, process documentation, KT (2-4 weeks)
- Total: 4-6 months

**Typical Team Composition**:
- MLOps / ML Platform Engineer Lead (senior) — 1
- ML Engineer — 1
- DevOps / Infrastructure Engineer — 1
- Team size: 2-3

**Common Risks**:
- Over-engineering platform before use cases justify it
- Tool proliferation without clear integration strategy
- Team adoption of new workflows
- Underestimating data pipeline complexity

**Engagement Model Recommendation**: T&M. MLOps scope evolves with organizational ML maturity.

**Key Questions to Validate Applicability**:
- How many ML models are in production today?
- What is the current model deployment process?
- What tools are in use (notebooks, experiment tracking, orchestration)?
- How often do models need retraining?
- Is there a dedicated ML platform team?

---

## Cross-cutting Patterns

### Team Augmentation (T&M / Staff-Aug-Plus)

Embed consultants into an existing client team to accelerate delivery.

**Typical Phases and Duration**:
- Phase 0 — Onboarding & codebase ramp-up (1-2 weeks)
- Ongoing — Sprint-based delivery alongside client team (3-12+ months)
- Exit — Knowledge transfer, documentation (1-2 weeks)
- Total: 3-12+ months (often open-ended)

**Typical Team Composition**:
- Engineers at requested seniority levels — 1-10
- Optional: embedded Tech Lead — 1
- Team size: varies per need

**Common Risks**:
- Treated as "body shop" without strategic impact
- Slow onboarding due to poor documentation
- Dependency on consultant without KT plan
- Scope/role ambiguity

**Engagement Model Recommendation**: T&M with monthly reviews. Staff-Aug-Plus includes a Tech Lead for coaching and quality.

**Key Questions to Validate Applicability**:
- What roles and seniority levels are needed?
- What is the expected duration?
- How mature is the client's development process?
- Is the goal capacity (more hands) or capability (new skills)?
- What does the offboarding/KT expectation look like?

---

### Assessment & Roadmap (2-4 Week Diagnostic)

Conduct a time-boxed assessment of a specific domain and produce a prioritized roadmap.

**Typical Phases and Duration**:
- Week 1 — Stakeholder interviews, documentation review
- Week 2 — Technical deep-dive, current state analysis
- Week 3 — Findings synthesis, roadmap drafting
- Week 4 — Presentation, recommendations, prioritization
- Total: 2-4 weeks

**Typical Team Composition**:
- Senior Consultant / Architect — 1
- Supporting Analyst or Engineer — 0.5-1
- Team size: 1-2

**Common Risks**:
- Stakeholder unavailability delays interviews
- Scope of assessment too broad for the time box
- Recommendations ignored without executive sponsorship
- Assessment becomes a "shelf study"

**Engagement Model Recommendation**: Fixed-Price. Well-defined scope and deliverables.

**Key Questions to Validate Applicability**:
- What domain is being assessed (architecture, data, DevOps, security)?
- Who are the key stakeholders to interview?
- What decisions will the assessment inform?
- Is there executive sponsorship for acting on recommendations?

---

### Proof of Concept (Time-Boxed Validation)

Validate a technical approach or hypothesis with a bounded POC before committing to a full engagement.

**Typical Phases and Duration**:
- Week 1 — Define success criteria, set up environment
- Week 2-3 — Build POC, iterate
- Week 4 — Evaluate, document findings, present recommendation
- Total: 2-4 weeks

**Typical Team Composition**:
- Senior Engineer or ML Engineer — 1
- Supporting Engineer — 0.5-1
- Team size: 1-2

**Common Risks**:
- POC scope creeps into prototype
- Success criteria not defined upfront
- POC uses shortcuts that do not transfer to production
- Go/no-go decision not made after POC

**Engagement Model Recommendation**: Fixed-Price with defined success criteria and go/no-go gate.

**Key Questions to Validate Applicability**:
- What hypothesis is being validated?
- What are the measurable success criteria?
- What happens after a successful POC?
- Is the data/environment available for the POC?
- What is the maximum acceptable investment if the POC fails?

---

### Training & Enablement (Workshops + Pairing)

Upskill client teams through structured training, workshops, and pair programming.

**Typical Phases and Duration**:
- Phase 0 — Skills assessment, curriculum design (1-2 weeks)
- Phase 1 — Workshop delivery (1-2 weeks)
- Phase 2 — Pair programming / embedded coaching (2-6 weeks)
- Phase 3 — Assessment, certification, follow-up plan (1 week)
- Total: 1-3 months

**Typical Team Composition**:
- Senior Consultant / Trainer — 1
- Supporting Engineer for pairing — 0.5-1
- Team size: 1-2

**Common Risks**:
- Team members pulled from training for urgent work
- Training content too generic or too advanced
- No follow-up mechanism to reinforce learning
- Manager expectations vs. realistic skill development timeline

**Engagement Model Recommendation**: Fixed-Price per training program. T&M for extended pairing engagements.

**Key Questions to Validate Applicability**:
- What skills need to be developed?
- What is the current skill level of the team?
- How many people need training?
- Is hands-on pairing needed, or are workshops sufficient?
- What is the follow-up plan to reinforce learning?
