// lib/features/auth/ui/pages/selector_contexto_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:agro_app/home_page.dart';

class SelectorContextoPage extends StatefulWidget {
  const SelectorContextoPage({super.key});

  @override
  State<SelectorContextoPage> createState() => _SelectorContextoPageState();
}

class _SelectorContextoPageState extends State<SelectorContextoPage> {
  final _accent = const Color(0xFFF2AE2E);
  bool _loading = true;

  String? _selectedUnidadId;
  String? _selectedCultivo;

  // Mapa para guardar los detalles de las unidades autorizadas
  final Map<String, _UnidadInfo> _unidadesDisponibles = {};

  // Devuelve los nombres de las unidades para el Dropdown
  List<String> get _unidadesNombres => _unidadesDisponibles.keys.toList();

  // Devuelve los cultivos de la unidad seleccionada
  List<String> get _cultivosDisponibles {
    if (_selectedUnidadId == null) return const [];
    return _unidadesDisponibles[_selectedUnidadId]?.cultivos ?? const [];
  }

  @override
  void initState() {
    super.initState();
    _cargarOpciones();
  }

  Future<void> _cargarOpciones() async {
    setState(() => _loading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }

    try {
      // 1. Obtener la lista de IDs de unidades autorizadas del usuario
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final List<String> unidadesAutorizadasIds = List<String>.from(userDoc.data()?['unidadesAutorizadas'] ?? []);

      if (unidadesAutorizadasIds.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      // 2. Buscar los detalles de cada unidad autorizada en el catálogo central
      final unidadesSnapshot = await FirebaseFirestore.instance
          .collection('unidades_catalog')
          .where(FieldPath.documentId, whereIn: unidadesAutorizadasIds)
          .get();

      final Map<String, _UnidadInfo> unidadesCargadas = {};
      for (var doc in unidadesSnapshot.docs) {
        final data = doc.data();
        final nombre = data['nombre'] as String? ?? doc.id;
        final cultivos = List<String>.from(data['cultivos'] ?? []);
        unidadesCargadas[doc.id] = _UnidadInfo(nombre: nombre, cultivos: cultivos);
      }

      if (mounted) {
        setState(() {
          _unidadesDisponibles.clear();
          _unidadesDisponibles.addAll(unidadesCargadas);
          _loading = false;
        });
      }

    } catch (e) {
      debugPrint('Error al cargar opciones de contexto: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmarYSeguir() async {
    final unidad = _selectedUnidadId;
    final cultivo = _selectedCultivo;

    if (unidad == null || cultivo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona ambos campos para continuar.')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'unidadSeleccionada': unidad,
        'cultivoSeleccionado': cultivo,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomePage()),
      );

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar la selección: $e')),
      );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset('IMG/3.jpg', fit: BoxFit.cover)),
          Positioned.fill(child: Container(color: Colors.black.withOpacity(0.25))),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ... (Resto de la UI sin cambios, como logo y título) ...
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Image.asset(
                          'IMG/Copia de Don Raul-2.png',
                          height: MediaQuery.of(context).size.height * 0.25,
                          fit: BoxFit.contain,
                        ),
                      ),
                      Text(
                        'Selecciona el contexto',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_loading)
                        CircularProgressIndicator(color: _accent)
                      else if (_unidadesDisponibles.isEmpty)
                        const Text(
                          'No tienes unidades de siembra asignadas. Contacta a un administrador.',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        )
                      else ...[
                          // Dropdown de Unidades
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: _dropdownDecoration('Unidad de Siembra'),
                            initialValue: _selectedUnidadId,
                            items: _unidadesDisponibles.entries.map((entry) {
                              return DropdownMenuItem(value: entry.key, child: Text(entry.value.nombre));
                            }).toList(),
                            onChanged: (val) {
                              setState(() {
                                _selectedUnidadId = val;
                                _selectedCultivo = null;
                              });
                            },
                          ),
                          const SizedBox(height: 16),
                          // Dropdown de Cultivos
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: _dropdownDecoration('Tipo de Cultivo'),
                            initialValue: _selectedCultivo,
                            items: _cultivosDisponibles
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (_selectedUnidadId == null) ? null : (val) {
                              setState(() => _selectedCultivo = val);
                            },
                          ),
                          const SizedBox(height: 22),
                          // Botón de Siguiente
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onPressed: (_selectedUnidadId != null && _selectedCultivo != null)
                                  ? _confirmarYSeguir
                                  : null,
                              icon: const Icon(Icons.arrow_forward),
                              label: const Text('Siguiente', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

// Clase auxiliar para guardar la información de la unidad
class _UnidadInfo {
  final String nombre;
  final List<String> cultivos;
  _UnidadInfo({required this.nombre, required this.cultivos});
}