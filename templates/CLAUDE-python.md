---
title: Python
nav_order: 3
parent: Templates
---
# CLAUDE.md — Python Project

<!-- Copy this template to your project root as CLAUDE.md and customize each section. -->

## Project Basics

<!-- Specify Python version and project type -->
This is a Python 3.10+ project. Type hints are required on all functions. Use async/await for I/O-bound operations where the framework supports it.

## Environment

<!-- Specify your package manager -->
- Use `poetry` for dependency management (alternatives: `uv`, `pip` + `venv`)
- Always pin dependency versions — no floating ranges in production
- Virtual environment must be active before running any commands
- `pyproject.toml` is the single source of truth for project metadata and dependencies

## Type Hints

<!-- Typing conventions -->
- Type hints required on all function signatures (parameters and return types)
- Use `mypy` in strict mode for type checking
- Avoid `Any` unless absolutely necessary — document why if used
- Use `TypedDict` for structured dictionaries, `dataclass` or `pydantic` for data models
- Import types from `typing` for Python 3.10 compatibility, or use native syntax for 3.10+

## Testing

<!-- Testing approach -->
- `pytest` for all tests
- Fixtures for test setup — prefer fixtures over setUp/tearDown
- `@pytest.mark.parametrize` for testing variants of the same behavior
- Mock external services only (APIs, databases, file systems) — never mock internal modules
- Test error paths and edge cases, not just the happy path
- Run tests with: `pytest -v`

## Code Style

<!-- Linting and formatting -->
- `ruff` for linting (replaces flake8, isort, pyflakes, and more)
- `black` for formatting (or `ruff format`)
- Import order: stdlib, third-party, local (enforced by ruff/isort)
- Line length: 88 characters (black default)
- Run checks with: `ruff check . && black --check .`

## Docstrings

<!-- Documentation conventions -->
- Google-style docstrings on all public functions and classes
- Include: one-line summary, Args, Returns, Raises sections
- Skip docstrings on obvious methods (getters, simple properties)
- Example:
  ```python
  def calculate_total(items: list[Item], tax_rate: float) -> Decimal:
      """Calculate the total price including tax.

      Args:
          items: List of items to total.
          tax_rate: Tax rate as a decimal (e.g., 0.08 for 8%).

      Returns:
          Total price including tax, rounded to 2 decimal places.

      Raises:
          ValueError: If tax_rate is negative.
      """
  ```

## Error Handling

<!-- Error handling patterns -->
- Specific exceptions over generic ones (`ValueError` not `Exception`)
- Never use bare `except:` — always specify the exception type
- Log errors with structured data (not just the message)
- Use custom exception classes for domain-specific errors
- Let unexpected exceptions propagate — don't silently swallow them

## Common Pitfalls

<!-- Things that frequently go wrong in Python -->
- Mutable default arguments: `def f(items=[])` shares the list across calls — use `None` and create inside
- Circular imports: restructure modules or use local imports
- GIL limitations: use multiprocessing for CPU-bound work, asyncio for I/O-bound
- f-string injection: never use f-strings for SQL queries or shell commands
- Late binding closures in loops: `lambda x=x: x` to capture loop variable

## Verification

<!-- How to verify work is complete -->
Before claiming work is done:
1. Run `pytest -v` — all tests pass
2. Run `mypy .` — zero type errors
3. Run `ruff check .` — zero lint errors
4. Run `black --check .` — formatting is clean
