# CLAUDE.md — Go Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your Go version and module path -->
This is a Go project using Go 1.22+. All code must pass `go fmt`, `go vet`, and `staticcheck`. Use the standard library wherever possible before reaching for external dependencies.

## Package Structure

<!-- Define your project layout -->
- `cmd/` — main applications (one directory per binary)
- `internal/` — private packages (not importable by other modules)
- `pkg/` — public packages (importable by external consumers, use sparingly)
- Keep packages small and focused — one responsibility per package
- Package names are short, lowercase, no underscores: `auth`, `store`, `handler`

## Error Handling

<!-- Go error handling conventions -->
- Always check returned errors — never use `_` to discard them
- Return errors, don't panic. `panic` is only for truly unrecoverable situations in `main()`
- Wrap errors with context: `fmt.Errorf("failed to create user: %w", err)`
- Use `errors.Is()` and `errors.As()` for error checking, not string comparison
- Define sentinel errors at package level: `var ErrNotFound = errors.New("not found")`
- Custom error types only when callers need to extract structured information

## Naming Conventions

<!-- Go naming standards -->
- `MixedCaps` for exported names, `mixedCaps` for unexported
- Interfaces with single methods use `-er` suffix: `Reader`, `Writer`, `Stringer`
- Don't stutter: `http.Server` not `http.HTTPServer`
- Acronyms are all caps: `HTTP`, `URL`, `ID` (not `Http`, `Url`, `Id`)
- Test files: `foo_test.go` alongside `foo.go`

## Testing

<!-- Testing approach -->
- Table-driven tests for functions with multiple input/output cases
- `go test ./...` must pass before any commit
- Use `testing.T` subtests: `t.Run("case name", func(t *testing.T) { ... })`
- Test helpers call `t.Helper()` first
- Use `testify/assert` or `testify/require` if the project already uses them — don't mix
- Integration tests use build tags: `//go:build integration`

## Concurrency

<!-- Concurrency patterns -->
- Always pass `context.Context` as the first parameter to long-running functions
- Use `sync.WaitGroup` for fan-out, channels for communication
- Never start goroutines without a plan for how they stop
- Protect shared state with `sync.Mutex` — keep critical sections small
- Prefer `select` with `ctx.Done()` for cancellation

## Dependencies

<!-- Dependency management -->
- Run `go mod tidy` after adding or removing imports
- Minimize external dependencies — the standard library covers most needs
- Pin major versions in `go.mod`
- Audit new dependencies before adding: check maintenance, license, and transitive deps

## Build & Deploy

<!-- Build and deployment conventions -->
- Static binaries: `CGO_ENABLED=0 go build -o bin/app ./cmd/app`
- Multi-stage Docker builds: build stage with Go image, runtime with `scratch` or `alpine`
- Use `-ldflags "-s -w"` for smaller release binaries
- Cross-compile with `GOOS` and `GOARCH` environment variables

## Verification

<!-- What to check before declaring done -->
- `go build ./...` — compiles without errors
- `go test ./...` — all tests pass
- `go vet ./...` — no suspicious constructs
- `staticcheck ./...` — no static analysis warnings (if installed)
- `go fmt ./...` — properly formatted (should be a no-op)

## Git & GitHub

<!-- Safety rules -->
- Do not push code or create PRs without explicit permission
- Do not perform destructive or irreversible git operations without asking first
- Run the full verification suite before committing
