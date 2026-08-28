# Example: 43-Endpoint API Migration

## Input

```
43 endpoints across 11 categories
- 25 "Done" (existing handlers, need migration)
- 16 "Stub" (hardcoded data, need database integration)
- 2 "Missing" (need full implementation)
- Non-trivial: PDF generation, image serving, XIRR calculation, email sending
```

## Output Summary (7 sprints, 17 hours estimated)

| Sprint | Title | Hours | Dependencies | Items |
|--------|-------|-------|--------------|-------|
| 1 | Setup: Create structure | 1 | None | 1 setup task |
| 2 | Migrate: Simple reads (bulk) | 3 | 1 | 15 GET endpoints |
| 3 | Migrate: Stub reads | 2 | 1 | 8 GET endpoints with hardcoded data |
| 4 | Migrate: Simple writes | 2 | 1 | 5 POST/PUT endpoints |
| 5 | Implement: Complex writes | 3 | 4 | 2 missing endpoints + email logic |
| 6 | Implement: Non-trivial | 4 | 2, 3 | PDF, images, XIRR |
| 7 | Integration & cleanup | 2 | 5, 6 | Register routes, verify OpenAPI |

Dependency chain: `1 → 2, 3, 4 → 5 → 7` and `2, 3 → 6 → 7`

## Full Sprint Definitions

