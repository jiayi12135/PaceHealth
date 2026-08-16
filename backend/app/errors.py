from fastapi import Request
from fastapi.responses import JSONResponse


class APIError(Exception):
    """An expected API failure with a stable client-facing error code."""

    def __init__(self, status_code: int, message: str, error_code: str) -> None:
        self.status_code = status_code
        self.message = message
        self.error_code = error_code


async def api_error_handler(_request: Request, exc: APIError) -> JSONResponse:
    return JSONResponse(
        status_code=exc.status_code,
        content={
            "success": False,
            "message": exc.message,
            "data": {"errorCode": exc.error_code},
        },
    )
