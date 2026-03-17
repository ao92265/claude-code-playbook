# CLAUDE.md — C# / .NET Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your .NET version and project type -->
This is a C# project using .NET 8+. Use nullable reference types (`<Nullable>enable</Nullable>`). Prefer records for DTOs, file-scoped namespaces, and primary constructors where appropriate. All code must compile with zero warnings.

## Project Structure

<!-- Define your solution layout -->
- `src/` — source projects
- `tests/` — test projects (mirror source structure)
- One project per bounded context or major feature area
- Shared code in a `.Common` or `.Shared` project
- Keep `Program.cs` minimal — register services, configure pipeline, run

## Naming Conventions

<!-- C# naming standards -->
- `PascalCase` for types, methods, properties, and public members
- `camelCase` for local variables and parameters
- `_camelCase` for private fields
- `IPascalCase` for interfaces (C# convention, unlike Java)
- Async methods end with `Async`: `GetUserAsync()`

## Dependency Injection

<!-- .NET DI patterns -->
- Constructor injection via built-in DI container
- Register services in `Program.cs` or extension methods: `services.AddScoped<IUserService, UserService>()`
- Use `IOptions<T>` for configuration binding
- Avoid service locator pattern — don't resolve services from `IServiceProvider` directly

## Error Handling

<!-- How errors are managed -->
- Use middleware for global exception handling, not try/catch in every controller
- Define custom exceptions for domain errors with meaningful messages
- Return `ProblemDetails` (RFC 7807) for API error responses
- Use `Result<T>` pattern for operations that can fail predictably
- Never expose stack traces in production responses

## Entity Framework Core

<!-- Database patterns -->
- Code-first migrations: `dotnet ef migrations add <Name>`
- DbContext registration: `services.AddDbContext<AppDbContext>()`
- Use `AsNoTracking()` for read-only queries
- Avoid lazy loading — use explicit `Include()` for related data
- Index frequently queried columns in migration files

## Testing

<!-- Testing approach -->
- xUnit for test framework
- NSubstitute or Moq for mocking
- `WebApplicationFactory<Program>` for integration tests
- Use `[Theory]` with `[InlineData]` for parameterized tests
- Test naming: `MethodName_Scenario_ExpectedResult`
- Testcontainers for database integration tests

## API Design

<!-- REST API conventions -->
- Minimal APIs or Controllers — be consistent within the project
- Use `[FromBody]`, `[FromQuery]`, `[FromRoute]` explicitly
- Return `IActionResult` or `Results` with proper status codes
- Use FluentValidation or Data Annotations for request validation
- Swagger/OpenAPI: keep `[ProducesResponseType]` attributes up to date

## Async Patterns

<!-- Async/await conventions -->
- Use `async`/`await` for all I/O operations
- Never use `.Result` or `.Wait()` — it causes deadlocks
- Use `CancellationToken` in controller actions and propagate through the call chain
- `ValueTask` only when the common path completes synchronously

## Build & Deploy

<!-- Build conventions -->
- `dotnet build` — must pass with zero warnings
- `dotnet publish -c Release` for deployment artifacts
- Docker: multi-stage build with `mcr.microsoft.com/dotnet/sdk` → `mcr.microsoft.com/dotnet/aspnet`
- Use `appsettings.{Environment}.json` for environment-specific config
- Never commit `appsettings.Development.json` with real secrets — use User Secrets or environment variables

## Verification

<!-- What to check before declaring done -->
- `dotnet build --warnaserror` — compiles with zero warnings
- `dotnet test` — all tests pass
- `dotnet format --verify-no-changes` — properly formatted
- Application starts without errors

## Git & GitHub

<!-- Safety rules -->
- Do not push code or create PRs without explicit permission
- Do not perform destructive or irreversible operations without asking first
- Never commit `appsettings.*.json` with connection strings or secrets
