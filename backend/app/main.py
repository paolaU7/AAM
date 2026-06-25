from fastapi import FastAPI
from app.api.routes import health, cursos, alumnos

app = FastAPI(title="AAM API", version="0.1.0")

app.include_router(health.router)
app.include_router(cursos.router)
app.include_router(alumnos.router)