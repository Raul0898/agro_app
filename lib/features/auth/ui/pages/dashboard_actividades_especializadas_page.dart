// lib/features/auth/ui/pages/dashboard_actividades_especializadas_page.dart
import 'package:flutter/material.dart';

class DashboardActividadesEspecializadasPage extends StatelessWidget {
  const DashboardActividadesEspecializadasPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;
          final crossCount = isWide ? 3 : 1;

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Text(
                    'Actividades Especializadas',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF151f28),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossCount,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 16 / 9,
                  ),
                  delegate: SliverChildListDelegate.fixed(const [
                    _KpiCard(title: 'Fertilizaciones (DRON)', value: '—', hint: 'Próximamente'),
                    _KpiCard(title: 'Aplicaciones Foliares', value: '—', hint: 'Próximamente'),
                    _KpiCard(title: 'NDVI Promedio', value: '—', hint: 'Próximamente'),
                  ]),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  child: Card(
                    elevation: 1.5,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'Aquí podrás visualizar métricas y accesos rápidos a Control de Malezas, Aplicaciones Foliares - Plagas - Enfermedades, '
                            'Fertilizaciones Granulares (DRON), Verificación de Germinación (DRON) y Análisis NDVI.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xFF151f28)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final String value;
  final String hint;
  const _KpiCard({required this.title, required this.value, required this.hint});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF151f28),
                )),
            const Spacer(),
            Text(value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF151f28),
                )),
            const SizedBox(height: 8),
            Text(hint, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
