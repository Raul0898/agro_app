import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agro_app/features/analisis/ui/widgets/repo_card_compaction.dart'
    as repo_widgets;
import 'package:agro_app/features/analisis/ui/widgets/repo_pdf_viewer.dart';
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

List<String> _seccionCandidatos(String n) => [
      n,
      'Sección $n',
      'Seccion $n',
      'seccion_$n',
      'Seccion_$n',
      'sec_$n',
    ];

Map<String, dynamic> _asSD(dynamic v) =>
    v is Map ? v.map((k, val) => MapEntry(k.toString(), val)) : <String, dynamic>{};

Map<String, dynamic> _docData(dynamic d) {
  try {
    final raw = (d as dynamic).data();
    return raw is Map<String, dynamic> ? raw : _asSD(raw);
  } catch (_) {
    return {};
  }
}

String _str(dynamic v) => v?.toString().trim() ?? '';

String _colorNormalizado(dynamic v) {
  final s = _str(v).toLowerCase();
  if (s.contains('rojo')) return 'rojo';
  if (s.contains('amarillo')) return 'amarillo';
  if (s.contains('verde')) return 'verde';
  return 'desconocido';
}

String _textoPorColor(String color) => switch (color) {
      'rojo' => 'Requiere Subsuelo',
      'amarillo' => 'No requiere Subsuelo (monitorear)',
      'verde' => 'No requiere Subsuelo',
      _ => 'Sin recomendación disponible',
    };

Color _chipColor(String color) => switch (color) {
      'rojo' => const Color(0xFFE53935),
      'amarillo' => const Color(0xFFFFB300),
      'verde' => const Color(0xFF43A047),
      _ => Colors.blueGrey,
    };

class RepoItem {
  final String titulo;
  final DateTime? fecha;
  final String? storagePath;
  final String? downloadUrl;
  final String color;
  final String texto;

  const RepoItem({
    required this.titulo,
    this.fecha,
    this.storagePath,
    this.downloadUrl,
    required this.color,
    required this.texto,
  });
}

Future<String?> _urlDesdeDoc(Map<String, dynamic> m) async {
  final direct = _str(m['downloadUrl1'] ?? m['downloadURL'] ?? m['url']);
  if (direct.isNotEmpty) return direct;

  final sp =
      _str(m['storagePath'] ?? m['path'] ?? m['storage_path'] ?? m['ruta']);
  if (sp.isEmpty) return null;
  try {
    final storage = FirebaseStorage.instance;
    final ref = sp.startsWith('gs://')
        ? storage.refFromURL(sp)
        : storage.ref(sp);
    return await ref.getDownloadURL();
  } catch (_) {
    return null;
  }
}

_EstadoColor _estadoFromAny(dynamic v) {
  switch (_colorNormalizado(v)) {
    case 'rojo':
      return _EstadoColor.rojo;
    case 'amarillo':
      return _EstadoColor.amarillo;
    case 'verde':
      return _EstadoColor.verde;
    default:
      return _EstadoColor.desconocido;
  }
}

class _PreparacionSuelosPageState extends State<PreparacionSuelosPage> {
  bool _loading = true;
  String? _error;
  String? _uid;
  String? _unidadId;

  final List<_SeccionInfo> _secciones = [];
  final Map<String, RepoItem> _datosPorSeccion = {};
  final Map<String, String?> _decisionPorSeccion = {};
  bool hayRojoGlobal = false;
  bool hayAmarilloGlobal = false;
  final List<_DecisionSeccionState> _decisiones = [];
  final Set<String> _guardandoDecisionSecciones = <String>{};
  final Set<String> _eliminandoDecisionSecciones = <String>{};

  final List<_ActividadSuperficialRegistro> _superficiales = [];
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
      final datosPorSeccion = <String, RepoItem>{};
      var hayRojo = false;
      var hayAmarillo = false;

        for (final seccion in secciones) {
          final item = await _ultimoDeSeccion(unidad, seccion.id);
          final repoItem = item ??
              const RepoItem(
                titulo: 'Sin archivo reciente',
                fecha: null,
                storagePath: null,
                downloadUrl: null,
                color: 'desconocido',
                texto: 'Sin recomendación disponible',
              );

        final barraColor = _estadoFromAny(repoItem.color);
        if (barraColor == _EstadoColor.rojo) {
          hayRojo = true;
        }
        if (barraColor == _EstadoColor.amarillo) {
          hayAmarillo = true;
        }

        datosPorSeccion[seccion.id] = repoItem;
      }

      final decisionesDetalladas = await _cargarDecisiones(uid, unidad);
      final decisionesMap = <String, String?>{};
      for (final estado in decisionesDetalladas) {
        if (estado.seccionId.isEmpty) continue;
        decisionesMap[estado.seccionId] = estado.decision?.trim();
      }

