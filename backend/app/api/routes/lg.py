"""Liquid Galaxy API routes."""
from fastapi import APIRouter

router = APIRouter()


@router.post("/deploy", tags=["lg"])
async def deploy_to_lg() -> dict:
	return {"result": "scheduled"}
