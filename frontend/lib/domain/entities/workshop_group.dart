/// Grupo de taller (workshop group). Relación N:M con alumnos vía
/// `student_workshop_groups` en el backend.
class WorkshopGroup {
  const WorkshopGroup({required this.id, required this.name});

  final int id;
  final String name;

  factory WorkshopGroup.fromJson(Map<String, dynamic> json) => WorkshopGroup(
        id: json['id'] as int,
        name: json['name'].toString(),
      );
}
