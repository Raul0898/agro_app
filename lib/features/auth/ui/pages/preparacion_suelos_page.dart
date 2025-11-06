import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart' as fb_storage;
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'reporte_actividad_laboreo_profundo.dart';
import 'reporte_actividad_laboreo_superficial.dart';
import 'selector_contexto_page.dart';

class PreparacionSuelosPage extends StatefulWidget {
  const PreparacionSuelosPage({super.key});

  @override
  State<PreparacionSuelosPage> createState() => _PreparacionSuelosPageState();
}

enum _EstadoColor { verde, amarillo, rojo, desconocido }

class _SeccionInfo {
  const _SeccionInfo({required this.id});

  final String id;
}

typedef _AnalisisSeccion = ({
  String? nombreArchivo,
  String? storagePath,
  DateTime? fecha,
  String? recomendacion,
  _EstadoColor estado,
});

class _DecisionSeccionState {
  const _DecisionSeccionState({
    required this.docId,
    required this.seccionId,
    required this.decision,
    this.fuente,
    this.createdAt,
    this.updatedAt,
    this.reporteEmitidoAt,
    this.expiresAt,
  });

  final String docId;
  final String seccionId;
  final String? decision;
  final String? fuente;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reporteEmitidoAt;
  final DateTime? expiresAt;

  bool get reporteVigente => _isWithinSixMonths(reporteEmitidoAt);
  bool get vigente =>
      expiresAt == null || expiresAt!.isAfter(DateTime.now());

  factory _DecisionSeccionState.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? <String, dynamic>{};
    final seccionRaw = data['seccion'] ?? data['seccionId'] ?? data['seccion_id'];
    final seccionId = _normalizarSeccionIdStatic(seccionRaw) ?? '';
    return _DecisionSeccionState(
      docId: snap.id,
      seccionId: seccionId,
      decision: (data['decision'] as String?)?.trim(),
      fuente: (data['fuente'] as String?)?.trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reporteEmitidoAt: (data['reporteEmitidoAt'] as Timestamp?)?.toDate(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  static String? _normalizarSeccionIdStatic(dynamic entry) {
    if (entry is String) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) return null;
      final match = RegExp(r'(\d+)').firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
      return trimmed;
    }
    if (entry is num) {
      final normalized = entry.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (entry is DocumentReference) {
      return entry.id.trim();
    }
    return null;
  }
}

class _ActividadSuperficialRegistro {
  const _ActividadSuperficialRegistro({
    required this.docId,
    required this.seleccion,
    this.createdAt,
    this.updatedAt,
    this.reporteEmitidoAt,
    this.done = false,
  });

  final String docId;
  final String seleccion;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reporteEmitidoAt;
  final bool done;

  bool get reporteVigente => done && _isWithinSixMonths(reporteEmitidoAt);

  factory _ActividadSuperficialRegistro.fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    return _ActividadSuperficialRegistro(
      docId: snap.id,
      seleccion: (data['seleccion'] as String? ?? 'rastra').toLowerCase(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reporteEmitidoAt: (data['reporteEmitidoAt'] as Timestamp?)?.toDate(),
      done: data['done'] == true,
    );
  }

  factory _ActividadSuperficialRegistro.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? <String, dynamic>{};
    return _ActividadSuperficialRegistro(
      docId: snap.id,
      seleccion: (data['seleccion'] as String? ?? 'rastra').toLowerCase(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reporteEmitidoAt: (data['reporteEmitidoAt'] as Timestamp?)?.toDate(),
      done: data['done'] == true,
    );
  }
}

bool _isWithinSixMonths(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return now.difference(date).inDays <= 180;
}

String _fmt(DateTime? value) {
  if (value == null) {
    return 'Sin fecha disponible';
  }
  return DateFormat('dd MMM yyyy, HH:mm', 'es_MX').format(value);
}

class _PreparacionSuelosPageState extends State<PreparacionSuelosPage> {
  bool _loading = true;
  String? _error;
  String? _uid;
  String? _unidadId;

  List<_SeccionInfo> _secciones = const [];
  final Map<String, _ArchivoStorageInfo?> _archivosPorSeccion = {};
  final Map<String, _RecomendacionInfo?> _recomendacionesPorSeccion = {};
  final Map<
      String,
      ({
        String nombre,
        String? storagePath,
        DateTime? fecha,
        String barraTexto,
        _EstadoColor barraColor,
      })> _datosPorSeccion = {};
  final Map<String, _DecisionSeccionState> _decisionPorSeccion = {};
  bool _hayRojo = false;
  bool _hayAmarillo = false;
  final Set<String> _guardandoDecisionSecciones = <String>{};
  final Set<String> _eliminandoDecisionSecciones = <String>{};

