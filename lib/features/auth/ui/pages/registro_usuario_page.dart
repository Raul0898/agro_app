// lib/features/auth/ui/pages/registro_usuario_page.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Importaciones para la navegación lateral (sin conflictos)
import '../../../../widgets/mini_icon_rail_scaffold.dart';
import 'equipos_pequenos_page.dart' show EquiposPequenosPage;
import 'equipos_grandes_page.dart' show EquiposGrandesPage;
import 'materiales_page.dart' show MaterialesPage;
import 'registro_implementos_page.dart' show RegistroImplementosPage;

// IMPORT CON ALIAS para evitar colisión
import 'package:agro_app/features/auth/ui/pages/registro_unidades_siembra_page.dart' as reg_unidades;

final Color colorNaranjaAgro = const Color(0xFFF2AE2E);

class RegistroUsuarioPage extends StatefulWidget {
  const RegistroUsuarioPage({super.key});

  @override
  State<RegistroUsuarioPage> createState() => _RegistroUsuarioPageState();
}

class _RegistroUsuarioPageState extends State<RegistroUsuarioPage> {
  int _activeContent = 0;
  final GlobalKey<_RegistroUsuarioFormState> _formStateKey = GlobalKey<_RegistroUsuarioFormState>();

  List<RailItem> _items(BuildContext context) => [
    RailItem(
      icon: Icons.build_outlined,
      tooltip: 'Equipos Pequeños',
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EquiposPequenosPage())),
    ),
    RailItem(
      icon: Icons.agriculture_outlined,
      tooltip: 'Equipos Grandes',
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const EquiposGrandesPage())),
    ),
    RailItem(
      icon: Icons.widgets_outlined,
      tooltip: 'Materiales',
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MaterialesPage())),
    ),
    RailItem(
      icon: Icons.person_add_alt_1_outlined,
      tooltip: 'Registro de usuario',
      onTap: () {}, // aquí
    ),
    RailItem(
      icon: Icons.yard_outlined,
      tooltip: 'Registro de Unidades de Siembra',
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const reg_unidades.RegistroUnidadesSiembraPage()),
      ),
    ),
    RailItem(
      icon: Icons.precision_manufacturing_outlined,
      tooltip: 'Registro de Implementos',
      onTap: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegistroImplementosPage())),
    ),
  ];

  void _switchToEditUser(String uid) {
    setState(() => _activeContent = 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _formStateKey.currentState?.cargarUsuarioParaEditar(uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MiniIconRailScaffold(
      title: 'Gestión de Usuarios',
      items: _items(context),
      currentIndex: 3,
      block: AppBlock.servicios,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Flexible(
                  child: _TopIconTab(
                    selected: _activeContent == 0,
                    icon: Icons.person_add_outlined,
                    label: 'Registrar / Editar',
                    onTap: () => setState(() => _activeContent = 0),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _TopIconTab(
                    selected: _activeContent == 1,
                    icon: Icons.people_outline,
                    label: 'Usuarios Existentes',
                    onTap: () => setState(() => _activeContent = 1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _activeContent == 0
                  ? _RegistroUsuarioForm(key: _formStateKey)
                  : _UsuariosExistentesList(onEdit: _switchToEditUser),
            ),
          ),
        ],
      ),
    );
  }
}

class _RegistroUsuarioForm extends StatefulWidget {
  const _RegistroUsuarioForm({super.key});

  @override
  State<_RegistroUsuarioForm> createState() => _RegistroUsuarioFormState();
}

// ===== MODELO DE PERMISOS =====
enum PermissionLevel { editar, ver, ninguno }

String permissionToString(PermissionLevel p) {
  switch (p) {
    case PermissionLevel.editar:
      return 'editar';
    case PermissionLevel.ver:
      return 'ver';
    case PermissionLevel.ninguno:
      return 'ninguno';
  }
}

PermissionLevel permissionFromString(String? s) {
  switch (s) {
    case 'editar':
      return PermissionLevel.editar;
    case 'ver':
      return PermissionLevel.ver;
    case 'ninguno':
    default:
      return PermissionLevel.ninguno;
  }
}

class _PermissionItem {
  final String id;
  final String label;
  final IconData icon;
  const _PermissionItem(this.id, this.label, this.icon);
}

class _PermissionGroup {
  final _PermissionItem item;
  final List<_PermissionItem> subItems;
  const _PermissionGroup({required this.item, this.subItems = const []});
}

class _RegistroUsuarioFormState extends State<_RegistroUsuarioForm> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();

  final _nombreCtrl = TextEditingController();
  final _dirCtrl = TextEditingController();
  final _puestoCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscureText = true;
  String _estado = 'activo';

  bool _isLoadingUnidades = true;
  final Map<String, String> _unidadesDisponibles = {};
  final Map<String, bool> _unidadesSeleccionadas = {};

  /// Menús principales (sin submenús), EXCEPTO Servicios Internos que va en grupo (ver orden más abajo).
  /// IMPORTANTE: Reemplazado `fertilizacion_especializada` por `actividades_especializadas`
  /// y agregado `dashboard_ae`.
  final Map<String, _PermissionItem> _principalById = const {
    'dashboard_general': _PermissionItem('dashboard_general', 'Dashboard General', Icons.dashboard_outlined),
    'dashboard_pei': _PermissionItem('dashboard_pei', 'Dashboard P.e.I', Icons.analytics_outlined),
    'dashboard_cei': _PermissionItem('dashboard_cei', 'Dashboard C.e.I', Icons.insights_outlined),
    'dashboard_ae': _PermissionItem('dashboard_ae', 'Dashboard A.E', Icons.dashboard_customize_rounded), // NUEVO
    'produccion_investigacion': _PermissionItem('produccion_investigacion', 'Producción e Investigación', Icons.biotech_outlined),
    'calidad_inocuidad': _PermissionItem('calidad_inocuidad', 'Calidad e Inocuidad', Icons.verified_outlined),
    'actividades_especializadas': _PermissionItem('actividades_especializadas', 'Actividades Especializadas', Icons.science_outlined), // NUEVO ID
    'riego': _PermissionItem('riego', 'Riego', Icons.water_drop_outlined),
    'servicio_dron': _PermissionItem('servicio_dron', 'Servicio de DRON', Icons.flight_takeoff),
    'planeacion': _PermissionItem('planeacion', 'Planeación', Icons.calendar_month_outlined),
  };

  /// Grupo con submenús SOLO para Servicios Internos
  final _PermissionGroup _grupoServiciosInternos = const _PermissionGroup(
    item: _PermissionItem('servicios_internos', 'Servicios Internos', Icons.home_repair_service_outlined),
    subItems: [
      _PermissionItem('servicios_internos/equipos_pequenos', 'Equipos Pequeños', Icons.build_outlined),
      _PermissionItem('servicios_internos/equipos_grandes', 'Equipos Grandes', Icons.agriculture_outlined),
      _PermissionItem('servicios_internos/materiales', 'Materiales', Icons.widgets_outlined),
      _PermissionItem('servicios_internos/registro_usuario', 'Registro de Usuario', Icons.person_add_alt_1_outlined),
      _PermissionItem('servicios_internos/registro_unidades', 'Registro de Unidades de Siembra', Icons.yard_outlined),
      _PermissionItem('servicios_internos/registro_implementos', 'Registro de Implementos', Icons.precision_manufacturing_outlined),
    ],
  );

  /// ORDEN EXACTO SOLICITADO (incluye dashboard_ae y reemplaza fertilizacion_especializada → actividades_especializadas)
  final List<String> _ordenPermisos = const [
    'dashboard_general',
    'dashboard_pei',
    'dashboard_cei',
    'dashboard_ae',                 // NUEVO
    'produccion_investigacion',
    'calidad_inocuidad',
    'actividades_especializadas',   // NUEVO ID
    'riego',
    'servicios_internos',
    'planeacion',
    'servicio_dron',
  ];

  final Map<String, PermissionLevel> _permisosSeleccionados = {};
  bool _isEditing = false;
  String? _editingUserId;

  @override
  void initState() {
    super.initState();
    _limpiarFormulario(inicial: true);
    _cargarUnidadesDisponibles();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _dirCtrl.dispose();
    _puestoCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _cargarUnidadesDisponibles() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('unidades_catalog').get();
      final Map<String, String> unidadesCargadas = {};
      for (var doc in snapshot.docs) {
        final nombre = doc.data()['nombre'] as String? ?? doc.id;
        unidadesCargadas[doc.id] = nombre;
      }
      if (mounted) {
        setState(() {
          _unidadesDisponibles
            ..clear()
            ..addAll(unidadesCargadas);
          _unidadesDisponibles.keys.forEach((key) {
            _unidadesSeleccionadas[key] = false;
          });
        });
      }
    } catch (e) {
      debugPrint('Error al cargar unidades desde el catálogo: $e');
    } finally {
      if (mounted) setState(() => _isLoadingUnidades = false);
    }
  }

  Future<void> cargarUsuarioParaEditar(String uid) async {
    _limpiarFormulario();
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (doc.exists && mounted) {
        final data = doc.data()!;

        setState(() {
          _isEditing = true;
          _editingUserId = uid;

          _nombreCtrl.text = data['nombre'] ?? '';
          _dirCtrl.text = data['direccion'] ?? '';
          _puestoCtrl.text = data['puesto'] ?? '';
          _emailCtrl.text = data['email'] ?? '';
          _estado = data['estado'] ?? 'activo';

          final List<String> unidadesAuth = List<String>.from(data['unidadesAutorizadas'] ?? []);
          _unidadesSeleccionadas.clear();
          for (var key in _unidadesDisponibles.keys) {
            _unidadesSeleccionadas[key] = unidadesAuth.contains(key);
          }

          final Map<String, dynamic> permisosGuardados = data['permisos'] ?? {};
          // principales
          _principalById.forEach((id, item) {
            _permisosSeleccionados[id] = permissionFromString(permisosGuardados[id] as String?);
          });
          // grupo servicios (padre + submenús)
          _permisosSeleccionados[_grupoServiciosInternos.item.id] =
              permissionFromString(permisosGuardados[_grupoServiciosInternos.item.id] as String?);
          for (var sub in _grupoServiciosInternos.subItems) {
            _permisosSeleccionados[sub.id] = permissionFromString(permisosGuardados[sub.id] as String?);
          }
        });

        _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cargado para edición: ${data['nombre']}'), backgroundColor: Colors.blueGrey),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar usuario: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _guardarUsuario() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final nombre = _nombreCtrl.text.trim();
    final direccion = _dirCtrl.text.trim();
    final puesto = _puestoCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();
    final estado = _estado;

    final List<String> unidadesAsignadas = _unidadesSeleccionadas.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final permisosToSave = <String, String>{};
    _permisosSeleccionados.forEach((key, value) {
      permisosToSave[key] = permissionToString(value);
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (_isEditing) {
        await FirebaseFirestore.instance.collection('users').doc(_editingUserId!).update({
          'nombre': nombre,
          'direccion': direccion,
          'puesto': puesto,
          'estado': estado,
          'unidadesAutorizadas': unidadesAsignadas,
          'permisos': permisosToSave,
        });

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado exitosamente.'), backgroundColor: Colors.green),
        );
        _limpiarFormulario();
      } else {
        final userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
        final newUser = userCredential.user;
        if (newUser == null) throw Exception("No se pudo crear el usuario.");

        await FirebaseFirestore.instance.collection('users').doc(newUser.uid).set({
          'uid': newUser.uid,
          'nombre': nombre,
          'direccion': direccion,
          'puesto': puesto,
          'email': email,
          'estado': estado,
          'unidadesAutorizadas': unidadesAsignadas,
          'permisos': permisosToSave,
          'role': 'user',
          'createdAt': FieldValue.serverTimestamp(),
        });

        try {
          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
        } catch (e) {
          debugPrint('Error al enviar correo de configuración: $e');
        }

        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Usuario registrado. Se envió un correo para configurar la contraseña.'),
              backgroundColor: Colors.green),
        );
        _limpiarFormulario();
      }
    } on FirebaseAuthException catch (e) {
      Navigator.of(context).pop();
      String errorMsg = "Ocurrió un error.";
      if (e.code == 'weak-password') errorMsg = 'La contraseña es muy débil.';
      if (e.code == 'email-already-in-use') errorMsg = 'El correo electrónico ya está en uso.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: Colors.red),
      );
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _limpiarFormulario({bool inicial = false}) {
    if (!inicial) _formKey.currentState?.reset();
    _nombreCtrl.clear();
    _dirCtrl.clear();
    _puestoCtrl.clear();
    _emailCtrl.clear();
    _passCtrl.clear();
    setState(() {
      _isEditing = false;
      _editingUserId = null;
      _estado = 'activo';

      _unidadesSeleccionadas.updateAll((key, value) => false);

      _principalById.forEach((id, _) {
        _permisosSeleccionados[id] = PermissionLevel.ninguno;
      });
      _permisosSeleccionados[_grupoServiciosInternos.item.id] = PermissionLevel.ninguno;
      for (var sub in _grupoServiciosInternos.subItems) {
        _permisosSeleccionados[sub.id] = PermissionLevel.ninguno;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return SingleChildScrollView(
      controller: _scrollController,
      key: const ValueKey('form'),
      padding: const EdgeInsets.all(12.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isEditing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Editando a: ${_nombreCtrl.text}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline),
                      label: const Text('Registrar Nuevo'),
                      onPressed: () => _limpiarFormulario(),
                    ),
                  ],
                ),
              ),

            _buildSectionHeader('Datos Personales', Icons.person_outline),
            TextFormField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre Completo'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _dirCtrl, decoration: const InputDecoration(labelText: 'Dirección (Opcional)')),
            const SizedBox(height: 12),
            TextFormField(controller: _puestoCtrl, decoration: const InputDecoration(labelText: 'Puesto / Rol')),

            const SizedBox(height: 24),
            _buildSectionHeader('Credenciales de Acceso', Icons.lock_outline),
            TextFormField(
              controller: _emailCtrl,
              decoration: InputDecoration(labelText: 'Correo Electrónico', enabled: !_isEditing),
              keyboardType: TextInputType.emailAddress,
              readOnly: _isEditing,
              validator: (v) => v!.isEmpty || !v.contains('@') ? 'Correo inválido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'Contraseña Temporal',
                enabled: !_isEditing,
                hintText: _isEditing ? 'No se puede cambiar aquí' : 'Mín. 6 caracteres',
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
              ),
              readOnly: _isEditing,
              validator: (v) => !_isEditing && v!.length < 6 ? 'Mínimo 6 caracteres' : null,
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Estado de la Cuenta', Icons.toggle_on_outlined),
            DropdownButtonFormField<String>(
              value: _estado,
              items: const [
                DropdownMenuItem(value: 'activo', child: Text('Activo')),
                DropdownMenuItem(value: 'inactivo', child: Text('Inactivo'))
              ],
              onChanged: (val) => setState(() => _estado = val!),
              decoration: const InputDecoration(labelText: 'Estado'),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Asignación de Unidades de Siembra', Icons.yard_outlined),
            _isLoadingUnidades
                ? const Center(child: CircularProgressIndicator())
                : _unidadesDisponibles.isEmpty
                ? const Text('No hay unidades de siembra para asignar.')
                : Column(
              children: _unidadesDisponibles.entries.map((entry) {
                final unitId = entry.key;
                final unitName = entry.value;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _unidadesSeleccionadas[unitId] = !(_unidadesSeleccionadas[unitId] ?? false);
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _unidadesSeleccionadas[unitId] ?? false,
                          onChanged: (val) {
                            setState(() {
                              _unidadesSeleccionadas[unitId] = val!;
                            });
                          },
                        ),
                        Expanded(child: Text(unitName, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),
            _buildSectionHeader('Permiso de Acceso a Módulos', Icons.rule_folder_outlined),
            const SizedBox(height: 6),
            const _WLegendChips(),
            const SizedBox(height: 6),

            // ORDEN EXACTO
            ..._ordenPermisos.map((id) {
              if (id == 'servicios_internos') {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      leading: Icon(_grupoServiciosInternos.item.icon, color: onSurface),
                      title: Text(
                        _grupoServiciosInternos.item.label,
                        style: TextStyle(fontWeight: FontWeight.bold, color: onSurface),
                      ),
                      trailing: _buildGroupTrailing(_grupoServiciosInternos),
                      childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      children: [
                        const Divider(height: 10),
                        ..._grupoServiciosInternos.subItems.map((sub) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _buildPermissionSelector(sub),
                        )),
                      ],
                    ),
                  ),
                );
              } else {
                final item = _principalById[id]!;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: _buildPermissionSelector(item),
                  ),
                );
              }
            }),

            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _guardarUsuario,
              icon: Icon(_isEditing ? Icons.save : Icons.person_add),
              label: Text(_isEditing ? 'Actualizar Usuario' : 'Registrar Usuario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorNaranjaAgro,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionSelector(_PermissionItem item) {
    final value = _permisosSeleccionados[item.id] ?? PermissionLevel.ninguno;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;

        final titleRow = Row(
          children: [
            Icon(item.icon, size: 18, color: Colors.grey[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                item.label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );

        final dropdown = DropdownButtonFormField<PermissionLevel>(
          value: value,
          items: const [
            DropdownMenuItem(
              value: PermissionLevel.editar,
              child: _WMenuOption(icon: Icons.edit_outlined, text: 'Acceso Total'),
            ),
            DropdownMenuItem(
              value: PermissionLevel.ver,
              child: _WMenuOption(icon: Icons.visibility_outlined, text: 'Solo Ver'),
            ),
            DropdownMenuItem(
              value: PermissionLevel.ninguno,
              child: _WMenuOption(icon: Icons.block_outlined, text: 'Sin Acceso'),
            ),
          ],
          onChanged: (val) => setState(() => _permisosSeleccionados[item.id] = val ?? PermissionLevel.ninguno),
          decoration: InputDecoration(
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
          ),
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              const SizedBox(height: 8),
              dropdown,
            ],
          );
        } else {
          return Row(
            children: [
              Expanded(child: titleRow),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: dropdown,
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildGroupTrailing(_PermissionGroup group) {
    final current = _permisosSeleccionados[group.item.id] ?? PermissionLevel.ninguno;

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;

        final groupDropdown = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: DropdownButtonFormField<PermissionLevel>(
            value: current,
            items: const [
              DropdownMenuItem(
                value: PermissionLevel.editar,
                child: _WMenuOption(icon: Icons.edit_outlined, text: 'Acceso Total'),
              ),
              DropdownMenuItem(
                value: PermissionLevel.ver,
                child: _WMenuOption(icon: Icons.visibility_outlined, text: 'Solo Ver'),
              ),
              DropdownMenuItem(
                value: PermissionLevel.ninguno,
                child: _WMenuOption(icon: Icons.block_outlined, text: 'Sin Acceso'),
              ),
            ],
            onChanged: (val) => setState(() {
              final chosen = val ?? PermissionLevel.ninguno;
              _permisosSeleccionados[group.item.id] = chosen;
            }),
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        );

        final applyAllBtn = Tooltip(
          message: 'Aplicar el nivel del grupo a todos los submenús',
          child: IconButton(
            icon: const Icon(Icons.auto_mode_outlined),
            onPressed: () {
              final lvl = _permisosSeleccionados[group.item.id] ?? PermissionLevel.ninguno;
              setState(() {
                for (var sub in group.subItems) {
                  _permisosSeleccionados[sub.id] = lvl;
                }
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Aplicado "${_labelForLevel(lvl)}" a submenús de "${group.item.label}".'),
                  backgroundColor: Colors.blueGrey,
                ),
              );
            },
          ),
        );

        if (narrow) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(width: 180, child: groupDropdown),
              applyAllBtn,
            ],
          );
        } else {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              groupDropdown,
              const SizedBox(width: 8),
              applyAllBtn,
            ],
          );
        }
      },
    );
  }

  String _labelForLevel(PermissionLevel lvl) {
    switch (lvl) {
      case PermissionLevel.editar:
        return 'Acceso Total';
      case PermissionLevel.ver:
        return 'Solo Ver';
      case PermissionLevel.ninguno:
        return 'Sin Acceso';
    }
  }
}

