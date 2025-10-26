// lib/services/catalog_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/unidad_models.dart';

/// Documento de cultivo en Firestore.
class CultivoDoc {
  final String id;               // id del doc (p.ej. "maiz")
  final String title;            // visible (p.ej. "Maíz")
  final List<String> menus;      // claves estilo: "menu:xxx" | "submenu:xxx/Texto"

  CultivoDoc({
    required this.id,
    required this.title,
    required this.menus,
  });

  factory CultivoDoc.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? <String, dynamic>{};
    final rawMenus = data['menus'];
    return CultivoDoc(
      id: snap.id,
      title: (data['title'] as String? ?? '').trim(),
      menus: rawMenus is List ? rawMenus.cast<String>() : const <String>[],
    );
  }
}

class CatalogService {
  CatalogService._();
  static final CatalogService I = CatalogService._();

  final _db = FirebaseFirestore.instance;

  /// Stream en vivo de todos los cultivos (ordenados por id)
  Stream<List<CultivoDoc>> streamCultivos() {
    return _db
        .collection('cultivos_catalog')
        .orderBy(FieldPath.documentId)
        .snapshots()
        .map((qs) => qs.docs.map((d) => CultivoDoc.fromSnapshot(d)).toList());
  }

  /// Carga “una vez” los cultivos.
  Future<List<CultivoDoc>> fetchCultivos() async {
    final qs = await _db
        .collection('cultivos_catalog')
        .orderBy(FieldPath.documentId)
        .get();
    return qs.docs.map((d) => CultivoDoc.fromSnapshot(d)).toList();
  }

  /// Crea o actualiza un cultivo en `cultivos_catalog/{id}`.
  Future<void> createOrUpdateCultivo({
    required String id,
    required String title,
    required List<String> menus,
  }) async {
    await _db.collection('cultivos_catalog').doc(id).set({
      'title': title,
      'menus': menus,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(), // si ya existe, no pasa nada
    }, SetOptions(merge: true));
  }

  /// Guarda/actualiza la información de una unidad de siembra
  /// dentro del documento de `users/{uid}`.
  Future<void> createOrUpdateUnidad({
    String? uid,
    required UnidadSiembraInput input,
  }) async {
    final userId = uid ?? FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      throw StateError('No hay usuario autenticado.');
    }

    // Construye el merge para users/{uid}
    final Map<String, dynamic> unidadMap = input.toFirestore();

    await _db.collection('users').doc(userId).set({
      'unidadesAutorizadas': FieldValue.arrayUnion([input.id]),
      'cultivosPorUnidad': {
        input.id: input.cultivos,
      },
      'unidadesInfo': {
        input.id: unidadMap,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}