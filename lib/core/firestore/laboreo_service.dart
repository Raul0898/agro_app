import 'package:cloud_firestore/cloud_firestore.dart';

class LaboreoService {
  LaboreoService([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  Future<String?> unidadActualDelUsuario(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    final data = snap.data();
    if (data == null) return null;

    final unidadSeleccionada = (data['unidadSeleccionada'] as String?)?.trim();
    if (unidadSeleccionada != null && unidadSeleccionada.isNotEmpty) {
      return unidadSeleccionada;
    }

    final unidad = (data['unidad'] as String?)?.trim();
    if (unidad != null && unidad.isNotEmpty) {
      return unidad;
    }

    return null;
  }

  Future<List<String>> seccionesDeUnidad(String unidadId) async {
    final snap = await _db.collection('unidades_catalog').doc(unidadId).get();
    final data = snap.data() ?? <String, dynamic>{};
    final raw = (data['secciones'] ?? data['num_secciones']);
    if (raw is List) {
      return raw
          .map((e) => _mapSeccionId(e))
          .whereType<String>()
          .toList();
    }
    if (raw is int) {
      return List<String>.generate(raw, (index) => '${index + 1}');
    }
    return <String>[];
  }

  String? _mapSeccionId(dynamic entry) {
    if (entry is String) {
      final trimmed = entry.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (entry is num) {
      if (entry.isNaN || entry.isInfinite) return null;
      final normalized = entry is int
          ? entry.toString()
          : (entry == entry.truncate()
              ? entry.truncate().toString()
              : entry.toString());
      final trimmed = normalized.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (entry is Map) {
      const preferredKeys = <String>['slug', 'valueSlug', 'id', 'uid', 'value'];
      for (final key in preferredKeys) {
        final value = entry[key];
        if (value is String && value.trim().isNotEmpty) {
          return value.trim();
        }
      }
      final nombre = entry['nombre'] ?? entry['name'] ?? entry['title'] ?? entry['label'];
      if (nombre is String && nombre.trim().isNotEmpty) {
        return _slugFromName(nombre);
      }
    }
    return null;
  }

  String _slugFromName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'seccion';

    if (RegExp(r'^\d+$').hasMatch(trimmed)) {
      return 'seccion_$trimmed';
    }

    String _stripDiacritics(String input) {
      const map = {
        'á': 'a',
        'à': 'a',
        'ä': 'a',
        'â': 'a',
        'ã': 'a',
        'å': 'a',
        'ç': 'c',
        'é': 'e',
        'è': 'e',
        'ë': 'e',
        'ê': 'e',
        'í': 'i',
        'ì': 'i',
        'ï': 'i',
        'î': 'i',
        'ñ': 'n',
        'ó': 'o',
        'ò': 'o',
        'ö': 'o',
        'ô': 'o',
        'õ': 'o',
        'ú': 'u',
        'ù': 'u',
        'ü': 'u',
        'û': 'u',
      };
      final buffer = StringBuffer();
      for (final rune in input.runes) {
        final char = String.fromCharCode(rune);
        buffer.write(map[char] ?? char);
      }
      return buffer.toString();
    }

    final normalized = _stripDiacritics(trimmed.toLowerCase());
    final sanitized = normalized
        .replaceAll(RegExp(r'[\s/]+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    if (sanitized.isEmpty) return 'seccion';
    if (sanitized.startsWith('seccion_')) return sanitized;
    if (sanitized.startsWith('seccion')) {
      final remainder = sanitized.substring('seccion'.length).replaceFirst(RegExp(r'^_'), '');
      return remainder.isEmpty ? 'seccion' : 'seccion_$remainder';
    }

    return 'seccion_$sanitized';
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
    return _db.collection('actividades_laboreo_profundo').add({
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
