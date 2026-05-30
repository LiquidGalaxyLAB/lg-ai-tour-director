"""Backend application entrypoint."""
from fastapi import FastAPI

from app.api.routes.health import router as health_router
from app.api.routes.tour import router as tour_router
from app.api.routes.lg import router as lg_router
from app.api.routes.library import router as library_router
from app.api.routes.narration import router as narration_router


def create_app() -> FastAPI:
	app = FastAPI(title="LG AI Tour Director API")
	app.include_router(health_router, prefix="/health")
	app.include_router(tour_router, prefix="/tour")
	app.include_router(lg_router, prefix="/lg")
	app.include_router(library_router, prefix="/library")
	app.include_router(narration_router, prefix="/narration")
	return app


app = create_app()


if __name__ == "__main__":
	import uvicorn

	uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
