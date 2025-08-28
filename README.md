# Dummy Server

A simple FastAPI server demonstration with structured logging using Nix.o
Featured in this video: https://vimeo.com/1113780459


## Features

- FastAPI server with structured logging via `structlog`
- Simple in-memory number operations (add/subtract)
- Operation history logging
- Nix-based development environment
- Comprehensive tests with pytest

## Usage

### With Nix

Start the server:
```bash
nix run              # Uses default 'serve' command
# or explicitly:
nix run .#default
```

Export OpenAPI specification:
```bash
nix run .#openapi
```

Or enter development shell and run directly:
```bash
nix develop
dummyserver serve           # Start server
dummyserver openapi         # Export OpenAPI spec
```

### API Endpoints

- `GET /` - Welcome message
- `GET /number` - Get current number
- `POST /number` - Modify number with `{"action": "add|subtract", "value": 123}`
- `GET /log` - Get operation history

### Testing

Run tests with structured logging output:
```bash
nix develop
pytest -s
```

### Code Analysis

Run individual analysis tools:
```bash
nix run .#codegen          # Code generation (whitespace trimming)
nix run .#nix-analysis     # Nix linting (deadnix, nixpkgs-fmt, statix)
nix run .#python-analysis  # Python linting (ruff, pyright)
```

Or run the complete pipeline:
```bash
./steps.sh
```

### Example

```bash
# Start server
nix run &

# Test endpoints
curl http://localhost:8000/number
curl -X POST http://localhost:8000/number -H "Content-Type: application/json" -d '{"action": "add", "value": 10}'
curl http://localhost:8000/log
```

## Project Structure

```
dummyserver/
├── flake.nix                   # Nix flake configuration
├── pyproject.toml             # Python project configuration
├── steps.sh                   # Complete analysis pipeline
├── nix/                       # Analysis tool configurations
│   ├── codegen.nix            # Code generation tools
│   ├── nix-analysis.nix       # Nix linting tools
│   └── python-analysis.nix    # Python linting tools
├── src/dummyserver/
│   ├── __init__.py
│   ├── cli.py                 # Typer CLI interface
│   ├── logging.py             # Structured logging setup
│   └── server.py              # FastAPI server
└── tests/
    └── test_server.py         # Tests with logging
```
