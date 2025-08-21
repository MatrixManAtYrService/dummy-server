"""Tests for the FastAPI server with structured logging output."""

from typing import Any

import pytest
from fastapi.testclient import TestClient
from httpx import Response

from dummyserver.logging import get_logger, setup_logging
from dummyserver.server import app

logger = get_logger("test")


@pytest.fixture(scope="session", autouse=True)
def setup_test_logging() -> None:
    """Set up logging for tests."""
    setup_logging()
    logger.info("Test session starting")


@pytest.fixture(scope="function")
def client() -> TestClient:
    """Create a test client with fresh state."""
    logger.info("Creating fresh test client")

    # Reset global state to predictable values
    import dummyserver.server as server_module
    server_module.current_number = 42
    server_module.operation_log = [{"action": "initialize", "value": 42}]

    logger.info("Reset server state", number=42)
    return TestClient(app)


def test_basic_operations_flow(client: TestClient) -> None:
    """Test basic add/subtract operations and verify responses."""
    logger.info("Starting basic operations flow test")

    # Check initial state
    response: Response = client.get("/number")
    assert response.status_code == 200
    assert response.json()["number"] == 42
    logger.info("Confirmed initial number", number=42)

    # Add 15
    response = client.post("/number", json={"action": "add", "value": 15})
    assert response.status_code == 200
    assert response.json()["number"] == 57
    logger.info("Add operation completed", result=57)

    # Subtract 7
    response = client.post("/number", json={"action": "subtract", "value": 7})
    assert response.status_code == 200
    assert response.json()["number"] == 50
    logger.info("Subtract operation completed", result=50)

    # Verify final state
    response = client.get("/number")
    assert response.status_code == 200
    assert response.json()["number"] == 50
    logger.info("Basic operations flow completed successfully", final=50)


def test_log_and_error_handling_flow(client: TestClient) -> None:
    """Test operation logging and error handling."""
    logger.info("Starting log and error handling flow test")

    # Check initial log
    response: Response = client.get("/log")
    assert response.status_code == 200
    log_data: list[dict[str, Any]] = response.json()
    assert len(log_data) == 1
    assert log_data[0]["action"] == "initialize"
    assert log_data[0]["value"] == 42
    logger.info("Initial log verified", entries=1)

    # Perform some operations
    client.post("/number", json={"action": "add", "value": 10})
    client.post("/number", json={"action": "subtract", "value": 5})
    logger.info("Performed two operations")

    # Check log has grown
    response = client.get("/log")
    log_data = response.json()
    assert len(log_data) == 3
    assert log_data[1]["action"] == "add"
    assert log_data[1]["value"] == 10
    assert log_data[2]["action"] == "subtract"
    assert log_data[2]["value"] == 5
    logger.info("Log entries verified", total_entries=3)

    # Test invalid operation
    response: Response = client.post("/number", json={"action": "multiply", "value": 3})
    assert response.status_code == 422
    logger.info("Invalid operation correctly rejected with 422")

    # Verify log unchanged after invalid operation
    response = client.get("/log")
    log_data = response.json()
    assert len(log_data) == 3  # Should still be 3, not 4
    logger.info("Log unchanged after invalid operation", entries=3)

    logger.info("Log and error handling flow completed successfully")