      final superficiales = await _cargarActividades(uid, unidad);

      if (!mounted) return;
      setState(() {
        _uid = uid;
        _unidadId = unidad;

        _secciones
          ..clear()
          ..addAll(secciones);

        _datosPorSeccion
          ..clear()
          ..addAll(datosPorSeccion);

        _decisionPorSeccion
          ..clear()
          ..addAll(decisionesMap);

        _decisiones
          ..clear()
          ..addAll(decisionesDetalladas);

        hayRojoGlobal = hayRojo;
        hayAmarilloGlobal = !hayRojo && hayAmarillo;

        _superficiales
          ..clear()
          ..addAll(superficiales);

        if (_eliminandoSuperficialId != null &&
            _superficiales.every((r) => r.docId != _eliminandoSuperficialId)) {
          _eliminandoSuperficialId = null;
        }

        _superficialesNuevos.removeWhere(
          (id) => _superficiales.every((registro) => registro.docId != id),
        );

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

  String? _stringFromDynamic(dynamic v) {
    if (v == null) return null;
    if (v is DocumentReference) {
      final value = v.id.trim();
      return value.isEmpty ? null : value;
    }
    final value = v.toString().trim();
    return value.isEmpty ? null : value;
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

  Future<RepoItem?> _ultimoDeSeccion(String unidad, String seccionId) async {
    final col = FirebaseFirestore.instance
        .collection('resultados_analisis_compactacion');

    Future<RepoItem?> _fromSnap(QuerySnapshot<Map<String, dynamic>> snap) async {
      if (snap.docs.isEmpty) return null;
      final m = _docData(snap.docs.first);
      final archivo = _asSD(m['archivo']);
      final recomendacion = _asSD(m['recomendacion']);

      var titulo = _str(m['nombre']);
      if (titulo.isEmpty) {
        titulo = _str(m['encabezado_nombre']);
      }
      if (titulo.isEmpty) {
        titulo = _str(archivo['nombre'] ??
            archivo['fileName'] ??
            archivo['titulo'] ??
            m['nombreArchivo']);
      }
      if (titulo.isEmpty) {
        titulo = 'Documento sin nombre';
      }

      DateTime? fecha;
      for (final candidate in [
        m['fecha'],
        archivo['fecha'],
        archivo['updatedAt'],
        archivo['uploadedAt'],
        archivo['actualizado'],
      ]) {
        if (candidate is Timestamp) {
          fecha = candidate.toDate();
          break;
        }
        if (candidate is DateTime) {
          fecha = candidate;
          break;
        }
        if (candidate is String) {
          final parsed = DateTime.tryParse(candidate);
          if (parsed != null) {
            fecha = parsed;
            break;
          }
        }
      }

      final color = _colorNormalizado(
        m['caso'] ?? recomendacion['color'] ?? archivo['color'],
      );

      final textoRecomendacion = _str(
        recomendacion['texto'] ?? recomendacion['mensaje'] ?? m['texto'] ?? m['mensaje'],
      );
      final texto = textoRecomendacion.isNotEmpty
          ? textoRecomendacion
          : _textoPorColor(color);

      final storagePath = _str(
        m['storagePath'] ??
            m['path'] ??
            m['storage_path'] ??
            m['ruta'] ??
            archivo['storagePath'] ??
            archivo['storage_path'] ??
            archivo['path'] ??
            archivo['ruta'],
      );

      final merged = <String, dynamic>{}
        ..addAll(m)
        ..addAll(archivo);
      final directUrl = await _urlDesdeDoc(merged);

      return RepoItem(
        titulo: titulo,
        fecha: fecha,
        storagePath: storagePath.isEmpty ? null : storagePath,
        downloadUrl: directUrl,
        color: color,
        texto: texto,
      );
    }

    try {
      final inValues = _seccionCandidatos(seccionId).take(10).toList();
      var snap = await col
          .where('unidad', isEqualTo: unidad)
          .where('seccion', whereIn: inValues)
          .orderBy('fecha', descending: true)
          .limit(1)
          .get();

      if (snap.docs.isEmpty) {
        for (final s in ['Sección $seccionId', seccionId]) {
          snap = await col
              .where('unidad', isEqualTo: unidad)
              .where('seccion', isEqualTo: s)
              .orderBy('fecha', descending: true)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) break;
        }
      }

      return await _fromSnap(snap);
    } catch (e) {
      // ignore: avoid_print
      print(
        '[PrepSuelos] _ultimoDeSeccion unidad=$unidad seccion=$seccionId error: $e',
      );
      return null;
    }
  }

  Future<List<_DecisionSeccionState>> _cargarDecisiones(
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
    return resultado.values.toList(growable: false);
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
        if (hayRojoGlobal) ...[
          const SizedBox(height: 16),
          Text(
            'Se detectaron secciones en rojo. Revisa el manual y registra la actividad necesaria.',
            style: theme.textTheme.bodyMedium,
          ),
        ] else if (hayAmarilloGlobal) ...[
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
    final repoItem = _datosPorSeccion[seccion.id] ??
        const RepoItem(
          titulo: 'Sin archivo reciente',
          fecha: null,
          storagePath: null,
          downloadUrl: null,
          color: 'desconocido',
          texto: 'Sin recomendación disponible',
        );
    final normalizedColor = _colorNormalizado(repoItem.color);
    final barraColor = _estadoFromAny(normalizedColor);
    final barraTexto = repoItem.texto.trim().isNotEmpty
        ? repoItem.texto
        : _textoPorColor(normalizedColor);
    final hasArchivo =
        _str(repoItem.downloadUrl).isNotEmpty || _str(repoItem.storagePath).isNotEmpty;

    final cardItem = repo_widgets.RepoItem(
      titulo: repoItem.titulo,
      fecha: repoItem.fecha,
      storagePath: repoItem.storagePath,
      color: normalizedColor,
      texto: repoItem.texto,
    );

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
            const SizedBox(height: 12),
            repo_widgets.RepoCardCompaction(
              item: cardItem,
              showDelete: false,
              showTexto: false,
              onPreview: hasArchivo
                  ? () async {
                      final url = await _urlDesdeDoc({
                        'downloadUrl1': repoItem.downloadUrl,
                        'storagePath': repoItem.storagePath,
                      });
                      if (!mounted) return;
                      if (url == null || url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo abrir el archivo.'),
                          ),
                        );
                        return;
                      }
                      await openRepoPdf(context, url, title: repoItem.titulo);
                    }
                  : null,
              onDownload: hasArchivo
                  ? () async {
                      final url = await _urlDesdeDoc({
                        'downloadUrl1': repoItem.downloadUrl,
                        'storagePath': repoItem.storagePath,
                      });
                      if (!mounted) return;
                      if (url == null || url.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No se pudo descargar el archivo.'),
                          ),
                        );
                        return;
                      }
                      await downloadRepoFile(
                        context,
                        url,
                        suggestedName: sanitizeRepoFileName(repoItem.titulo),
                      );
                    }
                  : null,
            ),
            const SizedBox(height: 12),
            _barraRecomendacion(barraColor, barraTexto),
            if (barraColor == _EstadoColor.rojo) ...[
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
            ] else if (barraColor == _EstadoColor.amarillo) ...[
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
    final decision = _decisionPorSeccion[seccion.id]?.trim();

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

  _DecisionSeccionState? _decisionStateFor(String seccionId) {
    for (final estado in _decisiones) {
      if (estado.seccionId == seccionId) {
        return estado;
      }
    }
    return null;
  }

  Widget _reporteProfundoButton({
    required _SeccionInfo seccion,
    required String fuente,
  }) {
    final decision = _decisionStateFor(seccion.id);
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
      final existente = _decisionStateFor(seccionId);
      final docRef = existente != null ? ref.doc(existente.docId) : ref.doc();
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
        _decisionPorSeccion[seccionId] = nuevo.decision?.trim();
        final index =
            _decisiones.indexWhere((element) => element.seccionId == seccionId);
        if (index >= 0) {
          _decisiones[index] = nuevo;
        } else {
          _decisiones.add(nuevo);
        }
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
      final existente = _decisionStateFor(seccionId);
      final docRef = existente != null ? ref.doc(existente.docId) : ref.doc();
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
        _decisionPorSeccion[seccionId] = nuevo.decision?.trim();
        final index =
            _decisiones.indexWhere((element) => element.seccionId == seccionId);
        if (index >= 0) {
          _decisiones[index] = nuevo;
        } else {
          _decisiones.add(nuevo);
        }
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
    final existente = _decisionStateFor(seccion.id);
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
        _decisiones.removeWhere((element) => element.docId == existente.docId);
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
        _superficiales.insert(0, registro);
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
        _superficiales
            .removeWhere((element) => element.docId == registro.docId);
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
          final index =
              _superficiales.indexWhere((e) => e.docId == actualizado.docId);
          if (index >= 0) {
            _superficiales[index] = actualizado;
          }
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

  Widget _barraRecomendacion(_EstadoColor estado, String texto) {
    final color = _colorParaEstado(estado);
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        texto,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _colorParaEstado(_EstadoColor estado) {
    switch (estado) {
      case _EstadoColor.verde:
        return _chipColor('verde');
      case _EstadoColor.amarillo:
        return _chipColor('amarillo');
      case _EstadoColor.rojo:
        return _chipColor('rojo');
      case _EstadoColor.desconocido:
        return _chipColor('desconocido');
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
