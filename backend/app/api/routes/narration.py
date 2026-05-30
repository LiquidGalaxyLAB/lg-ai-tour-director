"""Narration API routes."""
from fastapi import APIRouter

router = APIRouter()


@router.post("/generate", tags=["narration"])
async def generate_narration(prompt: str = "") -> dict:
	return {"narration": ""}