  List<_ActividadSuperficialRegistro> _superficiales = const [];
  bool _agregandoSuperficial = false;
  String _seleccionSuperficial = 'rastra';
  final Set<String> _superficialesNuevos = <String>{};
  String? _eliminandoSuperficialId;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_MX', null)
        .catchError((_) {})
        .whenComplete(() {
      if (mounted) {
        _cargarTodo();
      }
    });
  }

  Future<void> _cargarTodo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      setState(() {
        _loading = false;
        _error = 'Debes iniciar sesión para ver esta información.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final unidad = await _resolverUnidad(uid);
      final secciones = await _resolverSecciones(unidad);
      final datosPorSeccion = <String, _AnalisisSeccion?>{};
      bool hayRojo = false;
      bool hayAmarillo = false;
      final datosPorSeccion = <
          String,
          ({
            String nombre,
            String? storagePath,
            DateTime? fecha,
            String barraTexto,
            _EstadoColor barraColor,
          })>{};
      for (final seccion in secciones) {
        final archivo = await _ultimoArchivoStorage(unidad, seccion);
        archivos[seccion.id] = archivo;
        final recomendacion = await _recomendacion(unidad, seccion);
        recomendaciones[seccion.id] = recomendacion;
        final barraColor = recomendacion?.color ?? _EstadoColor.desconocido;
        final barraTexto =
            recomendacion?.texto ?? 'Sin recomendación disponible';
        String nombreArchivo = archivo?.nombre ?? 'Sin archivo reciente';
        DateTime? fechaArchivo = archivo?.fecha ?? recomendacion?.fecha;
        String? storagePath = archivo?.metadata.fullPath;
        storagePath = storagePath?.trim();

        Map<String, dynamic>? archivoDesdeDoc;
        final dataDoc = recomendacion?.doc?.data();
        if (dataDoc != null) {
          final rawArchivo = dataDoc['archivo'];
          if (rawArchivo is Map<String, dynamic>) {
            archivoDesdeDoc = rawArchivo;
          } else if (rawArchivo is Map) {
            archivoDesdeDoc = rawArchivo.map(
              (key, value) => MapEntry(key.toString(), value),
            );
          }
        }

        if (archivoDesdeDoc != null) {
          final pathDoc = _stringFromDynamic(archivoDesdeDoc['path']) ??
              _stringFromDynamic(archivoDesdeDoc['storagePath']) ??
              _stringFromDynamic(archivoDesdeDoc['storage_path']) ??
              _stringFromDynamic(archivoDesdeDoc['ruta']);
          final nombreDoc = _stringFromDynamic(archivoDesdeDoc['nombre']) ??
              _stringFromDynamic(archivoDesdeDoc['fileName']) ??
              _stringFromDynamic(archivoDesdeDoc['titulo']);
          final fechaDoc = _fechaDesdeDynamic(archivoDesdeDoc['fecha']) ??
              _fechaDesdeDynamic(archivoDesdeDoc['uploadedAt']) ??
              _fechaDesdeDynamic(archivoDesdeDoc['actualizado']);

          if ((storagePath ?? '').isEmpty) {
            if (pathDoc != null && pathDoc.isNotEmpty) {
              final trimmedPath = pathDoc.trim();
              if (trimmedPath.isNotEmpty) {
                storagePath = trimmedPath;
                if (nombreDoc != null && nombreDoc.isNotEmpty) {
                  nombreArchivo = nombreDoc;
                }
                if (fechaDoc != null) {
                  fechaArchivo = fechaDoc;
                }
              }
            }
          }
        }

        datosPorSeccion[seccion.id] = (
          nombre: nombreArchivo,
          storagePath: storagePath,
          fecha: fechaArchivo,
          barraTexto: barraTexto,
          barraColor: barraColor,
        );
        if (recomendacion != null) {
          if (recomendacion.color == _EstadoColor.rojo) {
            hayRojo = true;
          } else if (recomendacion.color == _EstadoColor.amarillo) {
            hayAmarillo = true;
          }
        }
      }
      final decisiones = await _cargarDecisiones(uid, unidad);
      final superficiales = await _cargarActividades(uid, unidad);

      if (!mounted) return;
      setState(() {
        _uid = uid;
        _unidadId = unidad;
        _secciones = secciones;
        _datosPorSeccion
          ..clear()
          ..addAll(recomendaciones);
        _datosPorSeccion
          ..clear()
          ..addAll(datosPorSeccion);
        _decisionPorSeccion
          ..clear()
          ..addAll(decisiones);
        _hayRojo = hayRojo;
        _hayAmarillo = !hayRojo && hayAmarillo;
        _superficiales = superficiales;
        _superficialesNuevos.removeWhere(
          (id) => superficiales.every((registro) => registro.docId != id),
        );
        if (_eliminandoSuperficialId != null &&
            superficiales.every((registro) => registro.docId != _eliminandoSuperficialId)) {
          _eliminandoSuperficialId = null;
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<String> _resolverUnidad(String uid) async {
    final desdeContexto = _unidadDesdeContexto();
    if (desdeContexto != null) {
      return desdeContexto;
    }

    final desdePerfil = await _unidadDesdePerfil(uid);
    if (desdePerfil != null) {
      return desdePerfil;
    }

    final desdeCatalogo = await _unidadDesdeCatalogo(uid);
    if (desdeCatalogo != null) {
      return desdeCatalogo;
    }

    throw Exception('No se encontró una unidad asignada al perfil.');
  }

  String? _unidadDesdeContexto() {
    try {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final candidates = <String?>[
          _stringFromDynamic(args['unidadSeleccionada']),
          _stringFromDynamic(args['unidad_seleccionada']),
          _stringFromDynamic(args['unidad']),
          _stringFromDynamic(args['unidadId']),
          _stringFromDynamic(args['unidad_id']),
        ];
        return _firstNonEmpty(candidates);
      }
    } catch (_) {
      // Ignorar: no hay argumentos o no se pueden leer en este contexto.
    }
    return null;
  }

  Future<String?> _unidadDesdePerfil(String uid) async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = userDoc.data() ?? <String, dynamic>{};

    Map<dynamic, dynamic>? contexto;
    final rawContexto = data['contexto'];
    if (rawContexto is Map) {
      contexto = rawContexto;
    }

    String? contextoUnidad;
    if (contexto != null) {
      contextoUnidad = _firstNonEmpty([
        _stringFromDynamic(contexto['unidad']),
        _stringFromDynamic(contexto['unidadId']),
        _stringFromDynamic(contexto['unidad_id']),
        _stringFromDynamic(contexto['unidadSeleccionada']),
        _stringFromDynamic(contexto['unidad_seleccionada']),
      ]);
    }

    String? primeraUnidadLista;
    final rawUnidades = data['unidades'];
    if (rawUnidades is List) {
      for (final item in rawUnidades) {
        final valor = _stringFromDynamic(item);
        if (valor != null && valor.isNotEmpty) {
          primeraUnidadLista = valor;
          break;
        }
      }
    }

    final candidatos = <String?>[
      _stringFromDynamic(data['unidadSeleccionada']),
      _stringFromDynamic(data['unidad_seleccionada']),
      _stringFromDynamic(data['unidadActual']),
      _stringFromDynamic(data['unidad_actual']),
      _stringFromDynamic(data['unidadIdActual']),
      _stringFromDynamic(data['unidadId']),
      _stringFromDynamic(data['unidad_id']),
      _stringFromDynamic(data['unidad']),
      contextoUnidad,
      primeraUnidadLista,
    ];

    return _firstNonEmpty(candidatos);
  }

  Future<String?> _unidadDesdeCatalogo(String uid) async {
    final query = await FirebaseFirestore.instance
        .collection('unidades_catalog')
        .where('miembros', arrayContains: uid)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final id = query.docs.first.id.trim();
    return id.isEmpty ? null : id;
  }

  String? _firstNonEmpty(Iterable<String?> values) {
    for (final value in values) {
      final trimmed = value?.trim();
      if (trimmed != null && trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return null;
  }

  String? _stringFromDynamic(dynamic value) {
    if (value is String) {
      return value.trim();
    }
    if (value is DocumentReference) {
      return value.id.trim();
    }
    if (value is num) {
      final normalized = value.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }
    return null;
  }

  Future<List<_SeccionInfo>> _resolverSecciones(String unidad) async {
    final doc = await FirebaseFirestore.instance
        .collection('unidades_catalog')
        .doc(unidad)
        .get();
    final data = doc.data() ?? <String, dynamic>{};

    final seccionesDesdeLista = _mapearSeccionesDesdeLista(data['secciones']);
    if (seccionesDesdeLista.isNotEmpty) {
      return _ordenarSecciones(seccionesDesdeLista);
    }

    final count = _intFromDynamic(data['seccionesCount']) ??
        _intFromDynamic(data['num_secciones']) ??
        _intFromDynamic(data['numSecciones']);
    if (count != null && count > 0) {
      return _ordenarSecciones(List<_SeccionInfo>.generate(
        count,
        (index) => _SeccionInfo(
          id: '${index + 1}',
        ),
      ));
    }

    return _ordenarSecciones(const <_SeccionInfo>[
      _SeccionInfo(id: '1'),
    ]);
  }

  List<_SeccionInfo> _mapearSeccionesDesdeLista(dynamic raw) {
    if (raw is! List) return const <_SeccionInfo>[];
    final resultado = <_SeccionInfo>[];
    final vistos = <String>{};
    for (final entry in raw) {
      final id = _normalizarSeccionId(entry);
      if (id == null || id.isEmpty) continue;
      if (vistos.add(id)) {
        resultado.add(_SeccionInfo(id: id));
      }
    }
    return resultado;
  }

  List<_SeccionInfo> _ordenarSecciones(List<_SeccionInfo> secciones) {
    final lista = List<_SeccionInfo>.from(secciones);
    lista.sort((a, b) {
      final ai = int.tryParse(a.id);
      final bi = int.tryParse(b.id);
      if (ai != null && bi != null) {
        return ai.compareTo(bi);
      }
      if (ai != null) return -1;
      if (bi != null) return 1;
      return a.id.compareTo(b.id);
    });
    return lista;
  }

  String _labelSeccion(_SeccionInfo seccion) => 'Sección ${seccion.id}';

  String? _idStorage(_SeccionInfo seccion) {
    final id = seccion.id.trim();
    if (id.isEmpty) return null;
    return _sanitizeStorageSegment(id);
  }

  String _sanitizeStorageSegment(String input) {
    final s = input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\\/]+'), '-')
        .replaceAll(RegExp(r'[^a-z0-9_\-\s]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_');
    return s.isEmpty ? 'na' : s;
  }

  String? _normalizarSeccionId(dynamic entry) {
    if (entry is String) {
      final trimmed = entry.trim();
      if (trimmed.isEmpty) return null;
      final match = RegExp(r'(\d+)').firstMatch(trimmed);
      if (match != null) {
        return match.group(1);
      }
      return trimmed;
    }
    if (entry is num) {
      final normalized = entry.toString().trim();
      return normalized.isEmpty ? null : normalized;
    }
    if (entry is Map) {
      const preferredKeys = <String>[
        'id',
        'uid',
        'valueSlug',
        'value',
        'slug',
        'numero',
        'numeroSeccion',
        'numero_seccion',
        'seccion',
        'section',
      ];
      for (final key in preferredKeys) {
        if (!entry.containsKey(key)) continue;
        final maybe = _stringFromDynamic(entry[key]) ??
            (entry[key] is num ? entry[key].toString() : null);
        final normalized = _normalizarSeccionId(maybe);
        if (normalized != null && normalized.isNotEmpty) {
          return normalized;
        }
      }
      final nombre = entry['nombre'] ?? entry['name'] ?? entry['title'] ?? entry['label'];
      final normalizedNombre = _normalizarSeccionId(nombre);
      if (normalizedNombre != null && normalizedNombre.isNotEmpty) {
        return normalizedNombre;
      }
    }
    return null;
  }

  int? _intFromDynamic(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  Future<_AnalisisSeccion?> _ultimoAnalisisPorSeccion(
    String unidad,
    _SeccionInfo seccion,
  ) async {
    Future<QuerySnapshot<Map<String, dynamic>>> ejecutar(dynamic seccionValor) async {
      Query<Map<String, dynamic>> query = FirebaseFirestore.instance
          .collection('resultados_analisis_compactacion')
          .where('unidad', isEqualTo: unidad)
          .where('seccion', isEqualTo: seccionValor)
          .orderBy('fecha', descending: true)
          .orderBy('updatedAt', descending: true)
          .limit(1);

      try {
        return await query.get();
      } on FirebaseException catch (e) {
        if (e.code == 'failed-precondition') {
          try {
            return await FirebaseFirestore.instance
                .collection('resultados_analisis_compactacion')
                .where('unidad', isEqualTo: unidad)
                .where('seccion', isEqualTo: seccionValor)
                .orderBy('updatedAt', descending: true)
                .limit(1)
                .get();
          } on FirebaseException catch (inner) {
            if (inner.code == 'failed-precondition') {
              return FirebaseFirestore.instance
                  .collection('resultados_analisis_compactacion')
                  .where('unidad', isEqualTo: unidad)
                  .where('seccion', isEqualTo: seccionValor)
                  .limit(1)
                  .get();
            }
            rethrow;
          }
        }
        rethrow;
      }
    }

    QuerySnapshot<Map<String, dynamic>> snap = await ejecutar(seccion.id);
    if (snap.docs.isEmpty) {
      final asInt = int.tryParse(seccion.id);
      if (asInt != null) {
        snap = await ejecutar(asInt);
      }
    }

    if (snap.docs.isEmpty) {
      return null;
    }

    final data = snap.docs.first.data();
    final fecha = _extraerFecha(data);
    final rawRecomendacion = data['recomendacion'];
    String? colorRaw;
    String? textoRaw;
    if (rawRecomendacion is Map<String, dynamic>) {
      colorRaw = (rawRecomendacion['color'] as String?)?.toLowerCase().trim();
      textoRaw = (rawRecomendacion['texto'] as String?)?.trim();
    } else if (rawRecomendacion is String) {
      textoRaw = rawRecomendacion.trim();
    }

    colorRaw ??= (data['color'] as String?)?.toLowerCase().trim();
    colorRaw ??= (data['caso'] as String?)?.toLowerCase().trim();

    textoRaw ??= (data['recomendacionTexto'] as String?)?.trim();
    textoRaw ??= (data['recomendaciones'] as String?)?.trim();
    final texto =
        (textoRaw == null || textoRaw.isEmpty)
            ? 'Sin recomendación disponible'
            : textoRaw;

    final nombreRaw = (data['nombre'] as String?)?.trim();
    final nombreAlterno = (data['fileName'] as String?)?.trim();
    final nombreArchivo =
        (nombreRaw != null && nombreRaw.isNotEmpty)
            ? nombreRaw
            : (nombreAlterno != null && nombreAlterno.isNotEmpty
                ? nombreAlterno
                : null);

    final storagePathRaw = (data['storagePath'] as String?)?.trim();
    final downloadUrl = (data['downloadUrl'] as String?)?.trim();
    final storagePath =
        (storagePathRaw != null && storagePathRaw.isNotEmpty)
            ? storagePathRaw
            : (downloadUrl != null && downloadUrl.isNotEmpty ? downloadUrl : null);

    return (
      nombreArchivo: nombreArchivo,
      storagePath: storagePath,
      fecha: fecha,
      recomendacion: texto,
      estado: _estadoDesdeColor(colorRaw),
    );
  }

  Future<String?> _urlDeStoragePath(String? path) async {
    final trimmed = path?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    if (trimmed.startsWith('http')) {
      return trimmed;
    }
    try {
      final ref = fb_storage.FirebaseStorage.instance.ref().child(trimmed);
      return await ref.getDownloadURL();
    } on fb_storage.FirebaseException {
      return null;
    }
  }

  Future<Map<String, _DecisionSeccionState>> _cargarDecisiones(
    String uid,
    String unidad,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('decisiones_laboreo_profundo')
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidad)
        .get();
    final Map<String, _DecisionSeccionState> resultado = {};
    for (final doc in snap.docs) {
      final estado = _DecisionSeccionState.fromSnapshot(doc);
      if (estado.seccionId.isEmpty) continue;
      if (!estado.vigente) continue;
      final existente = resultado[estado.seccionId];
      if (existente == null) {
        resultado[estado.seccionId] = estado;
        continue;
      }
      final fechaExistente = existente.updatedAt ?? existente.createdAt;
      final fechaNueva = estado.updatedAt ?? estado.createdAt;
      if (fechaNueva != null &&
          (fechaExistente == null || fechaNueva.isAfter(fechaExistente))) {
        resultado[estado.seccionId] = estado;
      }
    }
    return resultado;
  }

  Future<List<_ActividadSuperficialRegistro>> _cargarActividades(
    String uid,
    String unidad,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('actividades_laboreo_superficial')
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidad)
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs
        .map(_ActividadSuperficialRegistro.fromSnapshot)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      final esUnidad = _error!.toLowerCase().contains('unidad');
      final mensaje = 'Error al cargar los datos:\n${_error!}';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (esUnidad) ...[
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SelectorContextoPage(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Seleccionar unidad'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargarTodo,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLaboreoProfundo(context),
            const SizedBox(height: 24),
            Divider(color: Colors.black.withOpacity(0.08)),
            const SizedBox(height: 24),
            _buildLaboreoSuperficial(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLaboreoProfundo(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Laboreo Profundo', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        if (_secciones.isEmpty)
          _placeholderCard('No hay secciones registradas para la unidad.'),
        for (final seccion in _secciones) _buildCardSeccion(seccion),
        if (_hayRojo) ...[
          const SizedBox(height: 16),
          Text(
            'Se detectaron secciones en rojo. Revisa el manual y registra la actividad necesaria.',
            style: theme.textTheme.bodyMedium,
          ),
        ] else if (_hayAmarillo) ...[
          const SizedBox(height: 16),
          Text(
            'Algunas secciones requieren decisión. Selecciona una opción para continuar.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
 
  Widget _buildCardSeccion(_SeccionInfo seccion) {
    final theme = Theme.of(context);
    final datos = _datosPorSeccion[seccion.id];
    final estado = _colorBarra(seccion.id);
    final texto = datos?.barraTexto ?? 'Sin recomendación disponible';
    final fechaBase = datos?.fecha;
    final fechaTexto = fechaBase == null
        ? 'Sin fecha disponible'
        : DateFormat('dd/MM/yyyy', 'es_MX').format(fechaBase);
    final nombreArchivo = datos?.nombre ?? 'Sin archivo reciente';
    final storagePath = datos?.storagePath;
    final sinArchivoReciente = storagePath?.isEmpty ?? true;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_labelSeccion(seccion), style: theme.textTheme.titleMedium),
                const Spacer(),
                Icon(Icons.segment, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text('Fecha: $fechaTexto', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              nombreArchivo,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (sinArchivoReciente) ...[
              const SizedBox(height: 4),
              Text(
                'Sin archivo reciente. Revisa la recomendación para más detalles.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            _barraRecomendacion(estado, texto),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: sinArchivoReciente
                    ? null
                    : () async {
                        final url = await _urlDeStoragePath(storagePath!);
                        if (!mounted) return;
                        if (url == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'No se pudo obtener el archivo para mostrar.',
                              ),
                            ),
                          );
                          return;
                        }
                        await _abrirUrl(url);
                      },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa'),
              ),
            ),
            if (estado == _EstadoColor.rojo) ...[
              const SizedBox(height: 12),
              _manualPlaceholder(),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _reporteProfundoButton(
                  seccion: seccion,
                  fuente: 'rojo',
                ),
              ),
            ] else if (estado == _EstadoColor.amarillo) ...[
              const SizedBox(height: 12),
              _decisionWidgetSeccion(seccion),
            ],
          ],
        ),
      ),
    );
  }

  Widget _decisionWidgetSeccion(_SeccionInfo seccion) {
    final guardando = _guardandoDecisionSecciones.contains(seccion.id);
    final eliminando = _eliminandoDecisionSecciones.contains(seccion.id);
    final decisionState = _decisionPorSeccion[seccion.id];
    final decision = decisionState?.decision?.trim();

    if (guardando || eliminando) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (decision == null || decision.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selecciona la acción a realizar y se guardará para futuras sesiones.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: null,
            items: const [
              DropdownMenuItem(
                value: 'realizar',
                child: Text('Realizar Laboreo Profundo'),
              ),
              DropdownMenuItem(
                value: 'no_realizar',
                child: Text('No realizar Laboreo Profundo'),
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Decisión',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              if (value != null) {
                _guardarDecisionSeccion(seccion, value, fuente: 'amarillo');
              }
            },
          ),
        ],
      );
    }

    if (decision == 'no_realizar') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Actividad registrada',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _eliminarDecisionSeccion(seccion),
              child: const Text('Tomar otra decisión'),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _manualPlaceholder(),
        const SizedBox(height: 12),
        _reporteProfundoButton(seccion: seccion, fuente: 'amarillo'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => _eliminarDecisionSeccion(seccion),
            child: const Text('Tomar otra decisión'),
          ),
        ),
      ],
    );
  }

  Widget _reporteProfundoButton({
    required _SeccionInfo seccion,
    required String fuente,
  }) {
    final decision = _decisionPorSeccion[seccion.id];
    final bool mostrarPalomita = decision?.reporteVigente ?? false;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => _abrirReporteProfundo(seccion, fuente),
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Reporte de Actividad'),
        ),
        if (mostrarPalomita) ...[
          const SizedBox(width: 8),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ],
    );
  }

  Widget _buildLaboreoSuperficial(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Laboreo Superficial', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Text(
          'Selecciona el tipo de laboreo superficial a registrar:',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _seleccionSuperficial,
          items: const [
            DropdownMenuItem(value: 'rastra', child: Text('Rastreo')),
            DropdownMenuItem(value: 'desterronador', child: Text('Desterronador')),
            DropdownMenuItem(
              value: 'ambos',
              child: Text('Rastreo y Desterronador'),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() => _seleccionSuperficial = value);
            }
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Actividad',
          ),
        ),
        const SizedBox(height: 12),
        ..._manualesPlaceholder(_seleccionSuperficial),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () async {
            final resultado = await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => ReporteActividadLaboreoSuperficialPage(
                  seleccion: _seleccionSuperficial,
                ),
              ),
            );
            if (resultado == true && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recuerda registrar la actividad desde un bloque guardado.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Reporte de Actividad'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _agregandoSuperficial ? null : _agregarBloqueSuperficial,
          icon: _agregandoSuperficial
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.add_circle_outline),
          label: Text(
            _agregandoSuperficial
                ? 'Agregando…'
                : 'Agregar Laboreo Superficial',
          ),
        ),
        const SizedBox(height: 20),
        if (_superficiales.isEmpty)
          _placeholderCard(
              'Aún no se han registrado actividades de laboreo superficial.'),
        for (final registro in _superficiales)
          _superficialCard(context, registro),
      ],
    );
  }

  Widget _superficialCard(
    BuildContext context,
    _ActividadSuperficialRegistro registro,
  ) {
    final theme = Theme.of(context);
    final fecha = registro.createdAt;
    final fechaTexto = fecha == null
        ? 'Fecha no disponible'
        : DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(fecha);
    final seleccionTexto = _nombreSeleccion(registro.seleccion);
    final esNuevo = _superficialesNuevos.contains(registro.docId);
    final eliminando = _eliminandoSuperficialId == registro.docId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Actividad registrada', style: theme.textTheme.titleMedium),
                const Spacer(),
                if (registro.reporteVigente)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),
            const SizedBox(height: 8),
            Text('Tipo: $seleccionTexto', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text('Registrado: $fechaTexto', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: () => _abrirReporteSuperficial(registro),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Reporte de Actividad'),
                ),
                if (registro.reporteVigente)
                  const Icon(Icons.check_circle, color: Colors.green),
                if (esNuevo)
                  OutlinedButton.icon(
                    onPressed: eliminando
                        ? null
                        : () => _eliminarSuperficialNuevo(registro),
                    icon: eliminando
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: Text(
                      eliminando
                          ? 'Eliminando…'
                          : '🗑 Eliminar Laboreo Superficial',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarDecisionSeccion(
    _SeccionInfo seccion,
    String decision, {
    required String fuente,
  }) async {
    if (_uid == null || _unidadId == null) return;
    final seccionId = seccion.id;
    setState(() {
      _guardandoDecisionSecciones.add(seccionId);
    });
    try {
      final ref = FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo');
      final existente = _decisionPorSeccion[seccionId];
      final docRef =
          existente != null ? ref.doc(existente.docId) : ref.doc();
      final data = <String, dynamic>{
        'uid': _uid!,
        'unidad': _unidadId!,
        'seccion': seccionId,
        'decision': decision,
        'fuente': fuente,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 180)),
        ),
      };
      if (existente == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
      final snap = await docRef.get();
      final nuevo = _DecisionSeccionState.fromSnapshot(snap);
      if (!mounted) return;
      setState(() {
        _decisionPorSeccion[seccionId] = nuevo;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la decisión: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _guardandoDecisionSecciones.remove(seccionId);
      });
    }
  }

  Future<void> _registrarReporteProfundo(
    _SeccionInfo seccion,
    String fuente,
  ) async {
    if (_uid == null || _unidadId == null) return;
    final seccionId = seccion.id;
    setState(() {
      _guardandoDecisionSecciones.add(seccionId);
    });
    try {
      final ref = FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo');
      final existente = _decisionPorSeccion[seccionId];
      final docRef =
          existente != null ? ref.doc(existente.docId) : ref.doc();
      final data = <String, dynamic>{
        'uid': _uid!,
        'unidad': _unidadId!,
        'seccion': seccionId,
        'decision': 'realizar',
        'fuente': fuente,
        'reporteEmitidoAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 180)),
        ),
      };
      if (existente == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
      final snap = await docRef.get();
      final nuevo = _DecisionSeccionState.fromSnapshot(snap);
      if (!mounted) return;
      setState(() {
        _decisionPorSeccion[seccionId] = nuevo;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la actividad: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _guardandoDecisionSecciones.remove(seccionId);
      });
    }
  }

  Future<void> _eliminarDecisionSeccion(_SeccionInfo seccion) async {
    final existente = _decisionPorSeccion[seccion.id];
    if (existente == null) return;
    setState(() {
      _eliminandoDecisionSecciones.add(seccion.id);
    });
    try {
      await FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo')
          .doc(existente.docId)
          .delete();
      if (!mounted) return;
      setState(() {
        _decisionPorSeccion.remove(seccion.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo revertir la decisión: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _eliminandoDecisionSecciones.remove(seccion.id);
      });
    }
  }

  Future<void> _agregarBloqueSuperficial() async {
    if (_uid == null || _unidadId == null) return;
    setState(() => _agregandoSuperficial = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('actividades_laboreo_superficial')
          .doc();
      await ref.set({
        'uid': _uid!,
        'unidad': _unidadId!,
        'seleccion': _seleccionSuperficial,
        'done': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 180)),
        ),
      });
      final snap = await ref.get();
      final registro = _ActividadSuperficialRegistro.fromDocument(snap);
      if (!mounted) return;
      setState(() {
        _superficiales = <_ActividadSuperficialRegistro>[registro, ..._superficiales];
        _superficialesNuevos.add(registro.docId);
        _agregandoSuperficial = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad de laboreo superficial guardada.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _agregandoSuperficial = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la actividad: $e')),
      );
    }
  }

  Future<void> _eliminarSuperficialNuevo(
    _ActividadSuperficialRegistro registro,
  ) async {
    if (!_superficialesNuevos.contains(registro.docId)) {
      return;
    }
    setState(() => _eliminandoSuperficialId = registro.docId);
    try {
      await FirebaseFirestore.instance
          .collection('actividades_laboreo_superficial')
          .doc(registro.docId)
          .delete();
      if (!mounted) return;
      setState(() {
        _superficiales = _superficiales
            .where((element) => element.docId != registro.docId)
            .toList(growable: false);
        _superficialesNuevos.remove(registro.docId);
        _eliminandoSuperficialId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laboreo superficial eliminado.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (_eliminandoSuperficialId == registro.docId) {
          _eliminandoSuperficialId = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo eliminar la actividad: $e')),
      );
    }
  }

  Future<void> _abrirReporteProfundo(
    _SeccionInfo seccion,
    String fuente,
  ) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ReporteActividadLaboreoProfundoPage(),
      ),
    );
    if (resultado == true) {
      await _registrarReporteProfundo(seccion, fuente);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad de laboreo profundo registrada.')),
      );
    }
  }

  Future<void> _abrirReporteSuperficial(
    _ActividadSuperficialRegistro registro,
  ) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReporteActividadLaboreoSuperficialPage(
          seleccion: registro.seleccion,
        ),
      ),
    );
    if (resultado == true) {
      try {
        final docRef = FirebaseFirestore.instance
            .collection('actividades_laboreo_superficial')
            .doc(registro.docId);
        await docRef.set({
          'done': true,
          'reporteEmitidoAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'expiresAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 180)),
          ),
        }, SetOptions(merge: true));
        final snap = await docRef.get();
        final actualizado = _ActividadSuperficialRegistro.fromDocument(snap);
        if (!mounted) return;
        setState(() {
          _superficiales = _superficiales
              .map((e) => e.docId == actualizado.docId ? actualizado : e)
              .toList();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Actividad de laboreo superficial registrada.')),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo actualizar el reporte: $e')),
        );
      }
    }
  }

  List<Widget> _manualesPlaceholder(String seleccion) {
    final widgets = <Widget>[];
    if (seleccion == 'rastra' || seleccion == 'ambos') {
      widgets.add(_listaManuales('Rastreo', ['Manual de Rastreo 1', 'Manual de Rastreo 2']));
    }
    if (seleccion == 'desterronador' || seleccion == 'ambos') {
      widgets.add(_listaManuales(
        'Desterronador',
        ['Manual de Desterronador 1', 'Manual de Desterronador 2'],
      ));
    }
    return widgets;
  }

  Widget _listaManuales(String titulo, List<String> items) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final item in items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(item),
                trailing: IconButton(
                  icon: const Icon(Icons.visibility),
                  onPressed: () {},
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _manualPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Icon(Icons.menu_book_outlined, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Manual próximamente',
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
    );
  }

  DateTime? _extraerFecha(Map<String, dynamic> data) {
    final fechaCampo = data['fecha'];
    if (fechaCampo is Timestamp) {
      return fechaCampo.toDate();
    }
    if (fechaCampo is String) {
      final parsed = DateTime.tryParse(fechaCampo);
      if (parsed != null) {
        return parsed;
      }
    }
    return (data['updatedAt'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate();
  }

  Widget _barraRecomendacion(_EstadoColor estado, String texto) {
    final color = _colorParaEstado(estado);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _EstadoColor _colorBarra(String seccionId) {
    final datos = _datosPorSeccion[seccionId];
    return datos?.barraColor ?? _EstadoColor.desconocido;
  }

  Color _colorParaEstado(_EstadoColor estado) {
    switch (estado) {
      case _EstadoColor.verde:
        return const Color(0xFF2E7D32);
      case _EstadoColor.amarillo:
        return const Color(0xFFF9A825);
      case _EstadoColor.rojo:
        return const Color(0xFFC62828);
      case _EstadoColor.desconocido:
      default:
        return Colors.blueGrey.shade400;
    }
  }

  Future<String?> _urlDeStoragePath(String path) async {
    try {
      fb_storage.Reference ref;
      if (path.startsWith('gs://') || path.startsWith('http')) {
        ref = fb_storage.FirebaseStorage.instance.refFromURL(path);
      } else {
        ref = fb_storage.FirebaseStorage.instance.ref(path);
      }
      return await ref.getDownloadURL();
    } on fb_storage.FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _abrirUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace proporcionado.')),
      );
      return;
    }
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el documento.')),
      );
    }
  }

  _EstadoColor _estadoDesdeColor(String? color) {
    switch (color) {
      case 'verde':
        return _EstadoColor.verde;
      case 'amarillo':
        return _EstadoColor.amarillo;
      case 'rojo':
        return _EstadoColor.rojo;
      default:
        return _EstadoColor.desconocido;
    }
  }

  DateTime? _fechaDesdeDynamic(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    if (value is int) {
      if (value > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    if (value is num) {
      final intValue = value.toInt();
      if (intValue > 1000000000000) {
        return DateTime.fromMillisecondsSinceEpoch(intValue);
      }
      return DateTime.fromMillisecondsSinceEpoch(intValue * 1000);
    }
    return null;
  }

  String _nombreSeleccion(String raw) {
    switch (raw) {
      case 'ambos':
        return 'Rastreo y Desterronador';
      case 'desterronador':
        return 'Desterronador';
      case 'rastra':
      default:
        return 'Rastreo';
    }
  }
}
