import 'package:cloud_firestore/cloud_firestore.dart';

/// Helper queries for repository-style access to Firestore collections related to
/// analysis and reports.
class RepoQueries {
  RepoQueries._();

  /// Returns a query for compactación analysis results ordered by most recent
  /// date first and filtered by unidad/sección. Accepts an optional [desde]
  /// parameter to only include documents from that date forward and an optional
  /// [limit] for pagination.
  static Query<Map<String, dynamic>> resultadosCompactacion({
    required String unidadId,
    required String seccionId,
    DateTime? desde,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = FirebaseFirestore.instance
        .collection('resultados_analisis_compactacion')
        .where('unidad', isEqualTo: unidadId)
        .where('seccion', isEqualTo: seccionId);

    if (desde != null) {
      q = q.where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(desde));
    }

    q = q.orderBy('fecha', descending: true);

    if (limit != null) {
      q = q.limit(limit);
    }

    return q;
  }
}
