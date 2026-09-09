import 'package:flutter/material.dart';
import '../../../core/models/folder.dart';
import 'folder_detail_screen.dart';

/// Kept as an entry point; every depth uses the same folder features.
class SubfolderScreen extends StatelessWidget {
  final Folder folder;
  const SubfolderScreen({super.key, required this.folder});

  @override
  Widget build(BuildContext context) => FolderDetailScreen(folder: folder);
}
