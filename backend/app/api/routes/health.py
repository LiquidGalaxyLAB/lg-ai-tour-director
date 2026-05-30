"""Health check API routes."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/", tags=["health"])
async def health_check() -> dict:
	return {"status": "ok"}
