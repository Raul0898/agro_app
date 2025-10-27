import 'package:cloud_firestore/cloud_firestore.dart';

/// Utilidades centralizadas para construir consultas del repositorio
/// de reportes y análisis.
class RepoQueries {
  RepoQueries._();

  /// Consulta base para la colección `reportes_nutrientes` filtrada por
  /// unidad y sección. Permite aplicar un rango opcional por fecha.
  static Query<Map<String, dynamic>> reportesNutrientes(
    String unidad,
    String seccion, {
    Timestamp? desde,
    Timestamp? hasta,
  }) {
    final unidadTrim = unidad.trim();
    final seccionTrim = seccion.trim();

    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('reportes_nutrientes')
        .where('unidad', isEqualTo: unidadTrim);

    if (seccionTrim.isNotEmpty) {
      query = query.where('seccion', isEqualTo: seccionTrim);
    }
    if (desde != null) {
      query = query.where('fechaHora', isGreaterThanOrEqualTo: desde);
    }
    if (hasta != null) {
      query = query.where('fechaHora', isLessThanOrEqualTo: hasta);
    }

    return query;
  }
}
