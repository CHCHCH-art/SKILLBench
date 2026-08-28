# Estimation Guide — Technology Consulting Engagements

## Estimation Principles

1. **Estimate in ranges, not points**: Always provide optimistic-realistic-pessimistic (O-R-P) or +/-% ranges.
2. **Bottom-up validates top-down**: T-shirt size first, then validate with phase-level breakdown.
3. **Include non-coding work**: Meetings, documentation, reviews, deployments, KT account for 25-35% of total effort.
4. **Buffer by uncertainty**: Add contingency based on information quality:
   - High confidence (Phase 0 done): +10-15%
   - Medium confidence (discovery done): +20-30%
   - Low confidence (pre-discovery): +40-50%

## Common Estimation Pitfalls
- **Integration underestimation**: Connecting to existing systems always takes 2-3x longer than expected
- **Data migration complexity**: Data is always messier than described
- **Stakeholder availability**: Factor in waiting time for client decisions and reviews
- **Environment setup**: New environments, access, VPNs, onboarding eat first 1-2 weeks
- **Testing gap**: Clients often lack test environments or test data

## Effort Benchmarks by Service Type

### Architecture Modernization
- Assessment: 80-160h (2-4 weeks, 1-2 people)
- Strangler fig extraction per service: 120-240h (3-6 weeks, 2-3 people)
- CI/CD pipeline setup: 80-160h (2-4 weeks, 1-2 people)
- Monitoring/observability setup: 60-120h (2-3 weeks, 1-2 people)
- Full modernization program: 600-2000h (3-12 months, 3-6 people)

### Data Platform Build
- Data strategy & assessment: 60-120h (2-3 weeks, 1-2 people)
- Data warehouse/lake setup: 200-400h (1-3 months, 2-3 people)
- ETL/ELT pipeline (per source): 40-80h per data source
- BI/Dashboard implementation: 120-240h (1-2 months, 1-2 people)
- Data governance framework: 80-160h (2-4 weeks, 1-2 people)
- Full data platform: 500-1500h (3-9 months, 3-5 people)

### AI/ML Enablement
- ML strategy & use case assessment: 60-120h (2-3 weeks, 1-2 people)
- MLOps platform setup: 200-400h (1-3 months, 2-3 people)
- Model development (per use case): 160-400h (1-3 months, 1-2 people)
- Production deployment (per model): 80-160h (2-4 weeks, 1-2 people)
- Full AI enablement program: 600-2000h (3-12 months, 3-6 people)

### Cloud Migration
- Assessment & planning: 80-160h (2-4 weeks, 1-2 people)
- Per workload migration: 40-160h depending on complexity
- Infrastructure as Code setup: 120-240h (1-2 months, 1-2 people)
- Full cloud migration: 400-2000h (3-12 months, 2-6 people)

## Blended Rate Calculation

Blended rate = weighted average of team rates:
- Principal/Partner: $250-350/hr
- Senior Consultant: $180-250/hr
- Consultant: $120-180/hr
- Analyst/Junior: $80-120/hr

Example for a team of 1 Senior ($200) + 2 Mid ($150) + 1 Junior ($100):
Blended = (200 + 150 + 150 + 100) / 4 = $150/hr

Note: Rates are illustrative. Actual rates depend on geography, market, and client relationship. Always confirm with user before including in proposals.

## Non-Billable Effort Multiplier

Add 25-35% for non-billable activities:
- Internal meetings and coordination: 5-10%
- Documentation and reporting: 5-10%
- Code review and quality: 5-8%
- Environment and tooling: 3-5%
- Knowledge transfer (ongoing): 3-5%
- Contingency/buffer: 5-10%

Example: If billable work = 400h, total engagement = 400 x 1.30 = 520h
