"""Import all ORM models so they register on Base.metadata and string-based
relationships resolve regardless of which routers are loaded."""

from app.infrastructure.models.course_model import (
    AcademicYearModel, DivisionModel, SpecialtyModel, ShiftModel,
    WorkshopGroupModel, CourseModel, course_workshop_groups,
)
from app.infrastructure.models.student_model import (
    StudentModel, StudentCourseEnrollmentModel, RepeatingSubjectModel,
    EnrollmentTypeEnum, student_workshop_groups,
)
from app.infrastructure.models.user_model import (
    UserModel, PreceptorCourseAssignmentModel, DeviceModel, UserRoleEnum,
)
from app.infrastructure.models.schedule_model import (
    ScheduleSlotModel, ScheduleExceptionModel,
    ActivityTypeEnum, ExceptionScopeEnum,
)
from app.infrastructure.models.attendance_model import (
    AttendanceRecordModel, EarlyDepartureModel, NonComputableAbsenceModel,
    AttendanceStatusEnum, AttendanceSourceEnum, NonComputableReasonEnum,
)

__all__ = [
    "AcademicYearModel", "DivisionModel", "SpecialtyModel", "ShiftModel",
    "WorkshopGroupModel", "CourseModel", "course_workshop_groups",
    "StudentModel", "StudentCourseEnrollmentModel", "RepeatingSubjectModel",
    "EnrollmentTypeEnum", "student_workshop_groups",
    "UserModel", "PreceptorCourseAssignmentModel", "DeviceModel", "UserRoleEnum",
    "ScheduleSlotModel", "ScheduleExceptionModel",
    "ActivityTypeEnum", "ExceptionScopeEnum",
    "AttendanceRecordModel", "EarlyDepartureModel", "NonComputableAbsenceModel",
    "AttendanceStatusEnum", "AttendanceSourceEnum", "NonComputableReasonEnum",
]
