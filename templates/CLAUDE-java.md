---
title: Java
nav_order: 7
parent: Templates
---
# CLAUDE.md — Java / Spring Boot Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your Java version and framework -->
This is a Java 21+ project using Spring Boot 3.x. Use records for DTOs, sealed interfaces where appropriate, and prefer immutability. All code must compile cleanly with zero warnings.

## Package Structure

<!-- Define your project layout -->
- `src/main/java/com/example/` — main application code
- Group by feature, not by layer: `user/`, `order/`, `auth/` — each with its own controller, service, repository
- Shared utilities in `common/` or `shared/` package
- Configuration classes in `config/` package
- No circular dependencies between feature packages

## Naming Conventions

<!-- Java naming standards -->
- `PascalCase` for classes and interfaces
- `camelCase` for methods and variables
- `UPPER_SNAKE_CASE` for constants
- Interfaces don't need `I` prefix — `UserRepository` not `IUserRepository`
- Implementation suffix only when multiple impls exist: `UserServiceImpl`

## Dependency Injection

<!-- Spring DI patterns -->
- Constructor injection only — no field injection with `@Autowired`
- Use `@RequiredArgsConstructor` (Lombok) or explicit constructors
- Keep constructors small — if you need 5+ dependencies, the class does too much
- Use `@Configuration` classes for bean definitions, not XML

## Error Handling

<!-- How errors are managed -->
- Use `@ControllerAdvice` with `@ExceptionHandler` for global error handling
- Define custom exceptions for domain errors: `UserNotFoundException extends RuntimeException`
- Return consistent error response format: `{ "error": "...", "code": "...", "details": [...] }`
- Never expose stack traces in API responses
- Log exceptions at the handler level, not at every catch site

## Database & JPA

<!-- Database patterns -->
- Spring Data JPA for repositories — extend `JpaRepository` or `CrudRepository`
- Use `@Transactional` on service methods, not on repositories
- Flyway or Liquibase for database migrations — never modify existing migrations
- N+1 queries: use `@EntityGraph` or `JOIN FETCH` in JPQL
- Always define `equals()` and `hashCode()` on entities using business keys, not IDs

## Testing

<!-- Testing approach -->
- JUnit 5 + Mockito for unit tests
- `@SpringBootTest` for integration tests (use sparingly — they're slow)
- `@WebMvcTest` for controller layer tests
- `@DataJpaTest` for repository layer tests
- Use Testcontainers for database integration tests
- Test naming: `shouldReturnUserWhenIdExists()`

## API Design

<!-- REST API conventions -->
- RESTful endpoints: `GET /api/users`, `POST /api/users`, `GET /api/users/{id}`
- Use `@Valid` on request bodies with Bean Validation annotations
- Pagination with `Pageable`: `GET /api/users?page=0&size=20&sort=name`
- Return appropriate status codes: 201 for creation, 204 for deletion, 409 for conflicts
- Version APIs in the URL if breaking changes are needed: `/api/v2/users`

## Build & Deploy

<!-- Build conventions -->
- `./mvnw clean package` or `./gradlew build` — use the wrapper, not system Maven/Gradle
- Run with adequate memory: `JAVA_OPTS="-Xmx512m"` for dev, tune for production
- Use Spring profiles: `application-dev.yml`, `application-prod.yml`
- Docker: multi-stage build with `eclipse-temurin` base image

## Verification

<!-- What to check before declaring done -->
- `./mvnw compile` — compiles without errors or warnings
- `./mvnw test` — all tests pass
- `./mvnw spotbugs:check` or `./mvnw checkstyle:check` — no static analysis warnings (if configured)
- Application starts without errors: `./mvnw spring-boot:run`

## Git & GitHub

<!-- Safety rules -->
- Do not push code or create PRs without explicit permission
- Do not perform destructive or irreversible operations without asking first
- Never commit `application-local.yml` or files containing secrets
