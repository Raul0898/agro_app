enum AppRole { directorGeneral, directorProduccion, directorCalidad }

String roleToString(AppRole r) => switch (r) {
  AppRole.directorGeneral => 'DIRECTOR_GENERAL',
  AppRole.directorProduccion => 'DIRECTOR_PRODUCCION',
  AppRole.directorCalidad => 'DIRECTOR_CALIDAD',
};

AppRole? roleFromString(String? raw) {
  switch (raw) {
    case 'DIRECTOR_GENERAL': return AppRole.directorGeneral;
    case 'DIRECTOR_PRODUCCION': return AppRole.directorProduccion;
    case 'DIRECTOR_CALIDAD': return AppRole.directorCalidad;
  }
  return null;
}

extension AppRoleLabel on AppRole {
  String get label => switch (this) {
    AppRole.directorGeneral => 'Director General',
    AppRole.directorProduccion => 'Director de Producción e Investigación',
    AppRole.directorCalidad => 'Director de Calidad e Inocuidad',
  };
}
