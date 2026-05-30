"""Tour API routes."""
from fastapi import APIRouter

router = APIRouter()


@router.get("/", tags=["tour"])
async def list_tours() -> dict:
	return {"tours": []}
