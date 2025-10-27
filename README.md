# agro_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Firestore

Para resolver el error "Missing or insufficient permissions"/"The query requires an index" que aparece al filtrar los repositorios de Análisis y Reportes, se agregó `firestore.indexes.json` con los índices compuestos necesarios.

### Deploy manual

1. Autenticarse en Firebase (`firebase login`).
2. Seleccionar el proyecto (`firebase use agro-app-demo`).
3. Desplegar únicamente los índices: `firebase deploy --only firestore:indexes`.
4. Verificar en la consola de Firebase > Firestore Database > Indexes que aparezcan las combinaciones de `unidad`, `seccion` y `fecha`.
5. Abrir la app y repetir la búsqueda que fallaba. Tomar una captura donde se observe el listado cargado correctamente y adjuntarla en el reporte.

Los cambios en la app consumen directamente las nuevas combinaciones, por lo que no se requieren ajustes adicionales de código.
