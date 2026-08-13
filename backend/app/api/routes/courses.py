from datetime import date, time
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List, Optional
from app.infrastructure.database import get_db
from app.infrastructure.repositories.course_repository_impl import CourseRepositoryImpl
from app.infrastructure.repositories.time_slot_repository_impl import TimeSlotRepositoryImpl
from app.infrastructure.repositories.academic_repository_impl import CourseSubjectTeacherRepositoryImpl
from app.infrastructure.repositories.class_period_repository_impl import ClassPeriodRepositoryImpl
from app.infrastructure.repositories.preceptor_assignment_repository_impl import (
    CoursePreceptorRepositoryImpl, CoursePreceptorTempAssignmentRepositoryImpl,
)
from app.domain.usecases.course_usecases import GetCourses, GetCourseById, CreateCourse, CourseError
from app.domain.usecases.time_slot_usecases import (
    GetTimeSlotsByCourse, CreateCourseTimeSlot, DeleteTimeSlot, TimeSlotError,
)
from app.domain.usecases.academic_usecases import (
    GetCourseSubjectTeachers, AssignCourseSubjectTeacher, RemoveCourseSubjectTeacher, AcademicError,
)
from app.domain.usecases.class_period_usecases import (
    GetClassPeriodsByCourse, CreateClassPeriod, DeleteClassPeriod, ClassPeriodError,
)
from app.domain.usecases.preceptor_assignment_usecases import (
    GetCoursePreceptors, AssignCoursePreceptor, RemoveCoursePreceptor,
    GetCoursePreceptorTempAssignments, CreateCoursePreceptorTempAssignment, DeleteCoursePreceptorTempAssignment,
    PreceptorAssignmentError,
)
from pydantic import BaseModel


class CourseResponse(BaseModel):
    id: str
    academic_year: int
    grade_year: int
    division: int
    specialty: Optional[str] = None
    total_students: int
    name: str

    class Config:
        from_attributes = True


class CourseCreate(BaseModel):
    academic_year: int
    grade_year: int
    division: int
    specialty: Optional[str] = None


class TimeSlotResponse(BaseModel):
    id: str
    course_id: Optional[str] = None
    workshop_group_id: Optional[str] = None
    shift: str
    activity_type: str
    day_of_week: int
    start_time: time
    end_time: time
    late_tolerance_minutes: int


class TimeSlotCreate(BaseModel):
    shift: str
    activity_type: str  # 'main_shift' | 'after_shift'
    day_of_week: int
    start_time: time
    end_time: time
    late_tolerance_minutes: int = 0


class SubjectTeacherResponse(BaseModel):
    course_id: str
    subject_id: str
    subject_name: str
    teacher_id: str
    teacher_name: str
    teacher_email: Optional[str] = None
    teacher_phone: Optional[str] = None


class SubjectTeacherAssign(BaseModel):
    subject_id: str
    teacher_id: str


class ClassPeriodResponse(BaseModel):
    id: str
    course_id: str
    day_of_week: int
    shift: str
    period_order: int
    period_type: str
    start_time: time
    end_time: time
    is_fifth_module: bool
    subject_id: Optional[str] = None
    subject_name: Optional[str] = None
    teacher_id: Optional[str] = None
    teacher_name: Optional[str] = None


class ClassPeriodCreate(BaseModel):
    day_of_week: int
    shift: str
    period_type: str  # 'class' | 'recess' | 'lunch'
    start_time: time
    end_time: time
    subject_id: Optional[str] = None
    teacher_id: Optional[str] = None
    is_fifth_module: bool = False


class CoursePreceptorResponse(BaseModel):
    course_id: str
    shift: str
    preceptor_id: str
    preceptor_name: str


class CoursePreceptorAssign(BaseModel):
    shift: str
    preceptor_id: str


class CoursePreceptorTempResponse(BaseModel):
    id: str
    course_id: str
    shift: str
    preceptor_id: str
    preceptor_name: str
    start_date: date
    end_date: date
    reason: Optional[str] = None


class CoursePreceptorTempCreate(BaseModel):
    shift: str
    preceptor_id: str
    start_date: date
    end_date: date
    reason: Optional[str] = None
    created_by: str  # quién asigna — no hay sesión, lo elige la UI


router = APIRouter(prefix="/courses", tags=["courses"])


def _to_response(c) -> CourseResponse:
    return CourseResponse(
        id=str(c.id), academic_year=c.academic_year, grade_year=c.grade_year, division=c.division,
        specialty=c.specialty, total_students=c.total_students, name=c.name,
    )


