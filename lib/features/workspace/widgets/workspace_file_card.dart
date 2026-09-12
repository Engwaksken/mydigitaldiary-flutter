import 'package:flutter/material.dart';
import '../models/workspace_models.dart';

class WorkspaceFileCard extends StatelessWidget {
  final WorkspaceFile file;
  final VoidCallback? onDownload;

  const WorkspaceFileCard({
    super.key,
    required this.file,
    this.onDownload,
  });

  IconData get _icon {
    final mime = file.mimeType.toLowerCase();

    if (mime.startsWith('image/')) return Icons.image_outlined;
    if (mime.contains('pdf')) return Icons.picture_as_pdf_outlined;
    if (mime.contains('word')) return Icons.description_outlined;
    if (mime.contains('sheet') || mime.contains('excel')) {
      return Icons.table_chart_outlined;
    }
    if (mime.contains('presentation') || mime.contains('powerpoint')) {
      return Icons.slideshow_outlined;
    }

    return Icons.insert_drive_file_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onDownload,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF00897B).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _icon,
                  color: const Color(0xFF00897B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        file.humanSize,
                        if ((file.uploaderName ?? '').trim().isNotEmpty)
                          file.uploaderName!,
                      ].join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (onDownload != null)
                IconButton(
                  tooltip: 'Download',
                  onPressed: onDownload,
                  icon: const Icon(Icons.download_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
