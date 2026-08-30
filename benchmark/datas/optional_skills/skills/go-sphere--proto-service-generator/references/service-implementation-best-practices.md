# Service Implementation Best Practices

This reference contains implementation details and templates for `proto-service-generator`.
Keep `SKILL.md` as the high-level workflow and load only the sections needed for the current task.

## Section Loading Guide

1. Always load: `1) Interface Assertion and File Mapping`, `4) Append-Only Update Procedure`, `7) Import and Naming Checklist`.
2. Load `3) Simple CRUD (Direct Ent) Template` when implementing standard CRUD methods.
3. Load `2) Stub Template for Unknown Logic` when behavior cannot be inferred safely.
4. Load `5) Complex Logic Split to Usecase` and `6) Wire Injection Pattern` when flows are complex or DI signatures change.
5. Load `8) Sphere Feature Reuse Pattern` before introducing new helpers or custom infrastructure code.

## Table of Contents

1. Interface Assertion and File Mapping
2. Stub Template for Unknown Logic
3. Simple CRUD (Direct Ent) Template
4. Append-Only Update Procedure
5. Complex Logic Split to Usecase
6. Wire Injection Pattern
7. Import and Naming Checklist
8. Sphere Feature Reuse Pattern

## 1) Interface Assertion and File Mapping

Use generated `type XxxServiceHTTPServer interface` definitions from
`api/<module>/v1/*.sphere.pb.go` as the only method-signature source of truth.

Mapping rule:

- `XxxService` -> `internal/service/<module>/xxx.go`

Assertion template (required in each service file):

```go
var _ dashv1.AdminSessionServiceHTTPServer = (*Service)(nil)
```

Useful discovery commands:

```bash
rg -n "type .*ServiceHTTPServer interface" api
rg -n "var _ .*ServiceHTTPServer = \(\*Service\)\(nil\)" internal/service
rg -n "func \(s \*Service\) [A-Z]" internal/service
```

## 2) Stub Template for Unknown Logic

When business logic cannot be inferred safely, generate a compilable stub first.

```go
package dash

import (
	"context"
	"errors"

	dashv1 "github.com/go-sphere/sphere-layout/api/dash/v1"
)

func (s *Service) RefreshSomething(ctx context.Context, req *dashv1.RefreshSomethingRequest) (*dashv1.RefreshSomethingResponse, error) {
	return nil, errors.New("not implemented: RefreshSomething")
}
```

## 3) Simple CRUD (Direct Ent) Template

For simple CRUD, call Ent directly inside Service and avoid adding an extra DAO business layer.

```go
package dash

import (
	"context"

	"entgo.io/ent/dialect/sql"
	dashv1 "github.com/go-sphere/sphere-layout/api/dash/v1"
	"github.com/go-sphere/sphere-layout/internal/pkg/conv"
	"github.com/go-sphere/sphere-layout/internal/pkg/database/ent/keyvaluestore"
	"github.com/go-sphere/sphere-layout/internal/pkg/render/entbind"
)

var _ dashv1.KeyValueStoreServiceHTTPServer = (*Service)(nil)

func (s *Service) CreateKeyValueStore(ctx context.Context, req *dashv1.CreateKeyValueStoreRequest) (*dashv1.CreateKeyValueStoreResponse, error) {
	item, err := entbind.CreateKeyValueStore(s.db.KeyValueStore.Create(), req.KeyValueStore).Save(ctx)
	if err != nil {
		return nil, err
	}
	return &dashv1.CreateKeyValueStoreResponse{
		KeyValueStore: s.render.KeyValueStore(item),
	}, nil
}

func (s *Service) GetKeyValueStore(ctx context.Context, req *dashv1.GetKeyValueStoreRequest) (*dashv1.GetKeyValueStoreResponse, error) {
	item, err := s.db.KeyValueStore.Get(ctx, req.Id)
	if err != nil {
		return nil, err
	}
	return &dashv1.GetKeyValueStoreResponse{
		KeyValueStore: s.render.KeyValueStore(item),
	}, nil
}

func (s *Service) ListKeyValueStores(ctx context.Context, req *dashv1.ListKeyValueStoresRequest) (*dashv1.ListKeyValueStoresResponse, error) {
	query := s.db.KeyValueStore.Query()
	count, err := query.Clone().Count(ctx)
	if err != nil {
		return nil, err
	}
	totalPage, pageSize := conv.Page(count, int(req.PageSize))
	rows, err := query.Clone().
		Limit(pageSize).
		Order(keyvaluestore.ByID(sql.OrderDesc())).
		Offset(pageSize * int(req.Page)).
		All(ctx)
	if err != nil {
		return nil, err
	}
	return &dashv1.ListKeyValueStoresResponse{
		KeyValueStores: conv.Map(rows, s.render.KeyValueStore),
		TotalSize:      int64(count),
		TotalPage:      int64(totalPage),
	}, nil
}

func (s *Service) UpdateKeyValueStore(ctx context.Context, req *dashv1.UpdateKeyValueStoreRequest) (*dashv1.UpdateKeyValueStoreResponse, error) {
	item, err := entbind.UpdateOneKeyValueStore(
		s.db.KeyValueStore.UpdateOneID(req.KeyValueStore.Id),
		req.KeyValueStore,
	).Save(ctx)
	if err != nil {
		return nil, err
	}
	return &dashv1.UpdateKeyValueStoreResponse{
		KeyValueStore: s.render.KeyValueStore(item),
	}, nil
}

func (s *Service) DeleteKeyValueStore(ctx context.Context, req *dashv1.DeleteKeyValueStoreRequest) (*dashv1.DeleteKeyValueStoreResponse, error) {
	if err := s.db.KeyValueStore.DeleteOneID(req.Id).Exec(ctx); err != nil {
		return nil, err
	}
	return &dashv1.DeleteKeyValueStoreResponse{}, nil
}
```

