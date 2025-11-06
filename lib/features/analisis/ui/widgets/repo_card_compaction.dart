import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RepoItem {
  final String titulo;
  final DateTime? fecha;
  final String? storagePath;
  final String color;
  final String texto;

  const RepoItem({
    required this.titulo,
    this.fecha,
    this.storagePath,
    required this.color,
    required this.texto,
  });
}

class RepoCardCompaction extends StatelessWidget {
  const RepoCardCompaction({
    super.key,
    required this.item,
    required this.onPreview,
    required this.onDownload,
    this.onDelete,
    this.showDelete = true,
    this.showTexto = true,
    this.padding = EdgeInsets.zero,
  });

  final RepoItem item;
  final VoidCallback? onPreview;
  final VoidCallback? onDownload;
  final VoidCallback? onDelete;
  final bool showDelete;
  final bool showTexto;
  final EdgeInsetsGeometry padding;

  Color _chipColor(String value) {
    switch (value) {
      case 'rojo':
        return const Color(0xFFC62828);
      case 'amarillo':
        return const Color(0xFFF9A825);
      case 'verde':
        return const Color(0xFF2E7D32);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normalizedColor = item.color.trim().toLowerCase();
    final chipLabel =
        normalizedColor.isEmpty ? 'DESCONOCIDO' : normalizedColor.toUpperCase();
    final chipColor = _chipColor(normalizedColor);
    final fecha = item.fecha;
    final fechaStr = fecha == null
        ? 'Sin fecha disponible'
        : DateFormat('yyyy-MM-dd HH:mm').format(fecha);
    final texto = item.texto.trim();

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.picture_as_pdf, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Chip(
                label: Text(
                  chipLabel,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: chipColor,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (showTexto && texto.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              texto,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.grey.shade800,
                height: 1.25,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            fechaStr,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Vista previa'),
                onPressed: onPreview,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('Descargar'),
                onPressed: onDownload,
              ),
              if (showDelete && onDelete != null)
                TextButton.icon(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(color: Colors.red),
                  ),
                  onPressed: onDelete,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
