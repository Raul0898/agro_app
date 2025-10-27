import 'package:cloud_firestore/cloud_firestore.dart';

class RepoQueries {
  const RepoQueries._();

  static Query<Map<String, dynamic>> resultadosAnalisisCompactacion({
    required String unidad,
    String? seccion,
    DateTime? desde,
  }) {
    return _baseQuery(
      'resultados_analisis_compactacion',
      unidad: unidad,
      seccion: seccion,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> resultadosAnalisisNutrientes({
    required String unidad,
    String? seccion,
    DateTime? desde,
  }) {
    return _baseQuery(
      'resultados_analisis_nutrientes',
      unidad: unidad,
      seccion: seccion,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> reportesCompactacion({
    required String unidad,
    String? seccion,
    DateTime? desde,
  }) {
    return _baseQuery(
      'reportes_compactacion',
      unidad: unidad,
      seccion: seccion,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> reportesNutrientes({
    required String unidad,
    String? seccion,
    DateTime? desde,
  }) {
    return _baseQuery(
      'reportes_nutrientes',
      unidad: unidad,
      seccion: seccion,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> _baseQuery(
    String collection, {
    required String unidad,
    String? seccion,
    DateTime? desde,
  }) {
    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection(collection);

    if (desde != null) {
      query = query.where(
        'fecha',
        isGreaterThanOrEqualTo: Timestamp.fromDate(desde),
      );
    }

    query = query.where('unidad', isEqualTo: unidad);

    if (seccion != null && seccion.isNotEmpty) {
      query = query.where('seccion', isEqualTo: seccion);
    }

    return query.orderBy('fecha', descending: true);
  }
}
