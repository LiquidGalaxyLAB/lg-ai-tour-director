"""Library API routes."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/", tags=["library"])
async def list_library() -> dict:
	return {"items": []}
