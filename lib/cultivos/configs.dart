// lib/cultivos/configs.dart

/// Definición de un menú (o sección) dentro de un cultivo.
/// NOTA: `items` son simples Strings (p.ej. "Barbecho", "Rastra").
/// No hay objetos con `id`/`title` para submenús; usa el texto directamente.
class MenuDef {
  final String id;            // clave estable (p.ej. 'analisis_suelo')
  final String title;         // texto visible (p.ej. 'Análisis de suelo')
  final List<String> items;   // sub-opciones si aplica (texto plano)

  const MenuDef({
    required this.id,
    required this.title,
    this.items = const [],
  });
}

/// Config básica por cultivo.
class CultivoConfig {
  final String nombre;              // nombre visible del cultivo
  final List<MenuDef> defaultMenus; // menús por defecto (con id/title/items)

  const CultivoConfig({
    required this.nombre,
    required this.defaultMenus,
  });
}

/// Config del cultivo Maíz (usada en varias pantallas como `maizConfig`)
const CultivoConfig maizConfig = CultivoConfig(
  nombre: 'Maíz',
  defaultMenus: <MenuDef>[
    MenuDef(
      id: 'analisis_suelo',
      title: 'Análisis de suelo',
      items: <String>[
        'pH', 'Materia orgánica', 'Nitrógeno', 'Fósforo', 'Potasio',
      ],
    ),
    MenuDef(
      id: 'preparacion_suelos',
      title: 'Preparación de suelos',
      items: <String>[
        'Barbecho', 'Rastra', 'Nivelación',
      ],
    ),
    MenuDef(
      id: 'siembra',
      title: 'Siembra',
      items: <String>[
        'Densidad', 'Variedad', 'Fecha de siembra',
      ],
    ),
    MenuDef(
      id: 'riegos',
      title: 'Riegos',
      items: <String>[
        'Riego 0', 'Riego auxilio', 'Riego post-siembra',
      ],
    ),
    MenuDef(
      id: 'fertilizacion',
      title: 'Fertilización',
      items: <String>[
        'Arranque', 'Cobertura', 'Foliar',
      ],
    ),
    MenuDef(
      id: 'malezas',
      title: 'Control de malezas',
      items: <String>[
        'Preemergente', 'Posemergente',
      ],
    ),
    MenuDef(
      id: 'plagas',
      title: 'Control de plagas',
      items: <String>[
        'Gusano cogollero', 'Pulgones',
      ],
    ),
    MenuDef(
      id: 'cosecha',
      title: 'Cosecha',
      items: <String>[
        'Humedad de grano', 'Rendimiento',
      ],
    ),
  ],
);

/// Si luego agregas más cultivos, centralízalos aquí.
const Map<String, CultivoConfig> cultivosDisponibles = {
  'maiz': maizConfig,
  // 'cacahuate': cacahuateConfig,
  // 'sorgo': sorgoConfig,
};