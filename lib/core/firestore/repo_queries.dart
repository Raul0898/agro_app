import 'package:cloud_firestore/cloud_firestore.dart';

class RepoQueries {
  static Query<Map<String, dynamic>> _base(
    CollectionReference<Map<String, dynamic>> collection, {
    required String unidadId,
    String? seccionId,
    DateTime? desde,
  }) {
    Query<Map<String, dynamic>> query =
        collection.where('unidad', isEqualTo: unidadId);

    if (seccionId != null) {
      query = query.where('seccion', isEqualTo: seccionId);
    }

    query = query.orderBy('fecha', descending: true);

    if (desde != null) {
      query = query.where('fecha', isGreaterThanOrEqualTo: desde);
    }

    return query;
  }

  static Query<Map<String, dynamic>> resultadosCompactacion({
    required String unidadId,
    String? seccionId,
    DateTime? desde,
  }) {
    final collection = FirebaseFirestore.instance
        .collection('resultados_analisis_compactacion')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    return _base(
      collection,
      unidadId: unidadId,
      seccionId: seccionId,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> reportesCompactacion({
    required String unidadId,
    String? seccionId,
    DateTime? desde,
  }) {
    final collection = FirebaseFirestore.instance
        .collection('reportes_compactacion')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    return _base(
      collection,
      unidadId: unidadId,
      seccionId: seccionId,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> resultadosNutrientes({
    required String unidadId,
    String? seccionId,
    DateTime? desde,
  }) {
    final collection = FirebaseFirestore.instance
        .collection('resultados_analisis_nutrientes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    return _base(
      collection,
      unidadId: unidadId,
      seccionId: seccionId,
      desde: desde,
    );
  }

  static Query<Map<String, dynamic>> reportesNutrientes({
    required String unidadId,
    String? seccionId,
    DateTime? desde,
  }) {
    final collection = FirebaseFirestore.instance
        .collection('reportes_nutrientes')
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) =>
              snapshot.data() ?? <String, dynamic>{},
          toFirestore: (value, _) => value,
        );

    return _base(
      collection,
      unidadId: unidadId,
      seccionId: seccionId,
      desde: desde,
    );
  }
}
