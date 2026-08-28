---
name: parallel-build-metrics-analyzer
description: Analyzes parallel build performance metrics including speedup ratio (parallel vs sequential), module build times, iteration counts, wait times, and resource utilization. Identifies bottlenecks (slowest modules, excessive iterations, dependency chains), calculates parallel efficiency, and suggests optimizations (better module boundaries, caching, pre-computation). Generates performance reports comparing runs over time. Use after parallel builds complete, when analyzing build performance, identifying optimization opportunities, or measuring RAD system effectiveness.
allowed-tools: Read, Write, Bash
---

# Parallel Build Metrics Analyzer

You analyze parallel build performance metrics to identify bottlenecks, measure effectiveness, and suggest optimizations for future builds.

## When to use
- After parallel build completes (post-mortem analysis)
- Comparing parallel vs sequential performance
- Identifying bottleneck modules (slowest, most failures)
- Tracking build performance trends over time
- Optimizing build strategies for future features

## Purpose

**Problem**: Don't know if parallel strategy was effective. Can't identify bottlenecks. No data to improve future builds.

**Solution**: Analyze timing, iterations, failures. Measure speedup. Identify slow modules. Suggest optimizations.

**Benefits**:
- Know what's working (celebrate wins)
- Know what's not (fix bottlenecks)
- Data-driven optimization
- Continuous improvement
- Better estimates for future builds

## Metrics tracked

### 1. Build timing metrics
- Total parallel build time
- Sequential equivalent time
- Actual speedup (Nx faster)
- Time per module
- Time per phase
- Bottleneck modules (longest duration)

### 2. Validation metrics
- Iterations per module (1, 2, or 3)
- Tests passed/failed per module
- Common failure types
- Time spent in validation loops

### 3. Efficiency metrics
- Parallelization efficiency (actual vs theoretical speedup)
- Idle time (modules waiting for slower modules)
- Overhead time (coordination, integration)

### 4. Quality metrics
- Integration conflicts found
- Integration test failures
- Code quality issues
- Security issues

## Analysis output

