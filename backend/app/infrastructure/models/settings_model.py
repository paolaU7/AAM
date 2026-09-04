from sqlalchemy import Column, String, Text, Boolean, SmallInteger, TIMESTAMP, CheckConstraint
from sqlalchemy.sql import func
from app.infrastructure.database import Base


class SpecialtyModel(Base):
    """Catálogo de especialidades (Programación, Construcciones, Electrónica,
    Ciclo Básico). Editable a futuro desde Configuración. "Ciclo Básico" es
    la única con is_basic_cycle=True — se asigna sola a cursos de 1ro a 3ro,
    nunca la elige el usuario a mano (ver trigger `enforce_basic_cycle_specialty`
    en la DB, y la validación espejo en CreateCourse/UpdateCourse)."""
    __tablename__ = "specialties"

    id             = Column(String(36), primary_key=True, server_default=func.gen_random_uuid())
    name           = Column(Text, nullable=False, unique=True)
    is_basic_cycle = Column(Boolean, nullable=False, default=False)
    created_at     = Column(TIMESTAMP(timezone=True), nullable=False, server_default=func.now())


class SchoolSettingsModel(Base):
    """Fila única de configuración general (techo de año de cursada y de
    división que se ofrecen en los desplegables de alta de curso, más los
    umbrales del panel de notificaciones). Editable a futuro desde
    Configuración. `id` es BOOLEAN con CHECK(id) para forzar una sola fila
    posible en la tabla."""
    __tablename__ = "school_settings"

    id             = Column(Boolean, primary_key=True, default=True)
    max_grade_year = Column(SmallInteger, nullable=False, default=7)
    max_division   = Column(SmallInteger, nullable=False, default=4)
    # Umbrales para las alertas del panel (campana de notificaciones):
    consecutive_absences_alert_threshold = Column(SmallInteger, nullable=False, default=3)
    preceptor_temp_assignment_alert_days = Column(SmallInteger, nullable=False, default=2)
    schedule_exception_alert_days        = Column(SmallInteger, nullable=False, default=2)

    __table_args__ = (
        CheckConstraint("max_grade_year BETWEEN 1 AND 7", name="ck_school_settings_max_grade_year"),
        CheckConstraint("max_division > 0", name="ck_school_settings_max_division"),
        CheckConstraint("consecutive_absences_alert_threshold > 0", name="ck_school_settings_absences_threshold"),
        CheckConstraint("preceptor_temp_assignment_alert_days >= 0", name="ck_school_settings_preceptor_alert_days"),
        CheckConstraint("schedule_exception_alert_days >= 0", name="ck_school_settings_exception_alert_days"),
    )
