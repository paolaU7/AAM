from dataclasses import dataclass


@dataclass(frozen=True)
class WorkshopGroup:
    """Subdivisión interna de UN curso puntual (Grupo A, B, C...), no algo
    compartido entre cursos — 4to 1ra y 4to 2da tienen sus propios grupos,
    aunque cursen las mismas materias de taller. Único por (course_id,
    group_label)."""

    id: str
    course_id: str
    group_label: str

    @property
    def name(self) -> str:
        return self.group_label