class _WMenuOption extends StatelessWidget {
  final IconData icon;
  final String text;
  const _WMenuOption({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}

class _WLegendChips extends StatelessWidget {
  const _WLegendChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: const [
        Chip(avatar: Icon(Icons.edit_outlined, size: 16), label: Text('Acceso Total')),
        Chip(avatar: Icon(Icons.visibility_outlined, size: 16), label: Text('Solo Ver')),
        Chip(avatar: Icon(Icons.block_outlined, size: 16), label: Text('Sin Acceso')),
      ],
    );
  }
}

class _UsuariosExistentesList extends StatelessWidget {
  final Function(String) onEdit;
  const _UsuariosExistentesList({required this.onEdit});

  int _rank(String? role) {
    switch ((role ?? 'user').toLowerCase()) {
      case 'owner':
        return 3;
      case 'admin':
      case 'manager':
      case 'supervisor':
        return 2;
      default:
        return 1;
    }
  }

  Future<Map<String, dynamic>?> _getCurrentUserData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Correo de reseteo enviado a $email'), backgroundColor: Colors.green),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar correo: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteUser(BuildContext context, String uid, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: Text('¿Seguro que deseas eliminar a "$nombre"? Esta acción es irreversible y eliminará sus datos de Firestore (no de Authentication).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Usuario "$nombre" eliminado de Firestore.'), backgroundColor: Colors.green),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _getCurrentUserData(),
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final me = userSnap.data ?? {};
        final myRole = (me['role'] as String?) ?? 'user';
        final myRank = _rank(myRole);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance.collection('users').orderBy('nombre').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            final all = snapshot.data?.docs ?? [];

