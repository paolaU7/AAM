from typing import Protocol
from datetime import date
from ...models.registro_asistencia import RegistroAsistencia
from ...value_objects               import Turno


class RepositorioAsistencia(Protocol):
    def guardar(self, registro: RegistroAsistencia) -> None: ...
    def existePorId(self, id: str)                  -> bool: ...
    def porAlumnoYFecha(
        self,
        id_alumno: str,
        fecha:     date,
    ) -> list[RegistroAsistencia]: ...
    def porCursoYFecha(
        self,
        id_curso: str,
        fecha:    date,
    ) -> list[RegistroAsistencia]: ...
    def actualizar(self, registro: RegistroAsistencia) -> None: ...
