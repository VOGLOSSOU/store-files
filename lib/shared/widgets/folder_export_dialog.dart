import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../core/models/folder.dart';
import '../../core/services/folder_export_service.dart';

Future<void> showFolderExportDialog(BuildContext context, Folder folder) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _FolderExportDialog(folder: folder),
  );
}

class _FolderExportDialog extends StatefulWidget {
  const _FolderExportDialog({required this.folder});

  final Folder folder;

  @override
  State<_FolderExportDialog> createState() => _FolderExportDialogState();
}

class _FolderExportDialogState extends State<_FolderExportDialog> {
  File? _archive;
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _export();
  }

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final archive = await FolderExportService().exportZip(widget.folder.id!);
      if (!mounted) return;
      setState(() {
        _archive = archive;
        _busy = false;
      });
      await _share();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is FormatException
            ? error.message
            : 'Impossible de créer le ZIP. Vérifie l’espace disponible et réessaie.';
      });
    }
  }

  Future<void> _share() async {
    final archive = _archive;
    if (archive == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (!await archive.exists()) {
        if (mounted) {
          setState(() {
            _archive = null;
            _error = 'L’archive temporaire n’est plus disponible. Réessaie pour la recréer.';
          });
        }
        return;
      }
      if (!mounted) return;
      final renderObject = context.findRenderObject();
      final origin = renderObject is RenderBox && renderObject.hasSize
          ? renderObject.localToGlobal(Offset.zero) & renderObject.size
          : null;
      final result = await SharePlus.instance.share(
        ShareParams(
          files: [XFile(archive.path, mimeType: 'application/zip')],
          title: p.basename(archive.path),
          sharePositionOrigin: origin,
        ),
      );
      if (mounted && result.status == ShareResultStatus.unavailable) {
        setState(() {
          _error = 'Le résultat du partage n’est pas disponible. Vérifie dans l’application destinataire que le ZIP a bien été reçu.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Le partage n’a pas pu s’ouvrir. Tu peux réessayer.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: const Text('Exporter en ZIP'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.folder.name),
              const SizedBox(height: 16),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(_archive == null
                    ? 'Création de l’archive avec les documents et sous-dossiers…'
                    : 'Ouverture du partage…'),
              ] else if (_archive != null) ...[
                const Text('Ton archive est prête.'),
                const SizedBox(height: 8),
                const Text(
                  'Partage-la ou choisis une application de fichiers dans le menu de partage pour la conserver.',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
          if (!_busy)
            FilledButton.icon(
              onPressed: _archive == null ? _export : _share,
              icon: Icon(_archive == null ? Icons.refresh : Icons.share_outlined),
              label: Text(_archive == null ? 'Réessayer' : 'Partager le ZIP'),
            ),
        ],
      ),
    );
  }
}
