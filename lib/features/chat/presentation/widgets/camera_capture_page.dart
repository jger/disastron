// SPDX-License-Identifier: MIT
// Copyright (c) 2024-2026 Jannis Gerardis

import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Full-screen in-app capture that pops the taken photo's bytes.
///
/// Deliberately does not use `image_picker`'s `ImageSource.camera`: that fires
/// `MediaStore.ACTION_IMAGE_CAPTURE`, which backgrounds this app while a loaded
/// multimodal model keeps it multi-GB resident. Android reliably kills the
/// cached process before the intent returns. Capturing in-process never
/// backgrounds us, so there is nothing for the low-memory killer to reap.
class CameraCapturePage extends StatefulWidget {
  const CameraCapturePage({super.key});

  @override
  State<CameraCapturePage> createState() => _CameraCapturePageState();
}

class _CameraCapturePageState extends State<CameraCapturePage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  String? _error;
  bool _isCapturing = false;

  /// 720p. The Gemma 4 vision encoder tiles into 16x16 patches capped at 2520,
  /// so a larger frame buys no detail — and we are already fighting for memory.
  static const ResolutionPreset _resolution = ResolutionPreset.high;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_setUpCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_controller?.dispose());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    // The OS revokes the camera when we lose the foreground; rebuild on return.
    if (state == AppLifecycleState.inactive) {
      unawaited(controller.dispose());
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      unawaited(_setUpCamera());
    }
  }

  Future<void> _setUpCamera() async {
    try {
      final List<CameraDescription> cameras = await availableCameras();
      if (cameras.isEmpty) {
        _failWith('No camera available on this device.');
        return;
      }
      final CameraDescription camera = cameras.firstWhere(
        (CameraDescription c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final CameraController controller = CameraController(
        camera,
        _resolution,
        enableAudio: false,
      );
      // Throws CameraException('CameraAccessDenied') if the user says no.
      await controller.initialize();
      if (!mounted) {
        unawaited(controller.dispose());
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      _failWith(
        e.code == 'CameraAccessDenied'
            ? 'Camera permission denied. Enable it in Settings to take a photo.'
            : 'Could not start the camera: ${e.description ?? e.code}',
      );
    }
  }

  void _failWith(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _error = message);
  }

  Future<void> _capture() async {
    final CameraController? controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isCapturing) {
      return;
    }
    setState(() => _isCapturing = true);
    try {
      final XFile shot = await controller.takePicture();
      final Uint8List bytes = await shot.readAsBytes();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(bytes);
    } on CameraException catch (e) {
      _failWith('Could not take the photo: ${e.description ?? e.code}');
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final CameraController? controller = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Take a photo'),
      ),
      body: _buildBody(controller),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: controller != null && controller.value.isInitialized
          ? FloatingActionButton.large(
              tooltip: 'Capture',
              onPressed: _isCapturing ? null : () => unawaited(_capture()),
              child: _isCapturing
                  ? const CircularProgressIndicator()
                  : const Icon(Icons.camera_alt),
            )
          : null,
    );
  }

  Widget _buildBody(CameraController? controller) {
    final String? error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }
    if (controller == null || !controller.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: CameraPreview(controller));
  }
}
