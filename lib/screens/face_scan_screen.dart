import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/user_profile.dart';
import '../services/liveness_checker.dart';
import '../services/mock_ndid_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/face_frame.dart';
import 'verification_result.dart';

class FaceScanScreen extends StatefulWidget {
  const FaceScanScreen({
    super.key,
    required this.profile,
    required this.idp,
    this.ndidService = const MockNdidService(),
  });

  final UserProfile profile;
  final IdentityProvider idp;
  final MockNdidService ndidService;

  @override
  State<FaceScanScreen> createState() => _FaceScanScreenState();
}

class _FaceScanScreenState extends State<FaceScanScreen>
    with WidgetsBindingObserver {
  final _checker = LivenessChecker();
  final _detector = FaceDetector(
    options: FaceDetectorOptions(
      enableClassification: true,
      minFaceSize: 0.2,
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  CameraController? _controller;
  String? _cameraError;
  bool _startingCamera = false;
  bool _processingFrame = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_submitting) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed &&
        _controller == null &&
        _cameraError == null) {
      // ถ้าเปิดกล้องไม่สำเร็จ ให้ผู้ใช้กดลองใหม่เอง เพื่อไม่ให้ขอสิทธิ์ซ้ำวนไป
      _startCamera();
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    if (controller == null) return;
    if (mounted) setState(() => _controller = null);
    await controller.dispose();
  }

  Future<void> _startCamera() async {
    if (_startingCamera) return;
    _startingCamera = true;
    if (mounted) setState(() => _cameraError = null);

    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('NoCamera', 'no camera on this device');
      }
      final camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await controller.startImageStream(
        (image) => _onFrame(image, controller!),
      );
      _checker.reset();
      setState(() => _controller = controller);
    } on CameraException catch (e) {
      await controller?.dispose();
      if (mounted) setState(() => _cameraError = _describeCameraError(e));
    } finally {
      _startingCamera = false;
    }
  }

  String _describeCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
      case 'cameraPermission':
        return 'แอปไม่ได้รับอนุญาตให้ใช้กล้อง กรุณาอนุญาตในการตั้งค่าของเครื่อง แล้วลองอีกครั้ง';
      case 'NoCamera':
        return 'ไม่พบกล้องบนอุปกรณ์นี้';
      default:
        return 'เปิดกล้องไม่สำเร็จ (${e.code}) กรุณาลองอีกครั้ง';
    }
  }

  Future<void> _onFrame(CameraImage image, CameraController controller) async {
    if (_processingFrame || _submitting || _checker.isDone) return;
    final input = _toInputImage(image, controller);
    if (input == null) return;

    _processingFrame = true;
    try {
      final faces = await _detector.processImage(input);
      if (!mounted || !identical(controller, _controller)) return;
      setState(() => _checker.update(_toSample(faces, input.metadata!)));
      if (_checker.isDone) await _submit();
    } on PlatformException catch (e) {
      debugPrint('Face detection failed: ${e.code}');
    } finally {
      _processingFrame = false;
    }
  }

  FaceSample _toSample(List<Face> faces, InputImageMetadata metadata) {
    if (faces.length != 1) return FaceSample(faceCount: faces.length);
    final face = faces.single;
    final box = face.boundingBox;

    // พิกัดของ ML Kit อ้างอิงภาพหลังหมุนแล้ว
    final rotated = metadata.rotation == InputImageRotation.rotation90deg ||
        metadata.rotation == InputImageRotation.rotation270deg;
    final width = rotated ? metadata.size.height : metadata.size.width;
    final height = rotated ? metadata.size.width : metadata.size.height;

    return FaceSample(
      faceCount: 1,
      centerX: box.center.dx / width,
      centerY: box.center.dy / height,
      widthRatio: box.width / width,
      leftEyeOpen: face.leftEyeOpenProbability,
      rightEyeOpen: face.rightEyeOpenProbability,
      headYaw: face.headEulerAngleY ?? 0,
    );
  }

  InputImage? _toInputImage(CameraImage image, CameraController controller) {
    final sensor = controller.description.sensorOrientation;
    final InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensor);
    } else {
      const degrees = {
        DeviceOrientation.portraitUp: 0,
        DeviceOrientation.landscapeLeft: 90,
        DeviceOrientation.portraitDown: 180,
        DeviceOrientation.landscapeRight: 270,
      };
      final device = degrees[controller.value.deviceOrientation] ?? 0;
      final isFront =
          controller.description.lensDirection == CameraLensDirection.front;
      rotation = InputImageRotationValue.fromRawValue(
        isFront ? (sensor + device) % 360 : (sensor - device + 360) % 360,
      );
    }
    if (rotation == null) return null;

    final size = Size(image.width.toDouble(), image.height.toDouble());
    if (Platform.isAndroid) {
      return InputImage.fromBytes(
        bytes: yuv420ToNv21(image),
        metadata: InputImageMetadata(
          size: size,
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: size,
        rotation: rotation,
        format: InputImageFormat.bgra8888,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    await _stopCamera();
    if (!mounted) return;
    final saved = await completeVerification(
      context,
      profile: widget.profile,
      idp: widget.idp,
      ndidService: widget.ndidService,
    );
    // บันทึกไม่สำเร็จ ให้สแกนใหม่
    if (!saved && mounted) {
      setState(() => _submitting = false);
      await _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final theme = Theme.of(context);
    final message = _submitting
        ? 'กำลังส่งคำขอยืนยันตัวตนไปยัง ${widget.idp.name}...'
        : _cameraError ?? _checker.message;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const StepHeader(current: 3, title: 'ตรวจสอบใบหน้า'),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: FaceFrame(
                      progress: _submitting ? 1 : _checker.progress,
                      scanning: controller != null && !_submitting,
                      child: _buildPreview(controller),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: Text(
                      message,
                      key: ValueKey(message),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LivenessSteps(
                current:
                    _submitting ? LivenessStep.done.index : _checker.step.index,
              ),
              if (_cameraError != null) ...[
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _startCamera,
                  child: const Text('ลองอีกครั้ง'),
                ),
              ],
              // อีมูเลเตอร์ไม่มีใบหน้าจริงให้ตรวจ จึงมีปุ่มข้ามเฉพาะ debug build
              if (kDebugMode && !_submitting) ...[
                const SizedBox(height: 4),
                TextButton(
                  onPressed: _submit,
                  child: const Text('ข้ามการสแกน (เฉพาะ debug build)'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreview(CameraController? controller) {
    if (_cameraError != null) {
      return const Icon(
        Icons.no_photography_outlined,
        size: 56,
        color: AppColors.muted,
      );
    }
    if (_submitting || controller == null || !controller.value.isInitialized) {
      return const Center(
        child: SizedBox.square(
          dimension: 32,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }
    final preview = controller.value.previewSize!;
    return TweenAnimationBuilder<double>(
      key: ValueKey(controller),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }
}

/// แปลงภาพ YUV420 สามระนาบจาก CameraX เป็น NV21 ที่ ML Kit รองรับ
Uint8List yuv420ToNv21(CameraImage image) {
  final width = image.width;
  final height = image.height;
  final yPlane = image.planes[0];
  final uPlane = image.planes[1];
  final vPlane = image.planes[2];

  final nv21 = Uint8List(width * height + width * (height ~/ 2));
  var out = 0;

  for (var row = 0; row < height; row++) {
    final start = row * yPlane.bytesPerRow;
    nv21.setRange(out, out + width, yPlane.bytes, start);
    out += width;
  }

  final uvPixelStride = uPlane.bytesPerPixel ?? 1;
  for (var row = 0; row < height ~/ 2; row++) {
    final uRow = row * uPlane.bytesPerRow;
    final vRow = row * vPlane.bytesPerRow;
    for (var col = 0; col < width ~/ 2; col++) {
      final offset = col * uvPixelStride;
      nv21[out++] = vPlane.bytes[vRow + offset];
      nv21[out++] = uPlane.bytes[uRow + offset];
    }
  }
  return nv21;
}
