 AAM — Tareas de refinamiento del Panel de Dirección (por persona)

> Alcance: todo lo reportado EXCEPTO la sección "Implementaciones" (Panel de
> Preceptores + licencias de preceptor), que queda para otra tanda por ser
> features nuevas grandes, no arreglos sobre lo existente.



 ⚠️ Leer antes de arrancar: cambios de schema compartido

Cuatro de estas tareas necesitan modificar `schema.sql`, que es un
archivo único compartido por las 4 secciones. Si cada persona lo edita por
su cuenta en paralelo, van a pisarse los cambios. Antes de que cada uno
arranque su parte:

1. Junten estas 4 modificaciones en un solo commit/PR de schema, aplicado
   por una sola persona (o coordinado en una llamada rápida), ANTES de que
   el resto empiece a codear sobre las tablas nuevas.
2. Las 4 modificaciones necesarias:
    Persona 1 (Cursos): tabla nueva `teacher_subjects` (qué materias
     puede dictar cada profesor, catálogo global) + reestructurar
     `course_preceptors` para permitir varios preceptores permanentes por
     `(course_id, shift)`, cada uno con sus días asignados.
    Persona 2 (Profesores): columnas de estado/licencia en `teachers`
     (activo / de baja / licencia médica / vacaciones, con motivo y fecha
     de retorno).
    Persona 3 (Materias): columna `short_code` en `subjects` (el
     identificador corto tipo "M6t").
    Persona 4 (Configuración): columna `lunch_end_fifth_module` en
     `school_settings` (hoy solo existe `lunch_end` único, compartido por
     el almuerzo con y sin 5º módulo — hace falta separarlo).

El detalle técnico de cada una está dentro de la tarea correspondiente más
abajo.



 👤 Uli 1 — Cursos (10 tareas)

Sección con más lógica de negocio. Alcance: pantalla de detalle de un
curso (horario semanal, horario detallado, materias y profesores del
curso, preceptores del curso).

1. Simetría de espacios izq/der. El layout del detalle de curso tiene
   más padding a la izquierda que a la derecha. Revisar el contenedor
   principal de la pantalla: probablemente un padding asimétrico
   hardcodeado en vez de usar el mismo valor en ambos lados (según la guía
   de estilo, 28–32px de padding interno). Igualar.

2. Editar y deshabilitar horarios del horario semanal. Cada fila de
   `time_slots` necesita dos acciones nuevas: editar (abre el mismo
   formulario de alta, precargado) y deshabilitar. "Deshabilitar" no debe
   ser un borrado físico — agregar columna `is_active BOOLEAN NOT NULL
   DEFAULT TRUE` a `time_slots` en el schema compartido (ver nota de
   arriba) y que el toggle haga `UPDATE ... SET is_active = false` en vez
   de `DELETE`. Los horarios deshabilitados no deberían contarse para la
   validación de superposición con recreos ni mostrarse en la vista activa
   por defecto.

3. Orden de horarios en horario semanal. Al listar `time_slots`,
   ordenar SIEMPRE por: 1º `day_of_week` (lunes→domingo), 2º `shift` con
   el criterio mañana → tarde → vespertino (no alfabético — hay que mapear
   el enum a un orden numérico explícito en el query o en el frontend, ya
   que alfabéticamente "afternoon" < "evening" < "morning" no es el orden
   que se quiere).

4. Igualar ancho horario detallado / horario semanal. Ambos widgets
   deben ocupar el mismo `maxWidth` del contenedor. Revisar si uno está
   usando un `Container` con ancho fijo en px y el otro un `Expanded`/
   `flex` — unificar al mismo criterio.

5. Detalle de materia al hacer click (horario detallado). Al tocar un
   `class_period` de tipo `class`, abrir un modal/bottom sheet con: nombre
   de la materia, profesor asignado, horario (start_time–end_time). Abajo,
   3 botones: Editar, Eliminar, Cancelar. Editar reabre el formulario de
   carga precargado; Eliminar hace `DELETE` del `class_period` puntual
   (con confirmación).

6. Detalle de recreo al hacer click (horario detallado). Al tocar un
   `class_period` de tipo `recess`/`lunch`, abrir un modal de solo lectura
   con: turno, duración, rango horario, nombre/label. SIN botones de
   editar/eliminar — agregar un texto aclaratorio tipo "Los recreos se
   configuran desde Configuración → General".

