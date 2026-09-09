import 'package:flutter/material.dart';
import '../../../core/models/folder.dart';
import '../../../core/services/folder_service.dart';

class FolderPickerScreen extends StatefulWidget {
  final int? initialFolderId;
  const FolderPickerScreen({super.key, this.initialFolderId});

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  final _service = FolderService();
  final _path = <Folder>[];
  List<Folder> _children = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      var id = widget.initialFolderId;
      final visited = <int>{};
      while (id != null && visited.add(id)) {
        final folder = await _service.getById(id);
        if (folder == null) break;
        _path.insert(0, folder);
        id = folder.parentId;
      }
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de charger les dossiers.';
        });
      }
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final folders = _path.isEmpty
          ? await _service.getRootFolders()
          : await _service.getSubFolders(_path.last.id!);
      if (mounted) setState(() => _children = folders);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Impossible de charger les dossiers.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _FolderNameDialog(isSubfolder: _path.isNotEmpty),
    );
    if (name == null || !mounted) return;
    setState(() => _loading = true);
    try {
      final folder = await _service.create(
        name,
        parentId: _path.lastOrNull?.id,
      );
      if (!mounted) return;
      _path.add(folder);
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossible de créer ce dossier.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Choisir un dossier'),
      actions: [
        IconButton(
          onPressed: _loading ? null : _create,
          tooltip: 'Créer un dossier ici',
          icon: const Icon(Icons.create_new_folder_outlined),
        ),
      ],
    ),
    body: Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        _path.clear();
                        _load();
                      },
                child: const Text('Tous les dossiers'),
              ),
              for (var i = 0; i < _path.length; i++) ...[
                const Icon(Icons.chevron_right, size: 18),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _path.removeRange(i + 1, _path.length);
                          _load();
                        },
                  child: Text(_path[i].name),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!),
                      TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                )
              : _children.isEmpty
              ? const Center(
                  child: Text('Aucun sous-dossier. Tu peux en créer un ici.'),
                )
              : ListView.builder(
                  itemCount: _children.length,
                  itemBuilder: (_, index) {
                    final folder = _children[index];
                    return ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(folder.name),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _path.add(folder);
                        _load();
                      },
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _loading || _error != null || _path.isEmpty
                    ? null
                    : () => Navigator.pop(context, _path.last),
                icon: const Icon(Icons.check),
                label: Text(
                  _path.isEmpty
                      ? 'Ouvre ou crée un dossier'
                      : 'Classer dans « ${_path.last.name} »',
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _FolderNameDialog extends StatefulWidget {
  final bool isSubfolder;
  const _FolderNameDialog({required this.isSubfolder});
  @override
  State<_FolderNameDialog> createState() => _FolderNameDialogState();
}

class _FolderNameDialogState extends State<_FolderNameDialog> {
  final _controller = TextEditingController();
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isNotEmpty) Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.isSubfolder ? 'Nouveau sous-dossier' : 'Nouveau dossier',
    ),
    content: TextField(
      controller: _controller,
      autofocus: true,
      decoration: const InputDecoration(labelText: 'Nom du dossier'),
      onSubmitted: (_) => _submit(),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Créer')),
    ],
  );
}
