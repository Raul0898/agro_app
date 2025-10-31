import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

class _SeccionResultado {
  const _SeccionResultado({
    required this.info,
    this.doc,
    required this.color,
    required this.texto,
    this.nombre,
    this.fecha,
    this.url,
  });

  final _SeccionInfo info;
  final DocumentSnapshot<Map<String, dynamic>>? doc;
  final _EstadoColor color;
  final String texto;
  final String? nombre;
  final DateTime? fecha;
  final String? url;

  bool get tieneDocumento => doc != null;
}

class _DecisionProfundoState {
  const _DecisionProfundoState({
    required this.docId,
    required this.decision,
    required this.fuente,
    this.createdAt,
    this.updatedAt,
    this.reporteEmitidoAt,
  });

  final String docId;
  final String? decision;
  final String? fuente;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? reporteEmitidoAt;

  bool get reporteVigente => _isWithinSixMonths(reporteEmitidoAt);

  factory _DecisionProfundoState.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? <String, dynamic>{};
    return _DecisionProfundoState(
      docId: snap.id,
      decision: (data['decision'] as String?)?.trim(),
      fuente: (data['fuente'] as String?)?.trim(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      reporteEmitidoAt: (data['reporteEmitidoAt'] as Timestamp?)?.toDate(),
    );
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

class _PreparacionSuelosPageState extends State<PreparacionSuelosPage> {
  bool _loading = true;
  String? _error;
  String? _uid;
  String? _unidadId;

  List<_SeccionInfo> _secciones = const [];
  final Map<String, _SeccionResultado> _resultados = {};
  _DecisionProfundoState? _decision;
  bool _guardandoDecision = false;

  List<_ActividadSuperficialRegistro> _superficiales = const [];
  bool _agregandoSuperficial = false;
  String _seleccionSuperficial = 'rastra';

  @override
  void initState() {
    super.initState();
    _cargarTodo();
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
      final resultados = <String, _SeccionResultado>{};
      for (final seccion in secciones) {
        final resultado = await _cargarResultado(unidad, seccion);
        resultados[seccion.id] = resultado;
      }
      final decision = await _cargarDecision(uid, unidad);
      final superficiales = await _cargarActividades(uid, unidad);

      if (!mounted) return;
      setState(() {
        _uid = uid;
        _unidadId = unidad;
        _secciones = secciones;
        _resultados
          ..clear()
          ..addAll(resultados);
        _decision = decision;
        _superficiales = superficiales;
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
      return seccionesDesdeLista;
    }

    final count = _intFromDynamic(data['seccionesCount']) ??
        _intFromDynamic(data['num_secciones']) ??
        _intFromDynamic(data['numSecciones']);
    if (count != null && count > 0) {
      return List<_SeccionInfo>.generate(
        count,
        (index) => _SeccionInfo(
          id: '${index + 1}',
        ),
      );
    }

    return const <_SeccionInfo>[
      _SeccionInfo(id: '1'),
    ];
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

  Future<_SeccionResultado> _cargarResultado(
    String unidad,
    _SeccionInfo seccion,
  ) async {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('resultados_analisis_compactacion')
        .where('unidad', isEqualTo: unidad)
        .where('seccion', isEqualTo: seccion.id)
        .orderBy('updatedAt', descending: true)
        .limit(1);

    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await query.get();
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        snap = await FirebaseFirestore.instance
            .collection('resultados_analisis_compactacion')
            .where('unidad', isEqualTo: unidad)
            .where('seccion', isEqualTo: seccion.id)
            .limit(1)
            .get();
      } else {
        rethrow;
      }
    }

    if (snap.docs.isEmpty) {
      final asInt = int.tryParse(seccion.id);
      if (asInt != null) {
        Query<Map<String, dynamic>> altQuery = FirebaseFirestore.instance
            .collection('resultados_analisis_compactacion')
            .where('unidad', isEqualTo: unidad)
            .where('seccion', isEqualTo: asInt)
            .orderBy('updatedAt', descending: true)
            .limit(1);
        try {
          snap = await altQuery.get();
        } on FirebaseException catch (e) {
          if (e.code == 'failed-precondition') {
            snap = await FirebaseFirestore.instance
                .collection('resultados_analisis_compactacion')
                .where('unidad', isEqualTo: unidad)
                .where('seccion', isEqualTo: asInt)
                .limit(1)
                .get();
          } else {
            rethrow;
          }
        }
      }
    }

    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (snap.docs.isNotEmpty) {
      doc = snap.docs.first;
    }

    final data = doc?.data() ?? <String, dynamic>{};
    final recomendacion =
        (data['recomendacion'] as Map<String, dynamic>?) ?? const {};
    final colorRaw = (recomendacion['color'] as String?)?.toLowerCase().trim();
    final texto = (recomendacion['texto'] as String?)?.trim() ??
        'Sin recomendación disponible';
    final nombre = (data['nombreArchivo'] as String?) ??
        (data['nombre'] as String?) ??
        (data['titulo'] as String?);
    final url = (data['urlPdf'] as String?) ??
        (data['url'] as String?) ??
        (data['downloadUrl'] as String?);
    final fecha = (data['updatedAt'] as Timestamp?)?.toDate() ??
        (data['createdAt'] as Timestamp?)?.toDate();

    return _SeccionResultado(
      info: seccion,
      doc: doc,
      color: _estadoDesdeColor(colorRaw),
      texto: texto.isEmpty ? 'Sin recomendación disponible' : texto,
      nombre: nombre,
      fecha: fecha,
      url: url,
    );
  }

  Future<_DecisionProfundoState?> _cargarDecision(
    String uid,
    String unidad,
  ) async {
    final snap = await FirebaseFirestore.instance
        .collection('decisiones_laboreo_profundo')
        .where('uid', isEqualTo: uid)
        .where('unidad', isEqualTo: unidad)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return _DecisionProfundoState.fromSnapshot(snap.docs.first);
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

  bool get _hayRojo =>
      _resultados.values.any((resultado) => resultado.color == _EstadoColor.rojo);

  bool get _hayAmarillo => !_hayRojo &&
      _resultados.values.any((resultado) => resultado.color == _EstadoColor.amarillo);

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
        for (final seccion in _secciones)
          _seccionCard(_resultados[seccion.id] ?? _SeccionResultado(
            info: seccion,
            color: _EstadoColor.desconocido,
            texto: 'Sin información disponible',
          )),
        const SizedBox(height: 16),
        if (_hayRojo) _bloqueRojo(),
        if (!_hayRojo && _hayAmarillo) _bloqueAmarillo(),
      ],
    );
  }