7. Filtrar profesores por materia habilitada (requiere schema nuevo).
   Hoy, al asignar profesor a una materia de un curso, el select muestra
   TODOS los `teachers`. Tiene que mostrar solo los habilitados para esa
   materia específica. Requiere la tabla nueva `teacher_subjects
   (teacher_id, subject_id)` mencionada arriba — el select de profesores
   de este formulario debe filtrar por
   `WHERE subject_id = :materia_seleccionada`.

8. Filtrar preceptor reemplazante por turno/licencia (bloqueada,
   depende de "Implementaciones"). El select de preceptor reemplazante
   no debe mostrar: (a) preceptores no asignados a ese `course_id`+`shift`
   puntual, ni (b) preceptores actualmente de licencia médica/vacaciones.
   El punto (b) depende del campo de estado de licencia que se agrega en
   "Implementaciones" (todavía no existe) — dejar el filtro de turno (a)
   funcionando ahora, y el de licencia (b) como `TODO` comentado hasta que
   ese campo exista.

9. Mostrar estado del preceptor titular (bloqueada, misma dependencia
   que el punto 8). Mismo caso: mostrar si está de licencia/vacaciones/
   baja requiere el campo que todavía no existe. Dejar el layout
   preparado con un placeholder ("Activo") hasta que se pueda leer el
   estado real.

10. Múltiples preceptores permanentes por turno con días asignados
    (requiere schema nuevo). Hoy `course_preceptors` tiene PK
    `(course_id, shift)` — un solo preceptor por curso+turno. Hay que
    permitir varios, cada uno con los días de semana que le tocan, sin que
    dos preceptores del mismo curso+turno compartan un día. Cambiar a:

    ```sql
     reemplaza la tabla course_preceptors actual
    CREATE TABLE course_preceptors (
        id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        course_id     UUID NOT NULL REFERENCES courses(id) ON DELETE CASCADE,
        shift         shift_type NOT NULL,
        preceptor_id  UUID NOT NULL REFERENCES users(id),
        day_of_week   SMALLINT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
        UNIQUE (course_id, shift, day_of_week)  un solo preceptor por día
    );
    ```
    Nota: un mismo preceptor puede repetirse en varias filas (distintos
    días); lo que no puede pasar es que dos preceptores DISTINTOS tengan
    el mismo día en el mismo curso+turno — eso ya lo garantiza el
    `UNIQUE`. El `UNIQUE` no distingue nada especial entre mañana/tarde a
    propósito: como pediste, el mismo día SÍ puede repetirse entre turnos
    distintos (mañana y tarde), porque `shift` es parte de la clave.



 👤 Tito — Profesores + Bugs (7 tareas)

 Profesores

1. Cambiar título de la sección a "Profesores" (hoy dice otra cosa en
   el menú/header — corregir el string en el sidebar y en el título de la
   pantalla).

2. Asignación por año/especialidad, no por curso puntual. Al asignar
   un profesor a una materia, el formulario debe pedir: año (`grade_year`)
   y, si `grade_year >= 4`, también especialidad (`specialty_id`) — para
   1º a 3º no se pide especialidad porque siempre es "Ciclo Básico". Con
   esos dos datos, el select de materias se filtra contra
   `subject_applicability` para esa combinación (`grade_year` +
   `specialty_id`), mostrando solo las materias habilitadas para ese
   año/especialidad — no todas las materias del sistema.

3. Columna "Materias asignadas" en la tabla + vista detallada. Nueva
   columna que muestra, por profesor, los identificadores cortos
   (`short_code`, ver tarea de Materias de Persona 3) de las materias que
   dicta, separados por coma. Al hacer click en esa celda, abrir un modal
   con el detalle completo (nombre completo de cada materia, curso, año).

4. Botones de acción por profesor: eliminar, editar, dar de baja,
   licencia médica/vacaciones. "Eliminar" y "dar de baja" son cosas
   distintas: eliminar es borrado físico (bloquear con 400 si el profesor
   tiene `course_subject_teachers` asociados, igual que ya se hace con
   otras entidades referenciadas). "Dar de baja" y "licencia" actualizan
   el campo de estado nuevo en `teachers` (ver la migración pendiente de
   la sección de arriba) con motivo y fecha de retorno.