@router.get("", response_model=List[CourseResponse])
def get_courses(db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    return [_to_response(c) for c in GetCourses(repo).execute()]


@router.post("", response_model=CourseResponse, status_code=201)
def create_course(body: CourseCreate, db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    try:
        curso = CreateCourse(repo).execute(
            academic_year=body.academic_year, grade_year=body.grade_year,
            division=body.division, specialty=body.specialty,
        )
    except CourseError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return _to_response(curso)


@router.get("/{id}", response_model=CourseResponse)
def get_course(id: str, db: Session = Depends(get_db)):
    repo = CourseRepositoryImpl(db)
    curso = GetCourseById(repo).execute(id)
    if not curso:
        raise HTTPException(status_code=404, detail="Course not found")
    return _to_response(curso)


# ── Horario: turno principal (time_slots) ───────────────────────────────────

def _time_slot_response(s) -> TimeSlotResponse:
    return TimeSlotResponse(
        id=s.id, course_id=s.course_id, workshop_group_id=s.workshop_group_id,
        shift=s.shift, activity_type=s.activity_type, day_of_week=s.day_of_week,
        start_time=s.start_time, end_time=s.end_time,
        late_tolerance_minutes=s.late_tolerance_minutes,
    )


@router.get("/{id}/time-slots", response_model=List[TimeSlotResponse])
def get_course_time_slots(id: str, db: Session = Depends(get_db)):
    repo = TimeSlotRepositoryImpl(db)
    slots = GetTimeSlotsByCourse(repo).execute(id)
    return [_time_slot_response(s) for s in slots]


@router.post("/{id}/time-slots", response_model=TimeSlotResponse, status_code=201)
def create_course_time_slot(id: str, body: TimeSlotCreate, db: Session = Depends(get_db)):
    repo = TimeSlotRepositoryImpl(db)
    try:
        slot = CreateCourseTimeSlot(repo).execute(
            course_id=id, shift=body.shift, activity_type=body.activity_type,
            day_of_week=body.day_of_week, start_time=body.start_time, end_time=body.end_time,
            late_tolerance_minutes=body.late_tolerance_minutes,
        )
    except TimeSlotError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except ValueError:
        raise HTTPException(status_code=400, detail="shift o activity_type inválido.")
    return _time_slot_response(slot)


@router.delete("/{id}/time-slots/{slot_id}", status_code=204)
def delete_course_time_slot(id: str, slot_id: str, db: Session = Depends(get_db)):
    repo = TimeSlotRepositoryImpl(db)
    ok = DeleteTimeSlot(repo).execute(slot_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Time slot not found")
    return None


# ── Horario: detallado día por día (class_periods) ──────────────────────────

def _class_period_response(p) -> ClassPeriodResponse:
    return ClassPeriodResponse(
        id=p.id, course_id=p.course_id, day_of_week=p.day_of_week, shift=p.shift,
        period_order=p.period_order, period_type=p.period_type,
        start_time=p.start_time, end_time=p.end_time, is_fifth_module=p.is_fifth_module,
        subject_id=p.subject_id, subject_name=p.subject_name,
        teacher_id=p.teacher_id, teacher_name=p.teacher_name,
    )


@router.get("/{id}/class-periods", response_model=List[ClassPeriodResponse])
def get_class_periods(id: str, db: Session = Depends(get_db)):
    repo = ClassPeriodRepositoryImpl(db)
    return [_class_period_response(p) for p in GetClassPeriodsByCourse(repo).execute(id)]


@router.post("/{id}/class-periods", response_model=ClassPeriodResponse, status_code=201)
def create_class_period(id: str, body: ClassPeriodCreate, db: Session = Depends(get_db)):
    repo = ClassPeriodRepositoryImpl(db)
    try:
        period = CreateClassPeriod(repo).execute(
            course_id=id, day_of_week=body.day_of_week, shift=body.shift, period_type=body.period_type,
            start_time=body.start_time, end_time=body.end_time,
            subject_id=body.subject_id, teacher_id=body.teacher_id, is_fifth_module=body.is_fifth_module,
        )
    except ClassPeriodError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except ValueError:
        raise HTTPException(status_code=400, detail="shift o period_type inválido.")
    return _class_period_response(period)


@router.delete("/{id}/class-periods/{period_id}", status_code=204)
def delete_class_period(id: str, period_id: str, db: Session = Depends(get_db)):
    repo = ClassPeriodRepositoryImpl(db)
    ok = DeleteClassPeriod(repo).execute(period_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Class period not found")
    return None


# ── Materias y profesores del curso ──────────────────────────────────────────

@router.get("/{id}/subject-teachers", response_model=List[SubjectTeacherResponse])
def get_course_subject_teachers(id: str, db: Session = Depends(get_db)):
    repo = CourseSubjectTeacherRepositoryImpl(db)
    rows = GetCourseSubjectTeachers(repo).execute(id)
    return [SubjectTeacherResponse(**r.__dict__) for r in rows]


@router.post("/{id}/subject-teachers", response_model=SubjectTeacherResponse, status_code=201)
def assign_course_subject_teacher(id: str, body: SubjectTeacherAssign, db: Session = Depends(get_db)):
    repo = CourseSubjectTeacherRepositoryImpl(db)
    try:
        row = AssignCourseSubjectTeacher(repo).execute(id, body.subject_id, body.teacher_id)
    except AcademicError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    return SubjectTeacherResponse(**row.__dict__)


@router.delete("/{id}/subject-teachers/{subject_id}", status_code=204)
def remove_course_subject_teacher(id: str, subject_id: str, db: Session = Depends(get_db)):
    repo = CourseSubjectTeacherRepositoryImpl(db)
    ok = RemoveCourseSubjectTeacher(repo).execute(id, subject_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return None


# ── Preceptores ───────────────────────────────────────────────────────────────

@router.get("/{id}/preceptors", response_model=List[CoursePreceptorResponse])
def get_course_preceptors(id: str, db: Session = Depends(get_db)):
    repo = CoursePreceptorRepositoryImpl(db)
    return [CoursePreceptorResponse(**r.__dict__) for r in GetCoursePreceptors(repo).execute(id)]


@router.post("/{id}/preceptors", response_model=CoursePreceptorResponse, status_code=201)
def assign_course_preceptor(id: str, body: CoursePreceptorAssign, db: Session = Depends(get_db)):
    repo = CoursePreceptorRepositoryImpl(db)
    try:
        row = AssignCoursePreceptor(repo).execute(id, body.shift, body.preceptor_id)
    except PreceptorAssignmentError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except ValueError:
        raise HTTPException(status_code=400, detail="shift inválido.")
    return CoursePreceptorResponse(**row.__dict__)


@router.delete("/{id}/preceptors/{shift}", status_code=204)
def remove_course_preceptor(id: str, shift: str, db: Session = Depends(get_db)):
    repo = CoursePreceptorRepositoryImpl(db)
    ok = RemoveCoursePreceptor(repo).execute(id, shift)
    if not ok:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return None


@router.get("/{id}/preceptor-temp-assignments", response_model=List[CoursePreceptorTempResponse])
def get_course_preceptor_temp_assignments(id: str, db: Session = Depends(get_db)):
    repo = CoursePreceptorTempAssignmentRepositoryImpl(db)
    return [CoursePreceptorTempResponse(**r.__dict__) for r in GetCoursePreceptorTempAssignments(repo).execute(id)]


@router.post("/{id}/preceptor-temp-assignments", response_model=CoursePreceptorTempResponse, status_code=201)
def create_course_preceptor_temp_assignment(id: str, body: CoursePreceptorTempCreate, db: Session = Depends(get_db)):
    repo = CoursePreceptorTempAssignmentRepositoryImpl(db)
    try:
        row = CreateCoursePreceptorTempAssignment(repo).execute(
            course_id=id, shift=body.shift, preceptor_id=body.preceptor_id,
            start_date=body.start_date, end_date=body.end_date,
            reason=body.reason, created_by=body.created_by,
        )
    except PreceptorAssignmentError as e:
        raise HTTPException(status_code=e.status_code, detail=str(e))
    except ValueError:
        raise HTTPException(status_code=400, detail="shift inválido.")
    return CoursePreceptorTempResponse(**row.__dict__)


@router.delete("/{id}/preceptor-temp-assignments/{assignment_id}", status_code=204)
def delete_course_preceptor_temp_assignment(id: str, assignment_id: str, db: Session = Depends(get_db)):
    repo = CoursePreceptorTempAssignmentRepositoryImpl(db)
    ok = DeleteCoursePreceptorTempAssignment(repo).execute(assignment_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Assignment not found")
    return None
