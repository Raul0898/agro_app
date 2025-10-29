import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:agro_app/core/firestore/laboreo_service.dart';
import 'package:agro_app/core/router/app_routes.dart';

class PreparacionSuelosPage extends StatefulWidget {
  const PreparacionSuelosPage({super.key});

  @override
  State<PreparacionSuelosPage> createState() => _PreparacionSuelosPageState();
}

enum _CasoGlobal { verde, amarillo, rojo, desconocido }

class _SeccionAnalisis {
  const _SeccionAnalisis({
    required this.id,
    this.nombre,
    this.fecha,
    this.recomendacionTexto,
    this.recomendacionColor,
    this.url,
  });

  final String id;
  final String? nombre;
  final DateTime? fecha;
  final String? recomendacionTexto;
  final String? recomendacionColor;
  final String? url;

  bool get tieneDocumento => nombre != null || fecha != null || recomendacionTexto != null;
}

bool _isWithinSixMonths(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final difference = now.difference(date).inDays;
  return difference <= 180;
}

class _DecisionProfundoState {
  const _DecisionProfundoState({
    required this.docId,
    this.decision,
    this.fuente,
    this.ultimoReporteAt,
    this.updatedAt,
  });

  final String docId;
  final String? decision;
  final String? fuente;
  final DateTime? ultimoReporteAt;
  final DateTime? updatedAt;

  bool get reporteVigente => _isWithinSixMonths(ultimoReporteAt);

  static _DecisionProfundoState fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? <String, dynamic>{};
    return _DecisionProfundoState(
      docId: snap.id,
      decision: (data['decision'] as String?)?.trim(),
      fuente: (data['fuente'] as String?)?.trim(),
      ultimoReporteAt: (data['ultimoReporteAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

class _ActividadSuperficialState {
  const _ActividadSuperficialState({
    required this.docId,
    required this.actividades,
    this.createdAt,
    this.reporteEmitidoAt,
  });

  final String docId;
  final List<String> actividades;
  final DateTime? createdAt;
  final DateTime? reporteEmitidoAt;

  bool get reporteVigente => _isWithinSixMonths(reporteEmitidoAt);

  static _ActividadSuperficialState fromSnapshot(
    QueryDocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data();
    final actividades = (data['actividades'] as List?)
            ?.whereType<String>()
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    return _ActividadSuperficialState(
      docId: snap.id,
      actividades: actividades,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      reporteEmitidoAt: (data['reporteEmitidoAt'] as Timestamp?)?.toDate(),
    );
  }
}

class _PreparacionSuelosPageState extends State<PreparacionSuelosPage> {
  final LaboreoService _service = LaboreoService();

  bool _loading = true;
  String? _error;
  String? _uid;
  String? _unidadId;

  List<_SeccionAnalisis> _secciones = const [];
  _DecisionProfundoState? _decision;
  bool _showDecisionForm = false;
  bool _savingDecision = false;

  List<_ActividadSuperficialState> _superficiales = const [];
  bool _addingSuperficial = false;
  String _superficialOption = 'Rastreo';

  static const List<String> _superficialOptions = <String>[
    'Rastreo',
    'Desterronador',
    'Ambos',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
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
      final unidad = await _service.unidadActualDelUsuario(uid);
      if (unidad == null || unidad.trim().isEmpty) {
        setState(() {
          _loading = false;
          _error = 'No se encontró una unidad asignada al perfil.';
        });
        return;
      }

      final seccionesIds = await _service.seccionesDeUnidad(unidad);
      final secciones = <_SeccionAnalisis>[];
      for (final seccionId in seccionesIds) {
        final snap = await _service.ultimoCompactacionPorSeccion(
          unidadId: unidad,
          seccionId: seccionId,
        );
        secciones.add(_mapSeccion(seccionId, snap));
      }

      final decisionSnap =
          await _service.decisionProfundoDoc(uid: uid, unidadId: unidad);
      final decision =
          decisionSnap == null ? null : _DecisionProfundoState.fromSnapshot(decisionSnap);

      final superficialesDocs =
          await _service.actividadesSuperficiales(uid: uid, unidadId: unidad);
      final superficiales = superficialesDocs
          .map(_ActividadSuperficialState.fromSnapshot)
          .toList();

      setState(() {
        _uid = uid;
        _unidadId = unidad;
        _secciones = secciones;
        _decision = decision;
        _showDecisionForm = decision?.decision == null;
        _superficiales = superficiales;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Error al cargar los datos: $e';
      });
    }
  }

  _SeccionAnalisis _mapSeccion(
    String seccionId,
    QueryDocumentSnapshot<Map<String, dynamic>>? snap,
  ) {
    if (snap == null) {
      return _SeccionAnalisis(id: seccionId);
    }
    final data = snap.data();
    final nombre = (data['nombreArchivo'] as String?) ??
        (data['nombre'] as String?) ??
        (data['titulo'] as String?);
    final url = (data['url'] as String?) ?? (data['downloadUrl'] as String?);
    return _SeccionAnalisis(
      id: seccionId,
      nombre: nombre,
      fecha: (data['fecha'] as Timestamp?)?.toDate(),
      recomendacionTexto: data['recomendacion_texto'] as String?,
      recomendacionColor: data['recomendacion_color'] as String?,
      url: url,
    );
  }

  _CasoGlobal get _estadoGlobal {
    if (_secciones.isEmpty) return _CasoGlobal.desconocido;
    bool hasRojo = false;
    bool hasAmarillo = false;
    bool anyConocido = false;
    for (final seccion in _secciones) {
      final color = _normalizaColor(seccion.recomendacionColor);
      if (color == null) continue;
      anyConocido = true;
      if (color == 'rojo') return _CasoGlobal.rojo;
      if (color == 'amarillo') hasAmarillo = true;
    }
    if (!anyConocido) return _CasoGlobal.desconocido;
    if (hasAmarillo) return _CasoGlobal.amarillo;
    return _CasoGlobal.verde;
  }

  bool get _palomitaProfundo => _decision?.reporteVigente ?? false;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _error!,
            style: const TextStyle(fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildLaboreoProfundo(context),
          const SizedBox(height: 24),
          Divider(color: Colors.black.withOpacity(0.1)),
          const SizedBox(height: 24),
          _buildLaboreoSuperficial(context),
        ],
      ),
    );
  }

