/// Grupo de taller (A, B, C...) — subdivisión interna de UN curso puntual,
/// NO algo compartido entre cursos (4to 1ra y 4to 2da tienen sus propios
/// grupos, aunque den las mismas materias de taller en horarios distintos).
/// Relación con el alumno: FK simple y nullable (`students.workshop_group_id`),
/// un alumno pertenece a lo sumo un grupo, dentro de su curso.
class WorkshopGroup {
  const WorkshopGroup({required this.id, required this.courseId, required this.name});

  final String id;
  final String courseId;
  final String name; // `group_label` en la DB ("A", "B"...)

  factory WorkshopGroup.fromJson(Map<String, dynamic> json) => WorkshopGroup(
        id: json['id'].toString(),
        courseId: json['course_id'].toString(),
        name: (json['group_label'] ?? json['name']).toString(),
      );
}