```markdown
# Parallel Build Performance Analysis

**Feature**: User Authentication
**Build Date**: 2025-01-25 14:23
**Strategy**: Parallel (3 modules in 2 phases)
**Status**: ✅ Success

---

## Summary

**Actual Build Time**: 12m 34s
**Sequential Equivalent**: ~25m 15s
**Speedup**: 2.0x faster ✅
**Efficiency**: 80% (good)

**Quality**:
- ✅ All modules validated
- ✅ No integration conflicts
- ⚠️ 2 modules required 2 iterations

**Overall**: ⭐⭐⭐⭐ (4/5) - Good performance, minor optimization opportunities

---

## Timing Breakdown

### Total Timeline
```
t=0:00   Phase 1 starts (3 modules in parallel)
t=3:15   Module A complete & validated
t=3:30   Module B complete & validated
t=8:45   Module C complete (bottleneck)
t=9:15   Module C validated (after 2 iterations)
t=9:15   Phase 2 starts (2 modules in parallel)
t=13:30  Module D complete & validated
t=13:45  Module E complete & validated
t=14:00  Integration starts
t=15:30  Integration complete & validated
t=16:00  Final validation
t=16:30  Build complete ✅
```

### Phase Performance

| Phase | Modules | Planned | Actual | Diff | Status |
|-------|---------|---------|--------|------|--------|
| Phase 1 | 3 (A,B,C) | 8m | 9m 15s | +1m 15s | ⚠️ Slower |
| Phase 2 | 2 (D,E) | 5m | 4m 30s | -30s | ✅ Faster |
| Integration | 1 | 2m | 2m 30s | +30s | ≈ On time |
| **Total** | **6** | **15m** | **16m 15s** | **+1m 15s** | **≈ On time** |

**Analysis**: Slightly slower than estimate due to Module C validation iterations.

---

## Module Performance

### Module A: Password Validation ✅ Excellent
- **Phase**: 1
- **Build Time**: 2m 45s
- **Validation**: 30s (iteration 1) ✅
- **Total**: 3m 15s
- **Estimate**: 3m 12s (within 3s ✅)
- **Tests**: 25/25 passed
- **Status**: ⭐⭐⭐⭐⭐ Perfect

**Analysis**: Fast, passed first iteration, no issues

---

### Module B: JWT Token Management ✅ Good
- **Phase**: 1
- **Build Time**: 2m 30s
- **Validation**: 1m (iteration 1) ✅
- **Total**: 3m 30s
- **Estimate**: 3m 8s (within 22s ✅)
- **Tests**: 20/20 passed
- **Status**: ⭐⭐⭐⭐⭐ Perfect

**Analysis**: Fast, clean implementation

---

### Module C: Email Service ⚠️ Bottleneck
- **Phase**: 1
- **Build Time**: 7m 30s
- **Validation**: 1m 45s (iterations 1+2) ⚠️
- **Total**: 9m 15s
- **Estimate**: 8m 23s (+52s, 10% over)
- **Tests**: 15/15 passed (after fixes)
- **Status**: ⭐⭐⭐ Acceptable

**Issues**:
- ⚠️ Slowest module (9m 15s) - delayed Phase 2 start
- ⚠️ Required 2 validation iterations
- ⚠️ Failed 2 tests in iteration 1 (SMTP connection, email format)

**Impact**:
- Blocked Phase 2 from starting (wasted 1m of parallel capacity)
- Added 1m of validation rework

**Optimization Opportunities**:
1. Pre-generate comprehensive email tests (avoid iteration 2)
2. Use email-service template (proven pattern)
3. Consider stub for dependent modules (if >10m in future)

---

### Module D: Auth API Endpoint ✅ Good
- **Phase**: 2
- **Dependencies**: A, B
- **Build Time**: 3m 30s
- **Validation**: 1m (iteration 1) ✅
- **Total**: 4m 30s
- **Estimate**: 4m 45s (15s faster ✅)
- **Tests**: 18/18 passed
- **Status**: ⭐⭐⭐⭐⭐ Perfect

**Analysis**: Clean integration with Module A+B

---

### Module E: Password Reset API ✅ Good
- **Phase**: 2
- **Dependencies**: A, C
- **Build Time**: 3m 45s
- **Validation**: 1m (iteration 1) ✅
- **Total**: 4m 45s
- **Estimate**: 4m 10s (+35s acceptable)
- **Tests**: 12/12 passed
- **Status**: ⭐⭐⭐⭐ Good

**Analysis**: Slightly slower than expected but no issues

---

## Bottleneck Analysis

### Primary Bottleneck: Module C (Email Service)

**Time Impact**:
- Module C: 9m 15s
- Other Phase 1 modules: avg 3m 22s
- **Wasted parallel capacity**: 5m 53s

**Explanation**:
Modules A and B finished at 3m 30s but had to wait 5m 45s for Module C.
This idle time reduced parallelization efficiency.

**Theoretical best case**: If all Phase 1 modules finished at 3m 30s:
- Phase 1: 3m 30s (vs actual 9m 15s)
- Total: 10m 30s (vs actual 16m 15s)
- **Potential savings**: 5m 45s

### Secondary Bottlenecks

**Validation Iterations (Module C)**:
- 2 iterations added 1m to Module C
- Common issues: SMTP connection errors, email format bugs
- **Fix**: Better test generation, proven templates

---

## Efficiency Analysis

### Parallelization Efficiency

**Theoretical speedup** (if perfect parallelization):
- Sequential time: 25m 15s
- Perfect parallel time: 9m 15s (longest module)
- Theoretical speedup: 2.7x

**Actual speedup**:
- Sequential time: 25m 15s
- Actual parallel time: 16m 15s
- Actual speedup: 2.0x

**Efficiency**: 2.0x / 2.7x = 74%

**Analysis**:
- Lost 26% efficiency due to:
  - Phase dependencies (20%)
  - Integration overhead (4%)
  - Coordination overhead (2%)

**Verdict**: 74% efficiency is **good** for 2-phase parallel build.
(70-80% is typical, >80% is excellent)

---

## Comparison to Historical Builds

| Metric | This Build | Avg (auth features) | Performance |
|--------|------------|---------------------|-------------|
| Total time | 16m 15s | 17m 30s | ✅ 7% faster |
| Speedup | 2.0x | 1.8x | ✅ Better |
| Iterations/module | 1.2 | 1.4 | ✅ Fewer |
| Integration conflicts | 0 | 1.2 | ✅ Better |
| Efficiency | 74% | 68% | ✅ More efficient |

**Overall**: This build performed **better than average** ✅

---

## Recommendations

### Immediate (For This Feature Type)
1. **Optimize email service builds** (primary bottleneck)
   - Use proven email-service template
   - Pre-generate comprehensive tests
   - Target: Reduce from 9m to 6m (33% faster)

2. **Consider email service stub** (for dependent modules)
   - If email service >10m, stub allows Module E to proceed
   - Integration can replace stub later

### Short-term (Next Sprint)
1. **Update email service estimate** in build-plan-optimizer
   - Change from 8m 23s to 9m 15s (more accurate)

2. **Create email-service template**
   - Reusable pattern with common tests
   - Reduces failures from 15% to 8%

### Long-term (Process Improvements)
1. **Track module type performance**
   - Keep updating averages (password: 3m, email: 9m, etc.)
   - Better estimates for future builds

2. **Identify module patterns**
   - Email services are consistently slow
   - JWT modules are consistently fast
   - Plan accordingly

---

## Lessons Learned

### What Worked ✅
1. **Parallel strategy was effective** (2.0x speedup)
2. **Interface generation prevented conflicts** (0 integration issues)
3. **Modules A, B were fast and clean** (no rework needed)
4. **Phase 2 integration was smooth** (no type mismatches)

### What Could Improve ⚠️
1. **Email service took longer than expected**
   - Need better template or test generation
2. **Validation iteration for Module C**
   - Could have been avoided with better tests

### What to Avoid ❌
1. **Don't underestimate email services** (common bottleneck)
2. **Don't skip test generation** for complex modules

---

## Build Quality Score

**Overall Rating**: ⭐⭐⭐⭐ (4/5)

**Breakdown**:
- Speed: ⭐⭐⭐⭐ (2.0x speedup, good)
- Quality: ⭐⭐⭐⭐⭐ (no integration issues, clean code)
- Efficiency: ⭐⭐⭐⭐ (74% efficiency, good)
- Predictability: ⭐⭐⭐ (1m 15s over estimate, acceptable)

**Verdict**: Successful build with minor optimization opportunities.

---

## Action Items

### For Next Similar Build
- [ ] Use email-service template to reduce Module C time
- [ ] Pre-generate comprehensive tests for email service
- [ ] Update estimate: email services → 9m (from 8m)

### For Build Plan Optimizer
- [ ] Record this build's metrics
- [ ] Update email service average duration
- [ ] Reinforce parallel strategy for auth features (proven effective)

### For Team
- [ ] Share email service optimization findings
- [ ] Document common email test patterns
```