  Widget _buildLaboreoProfundo(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[
      Text('Laboreo Profundo', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      if (_secciones.isEmpty)
        _placeholderCard('No hay secciones registradas para la unidad.'),
      for (final seccion in _secciones) _seccionCard(context, seccion),
    ];

    if (_palomitaProfundo && _decision?.ultimoReporteAt != null) {
      children.add(const SizedBox(height: 12));
      children.add(_palomitaRow(
        'Reporte de actividad vigente',
        _decision!.ultimoReporteAt!,
      ));
    }

    children.add(const SizedBox(height: 16));

    switch (_estadoGlobal) {
      case _CasoGlobal.verde:
        children.add(
          _infoChip(
            icon: Icons.verified,
            color: Colors.green.shade600,
            text: 'Todas las secciones están en verde. No se requiere laboreo profundo.',
          ),
        );
        break;
      case _CasoGlobal.amarillo:
        children.addAll(_bloqueAmarillo());
        break;
      case _CasoGlobal.rojo:
        children.addAll(_bloqueRojo());
        break;
      case _CasoGlobal.desconocido:
        children.add(_placeholderCard(
            'No se encontraron recomendaciones recientes para las secciones.'));
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _buildLaboreoSuperficial(BuildContext context) {
    final theme = Theme.of(context);
    final children = <Widget>[
      Text('Laboreo Superficial', style: theme.textTheme.titleLarge),
      const SizedBox(height: 12),
      Text('Selecciona el tipo de laboreo superficial a registrar:',
          style: theme.textTheme.bodyMedium),
      const SizedBox(height: 8),
      DropdownButtonFormField<String>(
        value: _superficialOption,
        items: _superficialOptions
            .map((opt) => DropdownMenuItem<String>(value: opt, child: Text(opt)))
            .toList(),
        onChanged: (value) {
          if (value != null) {
            setState(() => _superficialOption = value);
          }
        },
      ),
      const SizedBox(height: 12),
      _manualPlaceholder(),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: _addingSuperficial ? null : _agregarLaboreoSuperficial,
          label: Text(_addingSuperficial
              ? 'Agregando…'
              : 'Agregar Laboreo Superficial'),
        ),
      ),
      const SizedBox(height: 20),
      if (_superficiales.isEmpty)
        _placeholderCard('Aún no se han registrado actividades de laboreo superficial.'),
      for (final registro in _superficiales)
        _superficialCard(context, registro),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }

  Widget _seccionCard(BuildContext context, _SeccionAnalisis seccion) {
    final theme = Theme.of(context);
    final fecha = seccion.fecha;
    final fechaFmt =
        fecha == null ? 'Sin fecha disponible' : DateFormat('dd/MM/yyyy').format(fecha);
    final color = _normalizaColor(seccion.recomendacionColor);
    final textoRecomendacion = seccion.recomendacionTexto?.trim();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Sección ${seccion.id}', style: theme.textTheme.titleMedium),
                const Spacer(),
                Icon(Icons.segment, color: theme.colorScheme.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text('Fecha: $fechaFmt', style: theme.textTheme.bodySmall),
            if (seccion.nombre != null) ...[
              const SizedBox(height: 6),
              Text(
                seccion.nombre!,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
            if (color != null && textoRecomendacion != null) ...[
              const SizedBox(height: 12),
              _barraRecomendacion(color, textoRecomendacion),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Vista previa'),
                onPressed: seccion.url == null
                    ? null
                    : () => _abrirUrl(seccion.url!),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bloqueAmarillo() {
    if (_savingDecision) {
      return const [Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()))];
    }

    final decision = _decision?.decision;
    if (_showDecisionForm || decision == null) {
      return [
        Text(
          'Se detectaron secciones en amarillo. Define la acción a seguir y se guardará para futuras sesiones.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: null,
          items: const [
            DropdownMenuItem(value: 'realizar', child: Text('Realizar Laboreo Profundo')),
            DropdownMenuItem(value: 'no_realizar', child: Text('No realizar (mantener monitoreo)')),
          ],
          decoration: const InputDecoration(labelText: 'Decisión'),
          onChanged: (value) {
            if (value != null) {
              _guardarDecision(value, 'amarillo_usuario');
            }
          },
        ),
      ];
    }

    if (decision == 'no_realizar') {
      return [
        _infoChip(
          icon: Icons.check_circle_outline,
          color: Colors.green.shade600,
          text: 'Actividad registrada como “No realizar”.',
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => setState(() => _showDecisionForm = true),
          icon: const Icon(Icons.edit_note),
          label: const Text('Tomar otra decisión'),
        ),
      ];
    }

    return [
      _manualPlaceholder(),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Reporte de Actividad'),
          onPressed: () => _abrirReporteProfundo('amarillo_usuario'),
        ),
      ),
    ];
  }

  List<Widget> _bloqueRojo() {
    return [
      _infoChip(
        icon: Icons.priority_high,
        color: Colors.red.shade600,
        text:
            'Se detectaron secciones en rojo. Se recomienda realizar laboreo profundo de inmediato.',
      ),
      const SizedBox(height: 12),
      _manualPlaceholder(),
      const SizedBox(height: 12),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.assignment_outlined),
          label: const Text('Reporte de Actividad'),
          onPressed: () => _abrirReporteProfundo('rojo_auto'),
        ),
      ),
    ];
  }

