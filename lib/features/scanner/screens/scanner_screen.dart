import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/models/document.dart';
import '../../../core/services/scanner_service.dart';
import 'preview_screen.dart';
import 'save_scan_screen.dart';

class ScannerScreen extends StatefulWidget {
  final int? folderId;
  const ScannerScreen({super.key, this.folderId});
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with WidgetsBindingObserver {
  final _service = ScannerService();
  final _pages = <ScannedPage>[];
  CameraController? _camera;
  Future<void> _cameraTask = Future.value();
  bool _active = true;
  bool _away = false;
  bool _busy = false;
  bool _opening = true;
  bool _allowExit = false;
  bool _confirming = false;
  bool _torch = false;
  String? _error;
  int? _retakeIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    _syncCamera();
  }

  /// Serialize opening/disposal, including interruptions during permission prompts.
  Future<void> _syncCamera() {
    _cameraTask = _cameraTask.then((_) async {
      final old = _camera;
      _camera = null;
      if (mounted) {
        setState(() {
          _opening = _active && !_away;
          _torch = false;
        });
      }
      try {
        await old?.dispose();
      } catch (_) {
        /* Device may already be disconnected. */
      }
      if (!mounted || !_active || _away) return;
      CameraController? next;
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw CameraException('NoCamera', 'Aucune caméra disponible.');
        }
        if (!mounted || !_active || _away) return;
        final back = cameras.where(
          (c) => c.lensDirection == CameraLensDirection.back,
        );
        next = CameraController(
          back.isEmpty ? cameras.first : back.first,
          ResolutionPreset.veryHigh,
          enableAudio: false,
        );
        await next.initialize();
        if (!mounted || !_active || _away) {
          await next.dispose();
          return;
        }
        setState(() {
          _camera = next;
          _opening = false;
          _error = null;
        });
      } catch (error) {
        try {
          await next?.dispose();
        } catch (_) {}
        if (mounted) {
          setState(() {
            _opening = false;
            _error = error is CameraException && error.code.contains('Access')
                ? 'Autorise l’accès à la caméra pour scanner tes documents.'
                : 'Impossible de démarrer la caméra. Réessaie.';
          });
        }
      }
    });
    return _cameraTask;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _active = false;
    unawaited(_syncCamera());
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (_busy || camera == null || !camera.value.isInitialized) return;
    setState(() => _busy = true);
    File? file;
    try {
      final photo = await camera.takePicture();
      file = File(photo.path);
      final page = await _service.preparePage(await file.readAsBytes());
      if (!mounted) return;
      final retaken = _retakeIndex;
      setState(() {
        if (retaken == null) {
          _pages.add(page);
        } else {
          _pages[retaken] = page;
        }
        _retakeIndex = null;
      });
      if (retaken != null) {
        setState(() => _busy = false);
        await _preview(retaken);
      }
    } catch (_) {
      _message('La photo n’a pas pu être prise. Réessaie.');
    } finally {
      try {
        if (file != null && await file.exists()) await file.delete();
      } on FileSystemException {
        // The camera cache can be reclaimed by the OS.
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _flash() async {
    final camera = _camera;
    if (camera == null || _busy) return;
    setState(() => _busy = true);
    try {
      final enabled = !_torch;
      await camera.setFlashMode(enabled ? FlashMode.torch : FlashMode.off);
      if (mounted && identical(camera, _camera)) {
        setState(() => _torch = enabled);
      }
    } catch (_) {
      _message('Le flash n’est pas disponible sur cette caméra.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _preview([int index = 0]) async {
    if (_pages.isEmpty || _busy || _away) return;
    setState(() {
      _away = true;
      _retakeIndex = null;
    });
    await _syncCamera();
    if (!mounted) return;
    final result = await Navigator.push<PreviewResult>(
      context,
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          pages: List.from(_pages),
          initialIndex: index,
          onPagesUpdated: (pages) {
            if (mounted) {
              setState(() {
                _pages.clear();
                _pages.addAll(pages);
              });
            }
          },
        ),
      ),
    );
    if (!mounted) return;
    if (result?.action == PreviewAction.save) {
      final document = await Navigator.push<Document>(
        context,
        MaterialPageRoute(
          builder: (_) => SaveScanScreen(
            pages: List.from(_pages),
            initialFolderId: widget.folderId,
          ),
        ),
      );
      if (!mounted) return;
      if (document != null) {
        _message('« ${document.name} » a été enregistré.');
        await _exit(document);
        return;
      }
    } else if (result?.action == PreviewAction.retake) {
      _retakeIndex = result!.index;
    }
    setState(() => _away = false);
    await _syncCamera();
  }

  Future<void> _exit([Document? document]) async {
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, document);
  }

  Future<void> _requestExit() async {
    if (_busy || _away || _confirming) return;
    if (_pages.isEmpty) {
      await _exit();
      return;
    }
    _confirming = true;
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le scan ?'),
        content: const Text('Les pages non enregistrées seront perdues.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuer le scan'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Abandonner'),
          ),
        ],
      ),
    );
    _confirming = false;
    if (discard == true && mounted) await _exit();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final camera = _camera;
    return PopScope(
      canPop: _allowExit,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _requestExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Scanner · ${_pages.length} page(s)'),
          leading: IconButton(
            onPressed: _busy ? null : _requestExit,
            icon: const Icon(Icons.arrow_back),
          ),
          actions: [
            IconButton(
              onPressed: camera == null || _busy ? null : _flash,
              tooltip: 'Flash',
              icon: Icon(_torch ? Icons.flash_on : Icons.flash_off),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: _opening
                      ? const CircularProgressIndicator()
                      : camera != null && camera.value.isInitialized
                      ? CameraPreview(camera)
                      : Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _error ?? 'Caméra en pause',
                                style: TextStyle(color: theme.colorScheme.onSurface),
                                textAlign: TextAlign.center,
                              ),
                              TextButton(
                                onPressed: _syncCamera,
                                child: const Text('Réessayer'),
                              ),
                              TextButton(
                                onPressed: openAppSettings,
                                child: const Text('Ouvrir les paramètres'),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
              if (_retakeIndex != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Reprendre la page ${_retakeIndex! + 1}',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() => _retakeIndex = null),
                      child: const Text('Annuler'),
                    ),
                  ],
                ),
              if (_pages.isNotEmpty)
                SizedBox(
                  height: 80,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => InkWell(
                      onTap: _busy ? null : () => _preview(i),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Image.memory(
                          _pages[i].effectiveBytes,
                          cacheWidth: 180,
                          width: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton(
                      heroTag: 'capture',
                      onPressed: _busy || camera == null ? null : _capture,
                      tooltip: 'Photographier la page',
                      child: _busy
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.camera_alt),
                    ),
                    FilledButton.icon(
                      onPressed: _busy || _pages.isEmpty ? null : _preview,
                      icon: const Icon(Icons.check),
                      label: const Text('Voir les pages'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
