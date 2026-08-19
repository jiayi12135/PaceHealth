from fastapi import FastAPI

from app.core.config import get_settings
from app.errors import APIError, api_error_handler
<<<<<<< Updated upstream
from app.routers.auth import router as auth_router
=======
from app.routers.ai import router as ai_router
from app.routers.auth import router as auth_router
from app.routers.scans import router as scans_router
>>>>>>> Stashed changes
from app.routers.users import router as users_router
from app.routers.weights import router as weights_router


settings = get_settings()
app = FastAPI(title=settings.app_name, version=settings.app_version)
app.add_exception_handler(APIError, api_error_handler)
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(weights_router)
<<<<<<< Updated upstream
=======
app.include_router(ai_router)
app.include_router(scans_router)
>>>>>>> Stashed changes


@app.get("/health", tags=["health"])
def health_check() -> dict[str, str]:
    """Return a lightweight readiness response for the API."""
    return {"status": "ok"}