Simple CRUD classification:

1. Method name is `Create*`, `Get*`, `List*`, `Update*`, or `Delete*`.
2. It operates on one entity.
3. It does not require complex cross-domain orchestration or complex transactions.

## 4) Append-Only Update Procedure

Do not rewrite existing files. Append only missing pieces.

Execution order:

1. Read all signatures from `type XxxServiceHTTPServer interface`.
2. Inspect existing methods in `internal/service/<module>/<service>.go`.
3. Append only missing methods.
4. Append assertion if missing.
5. Add only required imports.
6. Keep existing implementations untouched.

Quick check commands:

```bash
rg -n "type .*ServiceHTTPServer interface|^\}" api/<module>/v1/*.sphere.pb.go
rg -n "func \(s \*Service\)" internal/service/<module>/<service>.go
rg -n "var _ .*ServiceHTTPServer = \(\*Service\)\(nil\)" internal/service/<module>/<service>.go
```

## 5) Complex Logic Split to Usecase

When flow is clearly complex (cross-entity transactions, reusable orchestration, long flows), split logic into:

```text
internal/usecase/<module>/<service>/
```

Example structure:

```text
internal/usecase/dash/admin_session/
  usecase.go
```

`usecase.go` example:

```go
package adminsession

import "context"

type Usecase struct{}

func NewUsecase() *Usecase {
	return &Usecase{}
}

func (u *Usecase) RunComplexFlow(ctx context.Context, userID int64) error {
	// TODO: implement business flow
	return nil
}
```

Service usage example:

```go
type Service struct {
	// ...
	adminSessionUC *adminsession.Usecase
}

func (s *Service) SomeComplexMethod(ctx context.Context, req *dashv1.SomeComplexMethodRequest) (*dashv1.SomeComplexMethodResponse, error) {
	if err := s.adminSessionUC.RunComplexFlow(ctx, req.UserId); err != nil {
		return nil, err
	}
	return &dashv1.SomeComplexMethodResponse{}, nil
}
```

## 6) Wire Injection Pattern

When usecase dependencies are added, keep provider sets and constructors compilable.

`internal/usecase/dash/admin_session/wire.go` (optional):

```go
package adminsession

import "github.com/google/wire"

var ProviderSet = wire.NewSet(
	NewUsecase,
)
```

`internal/service/wire.go` update example:

```go
var ProviderSet = wire.NewSet(
	api.NewService,
	dash.NewService,
	bot.NewService,
	adminsession.NewUsecase,
)
```

`internal/service/dash/service.go` constructor update example:

```go
func NewService(
	db *dao.Dao,
	wechat *wechat.Wechat,
	cache cache.ByteCache,
	store storage.CDNStorage,
	adminSessionUC *adminsession.Usecase,
) *Service {
	return &Service{
		db:             db,
		wechat:         wechat,
		cache:          cache,
		storage:        store,
		adminSessionUC: adminSessionUC,
	}
}
```

## 7) Import and Naming Checklist

1. File naming: `XxxService -> xxx.go` (snake_case).
2. Receiver: always `func (s *Service)`.
3. Keep method signatures exactly aligned to generated interfaces.
4. Add imports only when required (`context`, `errors`, `sql`, `conv`, `entbind`, and generated API package).
5. Do not import unused packages.
6. Do not edit generated files under `api/*`.
7. Validate with at least:
- `go test ./internal/service/...`
- `go test ./cmd/app/...`

## 8) Sphere Feature Reuse Pattern

Reuse existing Sphere and repository capabilities before adding new code.

Reuse checks:

1. Search sibling services for matching implementation patterns.
2. Search existing middleware/auth/error flows in current server setup.
3. Search existing bind/render helpers before adding mapping code.
4. Search provider sets and constructors before adding duplicate dependencies.

Suggested lookup commands:

```bash
rg -n "Register.*ServiceHTTPServer|NewAuthMiddleware|WithJson|sphere\.errors|ProviderSet" internal api
rg -n "entbind\.|entmap\.|conv\.Page|DeleteOneID|UpdateOneID|IDIn\(" internal
rg -n "type Service struct|func NewService\(" internal/service
```

If `sphere-feature-workflow` is available, combine both skills:

1. Let `sphere-feature-workflow` guide end-to-end feature integration.
2. Keep `proto-service-generator` focused on interface coverage and method implementation shape.
3. Prefer framework-native behavior over duplicated custom code.