  Widget _superficialCard(BuildContext context, _ActividadSuperficialState registro) {
    final theme = Theme.of(context);
    final fecha = registro.createdAt;
    final fechaTxt = fecha == null
        ? 'Fecha no disponible'
        : DateFormat('dd/MM/yyyy HH:mm', 'es_MX').format(fecha);
    final actividades = registro.actividades.map(_nombreActividad).toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Registro creado el $fechaTxt',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                if (registro.reporteVigente && registro.reporteEmitidoAt != null)
                  _palomitaRow('Reporte vigente', registro.reporteEmitidoAt!),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: actividades
                  .map((actividad) => Chip(
                        avatar: const Icon(Icons.agriculture, size: 18),
                        label: Text(actividad),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 12),
            _manualPlaceholder(),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.assignment_outlined),
                label: const Text('Reporte de Actividad'),
                onPressed: () => _abrirReporteSuperficial(registro),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarDecision(String decision, String fuente) async {
    if (_uid == null || _unidadId == null) return;
    setState(() {
      _savingDecision = true;
      _showDecisionForm = false;
    });
    try {
      final ref = await _service.guardarDecisionProfundo(
        uid: _uid!,
        unidadId: _unidadId!,
        decision: decision,
        fuente: fuente,
      );
      final snap = await ref.get();
      setState(() {
        _decision = _DecisionProfundoState.fromSnapshot(snap);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decisión guardada correctamente.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la decisión: $e')),
      );
      setState(() => _showDecisionForm = true);
    } finally {
      if (mounted) {
        setState(() => _savingDecision = false);
      }
    }
  }

  Future<String?> _ensureDecisionDoc({
    required String decision,
    required String fuente,
  }) async {
    if (_uid == null || _unidadId == null) return null;
    if (_decision != null &&
        _decision!.decision == decision &&
        (_decision!.fuente ?? '') == fuente &&
        _decision!.docId.isNotEmpty) {
      return _decision!.docId;
    }

    final ref = await _service.guardarDecisionProfundo(
      uid: _uid!,
      unidadId: _unidadId!,
      decision: decision,
      fuente: fuente,
    );
    final snap = await ref.get();
    setState(() {
      _decision = _DecisionProfundoState.fromSnapshot(snap);
      _showDecisionForm = false;
    });
    return _decision?.docId;
  }

  Future<void> _abrirReporteProfundo(String fuente) async {
    if (_uid == null || _unidadId == null) return;
    setState(() => _savingDecision = true);
    try {
      final docId = await _ensureDecisionDoc(decision: 'realizar', fuente: fuente);
      setState(() => _savingDecision = false);
      if (docId == null) return;
      final result = await GoRouter.of(context).push<bool>(
        AppRoutes.reporteLaboreoProfundo,
        extra: LaboreoProfundoArgs(
          uid: _uid!,
          unidadId: _unidadId!,
          decisionFuente: fuente,
          decisionDocId: docId,
        ),
      );
      if (result == true) {
        await _refreshDecision();
      }
    } catch (e) {
      setState(() => _savingDecision = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el reporte: $e')),
      );
    }
  }

  Future<void> _refreshDecision() async {
    if (_uid == null || _unidadId == null) return;
    final snap =
        await _service.decisionProfundoDoc(uid: _uid!, unidadId: _unidadId!);
    setState(() {
      _decision = snap == null ? null : _DecisionProfundoState.fromSnapshot(snap);
      _showDecisionForm = _decision?.decision == null;
    });
  }

  Future<void> _agregarLaboreoSuperficial() async {
    if (_uid == null || _unidadId == null) return;
    final actividades = _mapActividadesDesdeSeleccion(_superficialOption);
    if (actividades.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una actividad válida.')),
      );
      return;
    }
    setState(() => _addingSuperficial = true);
    try {
      await _service.crearSuperficial(
        uid: _uid!,
        unidadId: _unidadId!,
        actividades: actividades,
      );
      await _refreshSuperficiales();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Actividad de laboreo superficial registrada.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo registrar la actividad: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _addingSuperficial = false);
      }
    }
  }

  Future<void> _refreshSuperficiales() async {
    if (_uid == null || _unidadId == null) return;
    final docs = await _service.actividadesSuperficiales(
      uid: _uid!,
      unidadId: _unidadId!,
    );
    setState(() {
      _superficiales = docs.map(_ActividadSuperficialState.fromSnapshot).toList();
    });
  }

  Future<void> _abrirReporteSuperficial(
      _ActividadSuperficialState registro) async {
    if (_uid == null || _unidadId == null) return;
    final result = await GoRouter.of(context).push<bool>(
      AppRoutes.reporteLaboreoSuperficial,
      extra: LaboreoSuperficialArgs(
        uid: _uid!,
        unidadId: _unidadId!,
        actividades: registro.actividades,
        actividadDocId: registro.docId,
      ),
    );
    if (result == true) {
      await _refreshSuperficiales();
    }
  }

  List<String> _mapActividadesDesdeSeleccion(String seleccion) {
    switch (seleccion) {
      case 'Rastreo':
        return const ['rastra'];
      case 'Desterronador':
        return const ['desterronador'];
      case 'Ambos':
        return const ['rastra', 'desterronador'];
      default:
        return const [];
    }
  }

  String _nombreActividad(String raw) {
    switch (raw.toLowerCase()) {
      case 'rastra':
        return 'Rastreo';
      case 'desterronador':
        return 'Desterronador';
      default:
        return raw;
    }
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

  Widget _palomitaRow(String label, DateTime fecha) {
    final fechaTxt = DateFormat('dd/MM/yyyy').format(fecha);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.check_circle, color: Colors.green),
        const SizedBox(width: 6),
        Text('$label — $fechaTxt',
            style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _infoChip({required IconData icon, required Color color, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
    );
  }

  Widget _barraRecomendacion(String color, String texto) {
    Color bg;
    switch (color) {
      case 'verde':
        bg = Colors.green.shade600;
        break;
      case 'amarillo':
        bg = Colors.amber.shade600;
        break;
      case 'rojo':
        bg = Colors.red.shade600;
        break;
      default:
        bg = Colors.blueGrey.shade400;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
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

  static String? _normalizaColor(String? raw) {
    final value = raw?.trim().toLowerCase();
    if (value == null || value.isEmpty) return null;
    if (value == 'verde' || value == 'amarillo' || value == 'rojo') {
      return value;
    }
    return null;
  }

}
