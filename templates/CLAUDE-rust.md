# CLAUDE.md — Rust Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify your Rust edition and workspace layout -->
This is a Rust project using edition 2021. All code must pass `cargo clippy -- -D warnings` and `cargo fmt --check`. Prefer safe Rust — avoid `unsafe` unless absolutely necessary and document safety invariants.

## Error Handling

<!-- Rust error handling conventions -->
- Libraries: use `thiserror` for custom error types with `#[derive(Error)]`
- Applications: use `anyhow::Result` for convenient error propagation
- Never use `.unwrap()` or `.expect()` in production code paths — use `?` operator
- `.unwrap()` is acceptable only in tests and examples
- Map errors with context: `.context("failed to parse config")?` (anyhow) or `.map_err()`
- Define error enums for each module's public API

## Types & Ownership

<!-- Type system and ownership patterns -->
- Prefer borrowing (`&T`, `&mut T`) over cloning — clone only when ownership transfer is needed
- Use `Cow<'_, str>` when a function might or might not need to own the string
- Lifetimes only when the compiler requires them — don't annotate unnecessarily
- Newtype pattern for domain types: `struct UserId(u64)` instead of raw `u64`
- Derive `Debug` on all types. Derive `Clone`, `PartialEq`, `Eq`, `Hash` when appropriate
- Prefer `impl Into<T>` or `impl AsRef<T>` for flexible function signatures

## Naming Conventions

<!-- Rust naming standards -->
- `snake_case` for functions, methods, variables, modules, and files
- `CamelCase` for types, traits, and enums
- `SCREAMING_SNAKE_CASE` for constants and statics
- Modules match file names: `mod auth` lives in `auth.rs` or `auth/mod.rs`
- Trait names describe capability: `Serialize`, `Display`, `Into`

## Testing

<!-- Testing approach -->
- Unit tests in the same file: `#[cfg(test)] mod tests { ... }`
- Integration tests in `tests/` directory
- Use `#[test]` for standard tests, `#[tokio::test]` for async tests
- Property-based testing with `proptest` for complex invariants
- Snapshot testing with `insta` for complex output validation
- Run `cargo test` before every commit

## Dependencies

<!-- Dependency management -->
- Minimize dependencies — each one adds compile time and attack surface
- Check crate maintenance status and download counts before adding
- Use `cargo-deny` to audit licenses and security advisories
- Pin minor versions in `Cargo.toml`: `serde = "1.0"` not `serde = "*"`
- Run `cargo update` periodically and test after updating

## Unsafe Code

<!-- Rules for unsafe -->
- Avoid `unsafe` unless there is no safe alternative and the performance benefit is measurable
- Every `unsafe` block must have a `// SAFETY:` comment explaining why it's sound
- Encapsulate `unsafe` behind safe abstractions
- Test `unsafe` code with Miri when possible: `cargo +nightly miri test`

## Performance

<!-- Performance conventions -->
- Always benchmark with release builds: `cargo bench` (never debug builds)
- Use `criterion` for benchmarks, not manual timing
- Don't optimize prematurely — profile first with `cargo flamegraph` or `perf`
- Prefer iterators over manual loops — they optimize better

## Build & Deploy

<!-- Build and deployment conventions -->
- Release builds: `cargo build --release`
- Strip symbols for smaller binaries: `[profile.release] strip = true` in `Cargo.toml`
- Cross-compilation with `cross` or `cargo-zigbuild`
- Static linking with `target-feature=+crt-static` for portable Linux binaries

## Verification

<!-- What to check before declaring done -->
- `cargo check` — compiles without errors
- `cargo test` — all tests pass
- `cargo clippy -- -D warnings` — no lint warnings
- `cargo fmt --check` — properly formatted
- `cargo doc --no-deps` — documentation builds without warnings

## Git & GitHub

<!-- Safety rules -->
- Do not push code or create PRs without explicit permission
- Do not perform destructive or irreversible git operations without asking first
- Run the full verification suite before committing