  Widget _seccionCard(_SeccionResultado resultado) {
    final theme = Theme.of(context);
    final fecha = resultado.fecha;
    final fechaTexto = fecha == null
        ? 'Sin fecha disponible'
        : DateFormat('dd/MM/yyyy', 'es_MX').format(fecha);
    final nombre = resultado.nombre ?? 'Documento sin nombre';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sección ${resultado.info.id}',
                    style: theme.textTheme.titleMedium),
                const Spacer(),
                Icon(Icons.segment, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text('Fecha: $fechaTexto', style: theme.textTheme.bodySmall),
            const SizedBox(height: 6),
            Text(
              nombre,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _barraRecomendacion(resultado.color, resultado.texto),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: resultado.url == null
                    ? null
                    : () => _abrirUrl(resultado.url!),
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bloqueRojo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _manualPlaceholder(),
            const SizedBox(height: 12),
            _reporteProfundoButton(fuente: 'rojo'),
          ],
        ),
      ),
    );
  }

  Widget _bloqueAmarillo() {
    if (_guardandoDecision) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final decision = _decision?.decision;
    if (decision == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Se detectaron secciones en amarillo. Selecciona la acción a realizar y se guardará para futuras sesiones.',
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
                _guardarDecision(value, 'amarillo');
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
              onPressed: _revertirDecision,
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
        _reporteProfundoButton(fuente: 'amarillo'),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _revertirDecision,
            child: const Text('Tomar otra decisión'),
          ),
        ),
      ],
    );
  }

  Widget _reporteProfundoButton({required String fuente}) {
    final bool mostrarPalomita = _decision?.reporteVigente ?? false;
    return Row(
      children: [
        FilledButton.icon(
          onPressed: () => _abrirReporteProfundo(fuente),
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
            Row(
              children: [
                FilledButton.icon(
                  onPressed: () => _abrirReporteSuperficial(registro),
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Reporte de Actividad'),
                ),
                if (registro.reporteVigente) ...[
                  const SizedBox(width: 8),
                  const Icon(Icons.check_circle, color: Colors.green),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarDecision(String decision, String fuente) async {
    if (_uid == null || _unidadId == null) return;
    setState(() => _guardandoDecision = true);
    try {
      final ref = FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo');
      late final DocumentReference<Map<String, dynamic>> docRef;
      if (_decision != null) {
        docRef = ref.doc(_decision!.docId);
      } else {
        docRef = ref.doc();
      }
      final data = <String, dynamic>{
        'uid': _uid!,
        'unidad': _unidadId!,
        'decision': decision,
        'fuente': fuente,
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 180)),
        ),
      };
      if (_decision == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
      final snap = await docRef.get();
      if (!mounted) return;
      setState(() {
        _decision = _DecisionProfundoState.fromSnapshot(snap);
        _guardandoDecision = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoDecision = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la decisión: $e')),
      );
    }
  }

  Future<void> _registrarReporteProfundo(String fuente) async {
    if (_uid == null || _unidadId == null) return;
    try {
      final ref = FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo');
      late final DocumentReference<Map<String, dynamic>> docRef;
      if (_decision != null) {
        docRef = ref.doc(_decision!.docId);
      } else {
        docRef = ref.doc();
      }
      final data = <String, dynamic>{
        'uid': _uid!,
        'unidad': _unidadId!,
        'decision': 'realizar',
        'fuente': fuente,
        'reporteEmitidoAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(
          DateTime.now().add(const Duration(days: 180)),
        ),
      };
      if (_decision == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
      }
      await docRef.set(data, SetOptions(merge: true));
      final snap = await docRef.get();
      if (!mounted) return;
      setState(() {
        _decision = _DecisionProfundoState.fromSnapshot(snap);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la actividad: $e')),
      );
    }
  }

  Future<void> _revertirDecision() async {
    if (_uid == null || _unidadId == null || _decision == null) return;
    setState(() => _guardandoDecision = true);
    try {
      await FirebaseFirestore.instance
          .collection('decisiones_laboreo_profundo')
          .doc(_decision!.docId)
          .delete();
      if (!mounted) return;
      setState(() {
        _decision = null;
        _guardandoDecision = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardandoDecision = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo revertir la decisión: $e')),
      );
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

  Future<void> _abrirReporteProfundo(String fuente) async {
    final resultado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ReporteActividadLaboreoProfundoPage(),
      ),
    );
    if (resultado == true) {
      await _registrarReporteProfundo(fuente);
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
