// lib/features/auth/ui/pages/dashboard_page.dart
import 'package:flutter/material.dart';
import '../../../../widgets/app_sidebar.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: Row(
        children: [
          AppSidebar(
            selectedIndex: _selected,
            onSelect: (i) => setState(() => _selected = i),
          ),
          Expanded(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 👇 Eliminamos el encabezado duplicado (título + campana/usuario/botón)
                    // const SizedBox(height: 0),

                    // Contenido principal
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, c) {
                          final twoCols = c.maxWidth > 980;
                          return GridView(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: twoCols ? 2 : 1,
                              mainAxisExtent: 170,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            children: const [
                              _StatCard(
                                title: 'Soil Moisture',
                                value: '35 %',
                                icon: Icons.eco_outlined,
                              ),
                              _StatCard(
                                title: 'Temperature',
                                value: '24ºC',
                                icon: Icons.thermostat_outlined,
                              ),
                              _ChartCard(title: 'Crop Monitoring'),
                              _ListCard(
                                title: 'Field Data',
                                items: ['Field 1', 'Field 2', 'Field 3'],
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BaseCard extends StatelessWidget {
  final Widget child;
  const _BaseCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface, // Blanco puro
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.surfaceContainerHighest), // Gris claro
      ),
      padding: const EdgeInsets.all(18),
      child: child,
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return _BaseCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.secondary.withOpacity(.12), // Azul petróleo suave
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: cs.secondary, size: 26),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: text.titleMedium?.copyWith(color: cs.onSurface)),
              const SizedBox(height: 8),
              Text(
                value,
                style: text.headlineMedium?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final String title;
  final List<String> items;
  const _ListCard({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: text.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          ...items.map((e) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record, size: 10, color: cs.tertiary), // Azul grisáceo
                const SizedBox(width: 8),
                Text(e, style: text.bodyLarge?.copyWith(color: cs.onSurface)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  const _ChartCard({required this.title});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return _BaseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: CustomPaint(
              painter: _MiniLinePainter(
                line: cs.secondary, // Azul petróleo
                grid: cs.tertiary.withOpacity(.25), // Azul grisáceo claro
                axis: cs.outline, // Gris medio
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _AxisLabel('Jan'),
              _AxisLabel('Feb'),
              _AxisLabel('Mar'),
              _AxisLabel('Apr'),
            ],
          ),
        ],
      ),
    );
  }
}

class _AxisLabel extends StatelessWidget {
  final String text;
  const _AxisLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.outline,
      ),
    );
  }
}

class _MiniLinePainter extends CustomPainter {
  final Color line;
  final Color grid;
  final Color axis;

  _MiniLinePainter({required this.line, required this.grid, required this.axis});

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()..color = grid..strokeWidth = 1;
    final axisPaint = Paint()..color = axis..strokeWidth = 1.2;
    final linePaint = Paint()
      ..color = line
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke;

    // Grid
    const rows = 4;
    for (int i = 1; i < rows; i++) {
      final dy = size.height * i / rows;
      canvas.drawLine(Offset(0, dy), Offset(size.width, dy), gridPaint);
    }
    // Eje X
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    // Curva ejemplo
    final path = Path();
    path.moveTo(0, size.height * .7);
    path.cubicTo(size.width * .2, size.height * .6, size.width * .35, size.height * .8,
        size.width * .5, size.height * .55);
    path.cubicTo(size.width * .7, size.height * .3, size.width * .85, size.height * .45,
        size.width, size.height * .2);

    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
