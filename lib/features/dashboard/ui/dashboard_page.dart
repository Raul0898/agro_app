import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/roles.dart';
import '../../auth/ui/login_page.dart';
import '../../fields/ui/fields_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  AppRole? role;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final d = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() { role = roleFromString(d.data()?['role'] as String?); });
  }

  @override
  Widget build(BuildContext context) {
    final modules = _modulesByRole(role);
    return Scaffold(
      appBar: AppBar(
        title: Text(role?.label ?? 'Cargando rol…'),
        actions: [
          IconButton(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginPage()),
                (r) => false,
              );
            },
            icon: const Icon(Icons.logout),
          )
        ],
      ),
      body: role == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Módulos disponibles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: modules.map((m) => _ModuleCard(title: m)).toList(),
                ),
              ],
            ),
    );
  }

  List<String> _modulesByRole(AppRole? r) {
    if (r == AppRole.directorGeneral) {
      return [
        'Registro de Terrenos',
        'Preparación de Suelos',
        'Siembra y Fertilización',
        'Control de Malezas',
        'Fertilizaciones Granulares',
        'Aplicaciones Foliares y Plagas',
        'Cosecha',
        'Análisis de Suelo',
        'Verificación de Compactación',
        'Verificación de Germinación',
        'Instalación de Equipos de Medición',
        'Análisis de Malezas',
        'Análisis de Nutrientes',
        'Seguimiento de Humedad',
        'Materiales de apoyo',
      ];
    }
    if (r == AppRole.directorProduccion) {
      return [
        'Registro de Terrenos',
        'Preparación de Suelos',
        'Siembra y Fertilización',
        'Control de Malezas',
        'Fertilizaciones Granulares',
        'Aplicaciones Foliares y Plagas',
        'Cosecha',
        'Materiales de apoyo',
      ];
    }
    if (r == AppRole.directorCalidad) {
      return [
        'Análisis de Suelo',
        'Verificación de Compactación',
        'Verificación de Germinación',
        'Instalación de Equipos de Medición',
        'Análisis de Malezas',
        'Análisis de Nutrientes',
        'Seguimiento de Humedad',
        'Materiales de apoyo',
      ];
    }
    return ['Materiales de apoyo'];
  }
}

class _ModuleCard extends StatelessWidget {
  final String title;
  const _ModuleCard({required this.title});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Card(
        child: InkWell(
          onTap: () {
            if (title == 'Registro de Terrenos') {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FieldsPage(companyId: 'demoCo'),
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.arrow_forward),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

