"""Import all ORM models so they register on Base.metadata and string-based
relationships resolve regardless of which routers are loaded."""

from app.infrastructure.models.course_model import (
    CourseModel, WorkshopGroupModel,
)
from app.infrastructure.models.student_model import (
    StudentModel,
)
from app.infrastructure.models.user_model import (
    UserModel, PreceptorCourseAssignmentModel, DeviceModel, UserRoleEnum,
)
from app.infrastructure.models.schedule_model import (
    TimeSlotModel, ScheduleExceptionModel,
    ShiftTypeEnum, ActivityTypeEnum,
)
from app.infrastructure.models.academic_model import (
    SubjectModel, TeacherModel, CourseSubjectTeacherModel, ClassPeriodModel,
    PeriodTypeEnum,
)
from app.infrastructure.models.preceptor_model import (
    CoursePreceptorModel, CoursePreceptorTempAssignmentModel,
)
from app.infrastructure.models.attendance_model import (
    AttendanceRecordModel, EarlyDepartureModel,
    AttendanceStatusEnum, AttendanceSourceEnum,
)

__all__ = [
    "CourseModel", "WorkshopGroupModel",
    "StudentModel",
    "UserModel", "PreceptorCourseAssignmentModel", "DeviceModel", "UserRoleEnum",
    "TimeSlotModel", "ScheduleExceptionModel",
    "ShiftTypeEnum", "ActivityTypeEnum",
    "SubjectModel", "TeacherModel", "CourseSubjectTeacherModel", "ClassPeriodModel",
    "PeriodTypeEnum",
    "CoursePreceptorModel", "CoursePreceptorTempAssignmentModel",
    "AttendanceRecordModel", "EarlyDepartureModel",
    "AttendanceStatusEnum", "AttendanceSourceEnum",
]