```yaml
project: "InvestorApi Migration"
task: "Migrate 43 endpoints from monolithic InvestorEndpoints.cs to feature-based structure"
total_items: 43
estimated_hours: 17
success_metric: "OpenAPI spec at /openapi/v1.json lists 43 endpoints under /api/v1/investors; all smoke tests pass"

dependency_chain: "1 → 2, 3, 4 → 5 → 7 and 2, 3 → 6 → 7"

sprints:
  - sprint_id: 1
    title: "Setup: Create Feature Structure"
    duration_hours: 1
    dependencies: []
    input_state: "Program.cs exists; Features/ contains no InvestorApi/"
    output_state: "Features/InvestorApi/ created with 14 .cs files (endpoints + DTOs)"
    scope:
      - Create Features/InvestorApi/ directory
      - Create 14 empty endpoint files: AuthEndpoints.cs, FundEndpoints.cs, ...
      - Create InvestorApiEndpoints.cs with registration stubs
      - Create 13 DTO files with empty class definitions
    acceptance_criteria:
      - "Directory Features/InvestorApi/ exists"
      - "14 .cs files present (list matches spec section 2.1)"
      - "dotnet build succeeds (0 syntax errors)"
      - "InvestorApiEndpoints.cs contains 14 method calls (commented out)"
    constraints:
      - "Do not implement endpoint logic"
      - "Do not register routes in Program.cs"
      - "Keep DTO classes empty (class definition + opening/closing braces only)"
    reference_material: "docs/plan.md section 'File Structure', lines 12-45"

  - sprint_id: 2
    title: "Migrate: Fund & Account Read Endpoints"
    duration_hours: 3
    dependencies: [1]
    input_state: "InvestorApi structure exists; old InvestorEndpoints.cs contains 8 GET methods"
    output_state: "FundEndpoints.cs and AccountEndpoints.cs populated with 5 migrated handlers"
    scope:
      - "Copy GetInvestors() → FundEndpoints.GetFunds()"
      - "Copy GetContactOptions() → FundEndpoints.GetContactOptions()"
      - "Copy GetInvestorAccounts() → FundEndpoints.GetAccountsByFund()"
      - "Copy GetAccountTypes() → AccountEndpoints.GetAccountTypes()"
      - "Copy GetPortfolioSettings() → AccountEndpoints.GetPortfolioSettings()"
    acceptance_criteria:
      - "FundEndpoints.cs contains 3 static methods with [HttpGet] attributes"
      - "AccountEndpoints.cs contains 2 static methods with [HttpGet] attributes"
      - "InvestorApiEndpoints.cs registers 5 handlers under /api/v1/investors"
      - "dotnet build succeeds"
      - "OpenAPI spec lists 5 new GET endpoints at /api/v1/investors/*"
    constraints:
      - "Do not modify old InvestorEndpoints.cs"
      - "Do not register routes in Program.cs yet"
      - "Copy handlers exactly—do not refactor logic"
    reference_material: "docs/plan.md table 'Endpoint Mapping', rows 11-15"

  - sprint_id: 3
    title: "Migrate: Stub Read Endpoints"
    duration_hours: 2
    dependencies: [1]
    input_state: "InvestorApi structure exists; 8 GET endpoints return hardcoded data"
    output_state: "8 stub endpoints migrated to feature files with hardcoded data preserved"
    scope:
      - Migrate 8 stub GET endpoints to their respective feature endpoint files
      - Preserve existing hardcoded return values
    acceptance_criteria:
      - "8 stub endpoint methods exist in feature endpoint files"
      - "Each stub returns hardcoded data matching original responses"
      - "dotnet build succeeds"
    constraints:
      - "Do not replace hardcoded data with database calls"
      - "Do not modify return types or response shapes"
    reference_material: "docs/plan.md table 'Endpoint Mapping', rows 26-33"

  - sprint_id: 4
    title: "Migrate: Write Endpoints (POST/PUT)"
    duration_hours: 2
    dependencies: [1]
    input_state: "InvestorApi structure exists; old endpoints contain 5 POST/PUT methods"
    output_state: "5 write endpoints migrated to feature endpoint files"
    scope:
      - Migrate 5 POST/PUT endpoints to respective feature files
      - Preserve existing validation and database logic
    acceptance_criteria:
      - "5 POST/PUT methods exist in feature endpoint files"
      - "Each method preserves original validation logic"
      - "dotnet build succeeds"
      - "InvestorApiEndpoints.cs registers all 5 write handlers"
    constraints:
      - "Do not refactor validation logic"
      - "Do not change HTTP methods or route patterns"
    reference_material: "docs/plan.md table 'Endpoint Mapping', rows 34-38"

  - sprint_id: 5
    title: "Implement: Missing Endpoints & Email"
    duration_hours: 3
    dependencies: [4]
    input_state: "Write endpoints migrated; 2 endpoints have no existing implementation"
    output_state: "2 new endpoints implemented; email notification logic integrated"
    scope:
      - Implement CreateInvestorAccount endpoint with full validation
      - Implement SendInvestorNotification endpoint with email service integration
    acceptance_criteria:
      - "CreateInvestorAccount handler validates input and persists to database"
      - "SendInvestorNotification handler calls email service and returns 202"
      - "dotnet build succeeds"
      - "Integration test: POST to CreateInvestorAccount returns 201"
    constraints:
      - "Use existing email service interface—do not create new service"
      - "Follow existing validation patterns from migrated write endpoints"
    reference_material: "docs/plan.md 'Missing Endpoints', lines 180-209"

  - sprint_id: 6
    title: "Implement: PDF, Images & XIRR"
    duration_hours: 4
    dependencies: [2, 3]
    input_state: "Read endpoints migrated; no PDF, image, or XIRR handlers"
    output_state: "ReportEndpoints.cs, MediaEndpoints.cs, and CalculationEndpoints.cs populated"
    scope:
      - Implement GenerateReport(int fundId) returning PDF via QuestPDF
      - Implement ServeInvestorLogo(int fundId) returning image from database BLOBs
      - Implement CalculateXIRR(int accountId) with financial calculation logic
    acceptance_criteria:
      - "ReportEndpoints.cs contains GenerateReport() returning application/pdf"
      - "MediaEndpoints.cs contains ServeInvestorLogo() returning FileStreamResult"
      - "CalculationEndpoints.cs contains CalculateXIRR() returning JSON"
      - "dotnet build succeeds"
      - "Smoke test: GET /api/v1/investors/reports/123 returns 200 with PDF content-type"
    constraints:
      - "Use existing database schema (investors.logo_blob column)"
      - "Do not add new NuGet packages without approval"
    reference_material: "docs/plan.md 'Non-Trivial Work', lines 210-275"

  - sprint_id: 7
    title: "Integration: Register Routes & Verify"
    duration_hours: 2
    dependencies: [5, 6]
    input_state: "All InvestorApi endpoints exist; Program.cs has no InvestorApi registration"
    output_state: "Program.cs registers /api/v1/investors; old routes removed; OpenAPI verified"
    scope:
      - Add app.MapInvestorApiEndpoints() to Program.cs
      - Remove old app.MapGroup("/investors") registration
      - Verify OpenAPI spec reflects new structure
    acceptance_criteria:
      - "Program.cs contains app.MapInvestorApiEndpoints() call"
      - "Program.cs does not contain old /investors MapGroup call"
      - "dotnet build && dotnet run starts without errors"
      - "OpenAPI spec at /openapi/v1.json lists 43 endpoints under /api/v1/investors"
      - "Swagger UI at /swagger loads successfully"
    constraints:
      - "Do not modify endpoint files"
      - "Do not change existing auth middleware"
    reference_material: "docs/plan.md 'Final Integration', lines 380-410"
```
