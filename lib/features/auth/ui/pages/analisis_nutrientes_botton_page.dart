// lib/features/auth/ui/pages/analisis_nutrientes_botton_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnalisisNutrientesPage extends StatefulWidget {
  const AnalisisNutrientesPage({super.key});

  @override
  State<AnalisisNutrientesPage> createState() => _AnalisisNutrientesPageState();
}

class _AnalisisNutrientesPageState extends State<AnalisisNutrientesPage> {
  static const kOrange = Color(0xFFF2AE2E);

  // Args de navegación
  String _unidad = 'Unidad';
  String _seccion = 'seccion_unica';
  bool _argsLoaded = false;

  int get _year => DateTime.now().year;
  String _ts() => DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_argsLoaded) return;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      _unidad = (args['unidadSeleccionada'] as String?)?.trim().isNotEmpty == true
          ? (args['unidadSeleccionada'] as String).trim()
          : _unidad;
      _seccion = (args['seccionSeleccionada'] as String?)?.trim().isNotEmpty == true
          ? (args['seccionSeleccionada'] as String).trim()
          : _seccion;
    }
    _argsLoaded = true;
  }

  // Helper de ruta para "Análisis de Nutrientes" (cuando implementes guardar PDF)
  String _buildStoragePathAnalisisNutrientes(String fileName) {
    // unidades_info/<Unidad>/analisis_suelo/analisis/analisis_nutrientes/<seccion>/<AÑO>/<fileName>
    return 'unidades_info/$_unidad/analisis_suelo/analisis/analisis_nutrientes/$_seccion/$_year/$fileName';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('Análisis de Nutrientes'),
          backgroundColor: kOrange,
          foregroundColor: Colors.black,
        ),
        body: Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Text('Contenido de Análisis de Nutrientes (en construcción)', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text('Unidad: $_unidad — Sección: $_seccion', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            // Ejemplo de cómo se armaría el nombre:
                  Builder(
                    builder: (context) {
                      final demoName = 'Analisis_Nutrientes_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
                      return Text('Ej. nombre archivo: $demoName', style: const TextStyle(fontSize: 12));
                    },
                  ),
                ],
  ),
  ),
  );
}
}
