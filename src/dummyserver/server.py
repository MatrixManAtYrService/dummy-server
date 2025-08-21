"""FastAPI server with simple number operations and structured logging."""

import random
from collections.abc import AsyncGenerator
from contextlib import asynccontextmanager
from enum import Enum
from typing import Any

from fastapi import FastAPI
from pydantic import BaseModel

from .logging import get_logger

logger = get_logger("server")

# Global state
current_number: int = 0
operation_log: list[dict[str, Any]] = []


class ActionType(str, Enum):
    """Valid operation actions."""
    ADD = "add"
    SUBTRACT = "subtract"


class NumberOperation(BaseModel):
    """Request model for number operations."""
    action: ActionType
    value: int


class NumberResponse(BaseModel):
    """Response model for number operations."""
    number: int


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncGenerator[None, None]:
    """Manage FastAPI application lifespan."""
    global current_number, operation_log

    logger.info("Server starting up")

    # Initialize with random number
    current_number = random.randint(1, 100)
    operation_log = [{"action": "initialize", "value": current_number}]

    logger.info("Initialized number", number=current_number)

    try:
        yield
    finally:
        logger.info("Server shutting down")


app = FastAPI(title="Dummy Server", lifespan=lifespan)


@app.get("/")
async def root() -> dict[str, str]:
    """Root endpoint."""
    logger.info("Root endpoint called")
    return {"message": "Hello from Dummy Server! Try GET/POST /number or GET /log"}


@app.get("/number", response_model=NumberResponse)
async def get_number() -> NumberResponse:
    """Get the current number."""
    logger.info("Getting current number", number=current_number)
    return NumberResponse(number=current_number)


@app.post("/number", response_model=NumberResponse)
async def modify_number(operation: NumberOperation) -> NumberResponse:
    """Modify the current number."""
    global current_number

    logger.info("Received operation", action=operation.action, value=operation.value, current=current_number)

    if operation.action == ActionType.ADD:
        current_number += operation.value
    elif operation.action == ActionType.SUBTRACT:
        current_number -= operation.value

    # Log the operation
    operation_log.append({
        "action": operation.action.value,
        "value": operation.value
    })

    logger.info("Number updated", new_number=current_number, operation=operation.action, value=operation.value)

    return NumberResponse(number=current_number)


@app.get("/log")
async def get_log() -> list[dict[str, Any]]:
    """Get the log of all operations."""
    logger.info("Returning operation log", count=len(operation_log))
    return operation_log
