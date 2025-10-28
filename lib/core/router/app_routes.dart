class AppRoutes {
  static const reporteLaboreoProfundo = '/reporte/laboreo_profundo';
  static const reporteLaboreoSuperficial = '/reporte/laboreo_superficial';
}

class LaboreoProfundoArgs {
  final String uid;
  final String unidadId;
  final String? decisionFuente; // "amarillo_usuario" | "rojo_auto" | null
  final String? decisionDocId;

  const LaboreoProfundoArgs({
    required this.uid,
    required this.unidadId,
    this.decisionFuente,
    this.decisionDocId,
  });
}

class LaboreoSuperficialArgs {
  final String uid;
  final String unidadId;
  final List<String> actividades; // ["rastra"], ["desterronador"] o ambas
  final String? actividadDocId;

  const LaboreoSuperficialArgs({
    required this.uid,
    required this.unidadId,
    required this.actividades,
    this.actividadDocId,
  });
}