5. Filtro por materia (con `short_code`) + lupa. Agregar un selector
   de materia (mostrando el código corto, no el nombre completo) y un
   campo de búsqueda libre por nombre de profesor.

6. Arreglar visual: "curricular" no se lee en modo oscuro (dos
   lugares). Pasa tanto en la tabla de Materias como dentro de
   "Gestionar materias" de cada profesor. Revisar el badge/chip que marca
   `subject_type = curricular`: seguramente tiene texto oscuro
   hardcodeado sobre fondo que en modo oscuro también queda oscuro (bajo
   contraste). Usar el color de texto del theme, no un valor fijo.

 Bugs

7. Saludo del panel de admin no es dinámico. El "Buenos días,
   Dirección" del dashboard debe calcularse según la hora real (mañana /
   tarde / noche) y no estar hardcodeado. Revisar si ya existe una
   función de saludo dinámico en otra pantalla del proyecto para reusarla.



 👤 Pao — Materias + Alumnos (8 tareas)

 Materias

1. Filtros: taller/curricular, año, especialidad + lupa. Agregar los
   3 selects de filtro más el campo de búsqueda por nombre, todos
   combinables (AND entre filtros).

2. Error legible al crear materia con nombre duplicado. Hoy el
   `UNIQUE(name)` de `subjects` está devolviendo el error crudo de
   Postgres. Mapear el código `23505` (unique_violation) a un mensaje
   claro tipo "Ya existe una materia llamada '{nombre}'".

3. Arreglar "curricular" en modo oscuro — mismo bug que la tarea 6 de
   Persona 2, pero en la tabla de Materias (probablemente el mismo
   componente reusado; coordinar con Persona 2 para no arreglarlo dos
   veces por separado).

4. Columna "Años asignados". Mostrar, por materia, todos los
   `grade_year` en los que tiene `subject_applicability`, separados por
   coma, con la especialidad entre paréntesis cuando aplica (ej: "1ro,
   3ro, 5to (E)" donde E/P/C abrevia la especialidad — Electrónica/
   Programación/Construcciones).

5. Identificador corto de materia (requiere schema nuevo). Agregar
   columna `short_code TEXT` a `subjects` (parte de la migración
   compartida mencionada arriba). Patrón sugerido: primera letra
   significativa del nombre en mayúscula + año(s) al que aplica, ej.
   "Matemática" aplicable a 1º y 6º → `M1r6t`; si aplica a un solo año,
   simplemente `M6t`. Para materias de nombre compuesto, usar la primera
   letra de cada palabra relevante (ej. "Lengua y Literatura" → `LL`).
   Generarlo automáticamente al crear/editar la materia (recalculando si
   cambian los años de `subject_applicability`), pero permitir edición
   manual por si el autogenerado queda ambiguo entre dos materias.

 Alumnos

6. Arreglar visual de filtros (layout roto). Revisar el
   `Row`/`Wrap` de filtros de la pantalla de Alumnos — probablemente un
   `Expanded` faltante o un ancho fijo que no responde bien en pantallas
   angostas.

7. Mostrar especialidad además del curso en el detalle del alumno.
   Al tocar el ícono de "ver" (ojito), además del curso (ej. "4to 2da"),
   mostrar la especialidad de ese curso (`courses.specialty_id` →
   `specialties.name`).

8. Permitir eliminar alumno solo si está dado de baja. El botón de
   eliminar (borrado físico) debe estar deshabilitado/oculto mientras
   `students.is_active = true`. Solo habilitarlo cuando el alumno ya fue
   dado de baja (`is_active = false`). Si se intenta eliminar sin cumplir
   la condición, el backend debe rechazar con 400 igual (no confiar solo
   en el frontend).


   
 👤 Juani — Asistencia + Usuarios + Reportes + Configuración (14 tareas)

 Asistencia

1. Error al cambiar el curso del select. Pantalla se rompe (fondo
   rojo, error de Flutter) al cambiar `course_id` en el selector. Revisar
   si el widget que pinta la tabla de asistencia asume que ciertos campos
   (ej. `course.specialty_id`, o algún campo anidado) siempre vienen no
   nulos al recargar con un curso distinto — probablemente un `late
   initialization` o acceso a un valor null sin `?.`.

