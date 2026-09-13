1- ALUMNOS

-arreglar visual filtros (alto)
-cuando tocas el ojito de un alumno dice el curso, esta bien, pero tambien debe aclarar la especialidad
-se puede eliminar alumno? consultar con los monos

2- ASISTENCIA

-cuando cambias el curso del select la pantalla no carga carga un error y todo el fondo rojo, lo mismo cuando cambias la fecha 
-cuando el nombre de un alumno es muy largo se ve un error amarillo y negro del flutter

3- CURSOS
-hacer simetricos los espacios de izq y der de los cursos (estan mas a la izq que der ahora)
-en horario semanal agregar boton de editar y de deshabilitar
-que cuando agregues muchos horarios en horario semanal solo se ordene con este criterio de prioridad de arriba a abajo: orden semanal (lunes, martes, etc) y horario despues (mañana, tarde, vespertino)
-que el horario detallado ocupe el mismo espacio de ancho que el horario semanal
-en horario detallado cuando haces click en en una materia te muestre toda la info respecto a la misma (profe, horario, nombre), abajo boton de editar, eliminar, cancelar
-en horario detallado cuando haces click en un recreo que te muestre la info(turno, duracion, de que hora a que hora, nombre) pero que no deje eliminarlo ni editar, eso se haria desde la configuracion
-en materias y profesores cuando asignas una materia a ese curso despliega todos los profes, solo debe desplegar los profes asignados/habilitados a dar esa materia
-cuando agregas un preceptor reemplazante esta bien que pida el turno, pero cuando desplegas preceptor reemplazante no debe desplegar ni preceptores que no esten asignaodos a ese turno, ni preceptores que estan de licencia medica
-debe mostrar el estado del preceptor titular (en caso de que este de licencia medica/vacaciones dado de baja, etc)
-debe dejar agregar mas de un prece permanente por turno y a cada uno asignarle un dia, por ej si tengo dos precces permanentes a la mañana el prece 1 puede tener lunes y martes mientras que el dos el resto de los dias pero no pueden tener los dos el mismo dia, lo mismo para prece de la tarde, el de la mañana y de la tarde si pueden tener asignado el mismo dia ya que es otro turno

4- MATERIAS

-agregar filtro de taller/curricular, año, especialidad y una lupa
-cuando queres agregar una materia con el mismo nombre de una existente da un error raro, debe ser un error legible
-en tema oscruo el cartel de curricular no se lee
-agregar columna a la tabla que diga años asignados y muestre a todos los años que esa materia esta asignadad separanadolos por coma, por ej 1ro, 3ro, 5to (E) (la e/p/c seria para aclarar la especialidad)
-agregar una columna a la izq de cada materia con un numero identificante por ej matematica de 6to M6t si es de 1ro y 6to seria M1r6t o algo asi no se inventalo vos el patron de la identeificacion que sea entendible con el fin de acortar los nombres de las materias para mostrarlos en otra tabla luego

5- PROFES

-cambiar el titlo de la seccion a profesores
-cuando asignas un profe a una materia que simplemente pida el año no el curso tan especifico, en caso de ser de 4to año para arriba que tambien pida la especialidad, en base al año y especialidad (de ser requerida) que se pidan debe desplegar las materias asignadas para esos años
-agregar columna a la tabla que diga materias asignadas y muestre a todos las materias que ese profesor esta asignado, para no escribir todo el nombre de la materia y el curso simplemente optamos por mostrar con el identificante de materia que esta en la seccion de materias en la primera columna. de todas maneras al hacer click en esta columna de materias asignadas a cada profe abira una vista mas detallada de todas las materias con el nombre e info necesaria completa.
-agregar boton de eliminar, editar, dar de baja, licencia medica/vacaciones a cada profe
-agregar filtro por materia (con el identificante no nombre completo de la materia) y lupa
-arreglar visul dentro de gestionar materias de profe el texto que indica que una materia es curricular no se lee en modo oscuro

6- USUARIOS

-arreglar la visual de la tabla, horizontalmente se ve todo pegado
-agregar filtros segun rol, estado y una lupa

7- REPORTES

-en exportacion personalizada los select deben ser asimetricos verticalmente 
-en exportacion personalizada cambiar el texto de los botones de generar excel y pdf a exportar excel y pdf
-en exportacion personalizada tanto los select como los botones de exporar en excel y exportar en pdf deben estra centrados y ser simetricos verticalmente
-en exportacions personalizada agregar como filtro año y divison por separado, saca el filtro de curso
-de acuerdo a que año elegis que muestra el selct de divison y de acuerdo a eso que muetsra el select de turnos 

8- CONFIGURACION

-acomoadar horizontalmente todas las tarjetas de general y cursos, que ocupen el maximo espacio posible
-todos los botones que sean de guardar cambios que esten del lado derecho en vez del izquierdo
-en dispositivos acomodar la info de las tablas ya que se ve amontonada horizontalmente
-en general en almuerzo separar en dos filas el inicio y fin de almuerzo con y sin quinto modulo, teniendo cada uno su inicio y fin individual  

9- IMPLEMENTACIONES

-agregar panel de preceptores
-en preceptores al preceptor que este a cargo debe dejar marcar como de licencia medica/vacaciones, con un campo de motivo de texto libre y cuanto tiempo se toma de licencia medica(maximo 1 mes, en caso de necesitarse mas se tendra que renovar la licencia medica)
    
10-BUGS

-el saludo del panel de admin no es dinamico