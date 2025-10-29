import 'package:cloud_firestore/cloud_firestore.dart';

class LaboreoService {
  LaboreoService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String?> unidadActualDelUsuario(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['unidad'] as String?;
  }

  Future<List<String>> seccionesDeUnidad(String unidadId) async {
    final snap = await _db.collection('unidades_catalog').doc(unidadId).get();
    final data = snap.data() ?? <String, dynamic>{};
    final raw = (data['secciones'] ?? data['num_secciones']);
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is int) {
      return List<String>.generate(raw, (index) => '${index + 1}');
    }
    return <String>[];
  }

  Future<QueryDocumentSnapshot<Map<String, dynamic>>?> ultimoCompactacionPorSeccion({
    required String unidadId,
    required String seccionId,
  }) async {
    final collection = _db.collection('resultados_analisis_compactacion');

    Future<QueryDocumentSnapshot<Map<String, dynamic>>?> _query(dynamic seccionValue) async {
      final query = await collection
          .where('unidad', isEqualTo: unidadId)
          .where('seccion', isEqualTo: seccionValue)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();
      if (query.docs.isEmpty) return null;
      return query.docs.first;
    }

    final byString = await _query(seccionId);
    if (byString != null) return byString;
    final numeric = int.tryParse(seccionId);
    if (numeric != null) {
      final byNumber = await _query(numeric);
      if (byNumber != null) return byNumber;
    }
    return null;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> decisionProfundoDoc({
    required String uid,
    required String unidadId,
  }) async {
    final query = await _db
        .collection('actividades_laboreo_profundo')
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidadId)
        .orderBy('updatedAt', descending: true)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  Future<DocumentReference<Map<String, dynamic>>> guardarDecisionProfundo({
    required String uid,
    required String unidadId,
    required String decision, // "realizar" | "no_realizar"
    required String fuente, // "amarillo_usuario" | "rojo_auto"
  }) async {
    final collection = _db.collection('actividades_laboreo_profundo');

    final existing = await collection
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidadId)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      final ref = existing.docs.first.reference;
      await ref.update({
        'decision': decision,
        'fuente': fuente,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return ref;
    }

    return collection.add({
      'uid': uid,
      'unidad': unidadId,
      'decision': decision,
      'fuente': fuente,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'ultimoReporteAt': null,
    });
  }

  Future<void> setUltimoReporteProfundo(String docId) async {
    await _db.collection('actividades_laboreo_profundo').doc(docId).update({
      'ultimoReporteAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<DocumentReference<Map<String, dynamic>>> crearSuperficial({
    required String uid,
    required String unidadId,
    required List<String> actividades, // ["rastra"], ["desterronador"] o ambas
  }) async {
    return _db.collection('actividades_laboreo_superficial').add({
      'uid': uid,
      'unidad': unidadId,
      'actividades': actividades,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'reporteEmitidoAt': null,
    });
  }

  Future<void> setReporteSuperficial(String docId) async {
    await _db.collection('actividades_laboreo_superficial').doc(docId).update({
      'reporteEmitidoAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> actividadesSuperficiales({
    required String uid,
    required String unidadId,
  }) async {
    final query = await _db
        .collection('actividades_laboreo_superficial')
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidadId)
        .orderBy('createdAt', descending: true)
        .get();
    return query.docs;
  }
}