2. Mismo error al cambiar la fecha. Muy probablemente la misma causa
   raíz que el punto 1 (el widget no maneja bien el estado de "recargando"
   entre un fetch y el siguiente). Investigar juntos, puede ser un solo
   fix.

3. Error visual (amarillo y negro) con nombres largos. Es el overflow
   error clásico de Flutter (`RenderFlex overflowed`). Envolver el texto
   del nombre del alumno en la tabla con `Expanded` + `overflow:
   TextOverflow.ellipsis`, o truncar manualmente si la celda tiene ancho
   fijo.

 Usuarios

4. Arreglar separación horizontal de la tabla (se ve amontonado).
   Revisar el `DataTable`/tabla custom: probablemente falta padding entre
   columnas o el ancho de columna se está calculando automático en vez de
   fijo/proporcional. Ajustar a los mismos paddings de tabla usados en
   otras pantallas del panel (para consistencia).

5. Filtros por rol, estado + lupa. Agregar select de `role`
   (principal/jefe_preceptores/preceptor), select de estado
   (activo/inactivo, `is_active`), y búsqueda libre por nombre/email.

 Reportes

6. Simetría vertical entre selects en exportación personalizada.
   Ajustar el layout para que todos los selects tengan la misma altura y
   separación vertical entre sí.

7. Cambiar texto de botones a "Exportar Excel" / "Exportar PDF" (hoy
   dicen "Generar Excel"/"Generar PDF" o similar).

8. Centrar y hacer simétricos selects + botones de exportación.
   Mismo criterio de alineación para todo el bloque.

9. Filtro de año y división por separado, sacar filtro de curso. Hoy
   probablemente hay un solo select de "curso" (que ya implica año+
   división combinados). Separarlo en dos selects independientes: Año
   (`grade_year`) y División (`division`).

10. División depende del año elegido; turno depende de la división.
    Al elegir un año, el select de División debe filtrarse a las
    divisiones que existen para ese `grade_year` (consultar
    `year_structure`, o directamente los `courses` existentes de ese
    año). Al elegir año+división (o sea, quedar resuelto un `course_id`),
    el select de Turno debe mostrar solo los turnos en los que ese curso
    tiene `time_slots`/`course_preceptors` cargados — no los 3 turnos
    fijos siempre.

 Configuración

11. Acomodar horizontalmente las tarjetas de General y Cursos para
    que ocupen el máximo espacio disponible (revisar si están en una
    `Column` cuando deberían estar en un `Wrap`/`GridView` responsivo).

12. Botones de "Guardar cambios" a la derecha (hoy están a la
    izquierda) — cambio de alineación en cada card de Configuración que
    tenga ese botón.

13. Acomodar la tabla de Dispositivos (info amontonada
    horizontalmente) — mismo criterio que la tarea 4 de Usuarios,
    posiblemente se pueda resolver con el mismo componente de tabla
    reusado (misma persona en ambas secciones, se puede resolver junto).

14. Separar almuerzo con/sin 5º módulo en dos filas independientes,
    cada una con su propio inicio y fin (requiere schema nuevo). Hoy
    `school_settings` tiene `lunch_start`, `lunch_start_fifth_module` y
    UN SOLO `lunch_end` compartido por ambos casos. Hace falta agregar
    `lunch_end_fifth_module TIME NOT NULL` (parte de la migración
    compartida mencionada arriba), con su propio `CHECK
    (lunch_start_fifth_module < lunch_end_fifth_module)`. En la UI,
    mostrar dos filas: "Almuerzo normal: [inicio] – [fin]" y "Almuerzo
    con 5º módulo: [inicio] – [fin]", cada campo editable por separado.



 Resumen de carga

| Persona | Sección | Tareas | Incluye cambio de schema |
|||||
| 1 | Cursos | 10 | Sí — 2 cambios |
| 2 | Profesores + Bugs | 7 | Sí — 1 cambio |
| 3 | Materias + Alumnos | 8 | Sí — 1 cambio |
| 4 | Asistencia + Usuarios + Reportes + Configuración | 14 | Sí — 1 cambio |

Las tareas 8 y 9 de Persona 1 quedan bloqueadas hasta que exista el campo
de licencia de preceptor (parte de "Implementaciones", fuera de este
alcance) — dejarlas para el final de su tanda, no al principio.