            final users = all.where((doc) {
              final data = doc.data();
              final role = (data['role'] as String?) ?? 'user';
              return _rank(role) <= myRank;
            }).toList();

            if (users.isEmpty) {
              return const Center(child: Text('No hay usuarios visibles para tu rol.'));
            }

            return ListView.builder(
              key: const ValueKey('list'),
              padding: const EdgeInsets.all(12.0),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final userDoc = users[index];
                final data = userDoc.data();
                final uid = userDoc.id;
                final nombre = data['nombre'] ?? 'Sin nombre';
                final email = data['email'] ?? 'Sin email';
                final puesto = data['puesto'] ?? 'Sin puesto';
                final estado = data['estado'] ?? 'indefinido';
                final role = (data['role'] as String?) ?? 'user';
                final unidades = List<String>.from(data['unidadesAutorizadas'] ?? []);

                final canEdit = _rank(role) <= myRank;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: estado == 'activo' ? Colors.green : Colors.grey,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('$puesto  •  Rol: $role', style: const TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'edit' && canEdit) {
                                  onEdit(uid);
                                } else if (value == 'delete' && canEdit) {
                                  _deleteUser(context, uid, nombre);
                                } else if (value == 'reset_pass' && canEdit) {
                                  _resetPassword(context, email);
                                }
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'reset_pass', child: Text('Resetear Contraseña')),
                                const PopupMenuItem(value: 'edit', child: Text('Editar')),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                              enabled: canEdit,
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        _buildInfoRow(Icons.email_outlined, email),
                        _buildInfoRow(Icons.vpn_key_outlined, 'Contraseña: ••••••••'),
                        _buildInfoRow(Icons.toggle_on_outlined, 'Estado: $estado',
                            color: estado == 'activo' ? Colors.green : Colors.red),
                        _buildInfoRow(Icons.yard_outlined,
                            'Unidades: ${unidades.isEmpty ? "Ninguna" : unidades.join(', ')}'),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: color))),
        ],
      ),
    );
  }
}

class _TopIconTab extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _TopIconTab({required this.selected, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = selected ? colorNaranjaAgro.withOpacity(0.20) : Colors.transparent;
    final border = selected ? colorNaranjaAgro.withOpacity(0.40) : Colors.transparent;
    final defaultIconAndTextColor =
    theme.brightness == Brightness.dark ? Colors.white70 : (theme.iconTheme.color ?? Colors.black54);
    final iconAndTextColor = selected ? colorNaranjaAgro : defaultIconAndTextColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: iconAndTextColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(fontWeight: selected ? FontWeight.w700 : FontWeight.w500, color: iconAndTextColor),
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