## Metrics to track

```json
{
  "build_id": "auth-2025-01-25",
  "feature": "user-authentication",
  "strategy": "parallel_3_modules_2_phases",
  "start_time": "2025-01-25T14:23:00Z",
  "end_time": "2025-01-25T14:39:30Z",
  "total_duration_seconds": 975,
  "sequential_equivalent_seconds": 1515,
  "speedup": 2.0,
  "efficiency_percent": 74,
  "phases": [
    {
      "phase": 1,
      "modules": ["password_validation", "jwt_management", "email_service"],
      "planned_duration": 480,
      "actual_duration": 555,
      "parallel": true,
      "bottleneck_module": "email_service"
    }
  ],
  "modules": [
    {
      "name": "email_service",
      "phase": 1,
      "build_duration": 450,
      "validation_duration": 105,
      "iterations": 2,
      "tests_total": 15,
      "tests_passed": 15,
      "bottleneck": true
    }
  ],
  "quality": {
    "integration_conflicts": 0,
    "validation_iterations_avg": 1.2,
    "test_pass_rate": 100
  },
  "rating": 4
}
```

## Instructions

1. **Collect data**: Read build logs, timing data, validation reports
2. **Calculate metrics**: Speedup, efficiency, bottlenecks
3. **Compare to estimates**: How accurate were predictions?
4. **Compare to history**: Better or worse than average?
5. **Identify patterns**: What worked, what didn't
6. **Generate recommendations**: Specific improvements
7. **Save analysis**: For future reference and learning

## Best practices

- Analyze every parallel build (learn continuously)
- Track trends over time (getting better?)
- Be specific with recommendations (actionable)
- Celebrate successes (reinforce what works)
- Learn from bottlenecks (fix what's slow)
- Update estimates (improve accuracy)

## Constraints

- Must use actual timing data (not estimates)
- Must calculate realistic speedup
- Should provide actionable recommendations
- Must track quality metrics (not just speed)
- Should compare to historical data when available
