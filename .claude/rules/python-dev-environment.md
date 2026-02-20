# Python Development Environment

Standard Python development environment and toolchain for all projects.

## Package Management: uv

**Do not use pip directly. All commands must go through uv.**

```bash
# Add packages
uv add <package>
uv add --dev <package>    # Dev dependency

# Sync dependencies
uv sync

# Run scripts
uv run <command>
uv run python script.py
uv run pytest
```

### pyproject.toml

Manage dependencies in `pyproject.toml`:

```toml
[project]
dependencies = [
    "httpx>=0.27",
]

[project.optional-dependencies]
dev = [
    "pytest>=8.0",
    "ruff>=0.8",
]
```

## Linting & Formatting: ruff

```bash
# Check
uv run ruff check .

# Auto-fix
uv run ruff check --fix .

# Format
uv run ruff format .
```

### ruff Configuration (pyproject.toml)

```toml
[tool.ruff]
target-version = "py312"
line-length = 88

[tool.ruff.lint]
select = [
    "E",      # pycodestyle errors
    "W",      # pycodestyle warnings
    "F",      # pyflakes
    "I",      # isort
    "B",      # flake8-bugbear
    "UP",     # pyupgrade
]
ignore = ["E501"]  # line too long (formatter handles)

[tool.ruff.format]
quote-style = "double"
```

## Common Commands

```bash
# Initialize new project
uv init
uv venv
source .venv/bin/activate  # Linux/macOS
.venv\Scripts\activate     # Windows

# Install dev dependencies
uv sync --all-extras

# Quality check
uv run ruff check .
uv run ruff format .
uv run pytest
```

## Pre-commit Checklist

- [ ] `uv run ruff check .` passes
- [ ] `uv run ruff format .` passes
- [ ] `uv run pytest` passes (if tests exist)

## Best Practices

### Dependency Management

- Always use `uv add` instead of manually editing `pyproject.toml`
- Use `--dev` flag for development-only dependencies
- Run `uv sync` after pulling changes from git

### Code Quality

- Run `ruff check --fix .` before committing to auto-fix issues
- Run `ruff format .` to ensure consistent code style
- Configure ruff in `pyproject.toml` for project-specific rules

### Project Structure

```
myproject/
├── pyproject.toml       # Project metadata and dependencies
├── uv.lock             # Locked dependency versions
├── .venv/              # Virtual environment (git-ignored)
├── src/                # Source code
│   └── myproject/
│       ├── __init__.py
│       └── main.py
└── tests/              # Test files
    └── test_main.py
```

### Virtual Environment

- uv automatically creates `.venv/` in the project directory
- Always activate the virtual environment before running commands
- `.venv/` should be in `.gitignore`
