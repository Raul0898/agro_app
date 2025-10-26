// lib/models/unidad_models.dart

/// Modelo simple para capturar la información de una Unidad de Siembra
/// antes de enviarla a Firestore.
class UnidadSiembraInput {
  final String id;                // ej: "Acala"
  final String nombre;            // ej: "Rancho Acala"
  final String direccion;         // texto libre
  final String? ubicacionTexto;   // ej: "Acala, Chiapas"
  final double? superficieHa;     // ej: 120.0
  final String? sistemaRiego;     // "Gravedad" | "Goteo" | "Aspersión" | etc.
  final List<String> cultivos;    // ids de cultivos (ej: ["maiz", "sorgo"])
  final String? notas;

  const UnidadSiembraInput({
    required this.id,
    required this.nombre,
    required this.direccion,
    this.ubicacionTexto,
    this.superficieHa,
    this.sistemaRiego,
    required this.cultivos,
    this.notas,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      if (ubicacionTexto != null && ubicacionTexto!.trim().isNotEmpty)
        'ubicacionTexto': ubicacionTexto!.trim(),
      if (superficieHa != null) 'superficieHa': superficieHa,
      if (sistemaRiego != null && sistemaRiego!.trim().isNotEmpty)
        'sistemaRiego': sistemaRiego!.trim(),
      'cultivos': cultivos,
      if (notas != null && notas!.trim().isNotEmpty) 'notas': notas!.trim(),
    };
  }
}