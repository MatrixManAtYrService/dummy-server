"""CLI interface for dummyserver."""

import json

import typer
import uvicorn

from .logging import get_logger

app = typer.Typer()
logger = get_logger("cli")


@app.command()
def serve(
    host: str = typer.Option("0.0.0.0", help="Host to bind to"),
    port: int = typer.Option(8000, help="Port to bind to"),
    reload: bool = typer.Option(False, help="Enable auto-reload for development"),
) -> None:
    """Start the dummyserver FastAPI application."""
    from .logging import setup_logging
    from .server import app as fastapi_app

    setup_logging()
    logger.info("Starting dummyserver", host=host, port=port, reload=reload)

    uvicorn.run(
        fastapi_app,
        host=host,
        port=port,
        reload=reload,
    )


@app.command()
def openapi() -> None:
    """Export OpenAPI specification to stdout."""
    from .server import app as fastapi_app
    
    openapi_spec = fastapi_app.openapi()
    print(json.dumps(openapi_spec, indent=2))


def main() -> None:
    app()


if __name__ == "__main__":
    main()
