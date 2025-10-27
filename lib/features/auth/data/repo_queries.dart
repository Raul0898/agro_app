import 'package:cloud_firestore/cloud_firestore.dart';

class RepoQueries {
  const RepoQueries._();

  static Query<Map<String, dynamic>> reportesCompactacion({
    required String unidadId,
    required String seccionId,
    DateTime? desde,
  }) {
    var query = FirebaseFirestore.instance
        .collection('reportes_compactacion')
        .where('unidad', isEqualTo: unidadId);

    if (seccionId.trim().isNotEmpty) {
      query = query.where('seccion', isEqualTo: seccionId);
    }

    if (desde != null) {
      query = query
          .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }

    return query;
  }

  static Query<Map<String, dynamic>> reportesNutrientes({
    required String unidadId,
    required String seccionId,
    DateTime? desde,
  }) {
    var query = FirebaseFirestore.instance
        .collection('reportes_nutrientes')
        .where('unidad', isEqualTo: unidadId);

    if (seccionId.trim().isNotEmpty) {
      query = query.where('seccion', isEqualTo: seccionId);
    }

    if (desde != null) {
      query = query
          .where('fechaHora', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }

    return query;
  }
}
