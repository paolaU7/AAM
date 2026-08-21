from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import health, students
from app.api.routes.courses import router as courses_router
from app.api.routes.workshop_groups import router as workshop_groups_router
from app.api.routes.users import router as users_router
from app.api.routes.attendance import router as attendance_router
from app.api.routes.academic import router as academic_router

app = FastAPI(title="AAM API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(courses_router)
app.include_router(workshop_groups_router)
app.include_router(students.router)
app.include_router(users_router)
app.include_router(attendance_router)
app.include_router(academic_router)