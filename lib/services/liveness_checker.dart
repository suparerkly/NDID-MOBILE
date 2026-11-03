/// ค่าจากกล้องหนึ่งเฟรม พิกัดเป็นสัดส่วน 0-1 ของภาพ
class FaceSample {
  const FaceSample({
    required this.faceCount,
    this.centerX = 0,
    this.centerY = 0,
    this.widthRatio = 0,
    this.leftEyeOpen,
    this.rightEyeOpen,
    this.headYaw = 0,
  });

  final int faceCount;
  final double centerX;
  final double centerY;
  final double widthRatio;
  final double? leftEyeOpen;
  final double? rightEyeOpen;
  final double headYaw;
}

enum LivenessStep { alignFace, blink, turnHead, done }

/// ลำดับการตรวจ: จัดใบหน้าให้อยู่กลางกรอบ, กะพริบตา, หันหน้าแล้วกลับมาตรง
///
/// เป็นการจำลองเพื่อสาธิตเท่านั้น ไม่ได้ป้องกันการปลอมแปลงระดับ NDID จริง
class LivenessChecker {
  static const _framesToAlign = 8;
  static const _framesToResetOnLoss = 10;
  static const _eyeOpen = 0.6;
  static const _eyeClosed = 0.25;
  static const _yawTurned = 20.0;
  static const _yawStraight = 10.0;

  LivenessStep step = LivenessStep.alignFace;
  String message = 'จัดใบหน้าให้อยู่ในกรอบ';

  int _alignedFrames = 0;
  int _lostFrames = 0;
  bool _eyesWereOpen = false;
  bool _eyesClosed = false;
  bool _headTurned = false;

  bool get isDone => step == LivenessStep.done;

  /// ความคืบหน้า 0-1 สำหรับแสดงบนหน้าจอ
  double get progress => step.index / LivenessStep.done.index;

  void reset() {
    step = LivenessStep.alignFace;
    message = 'จัดใบหน้าให้อยู่ในกรอบ';
    _alignedFrames = 0;
    _lostFrames = 0;
    _eyesWereOpen = false;
    _eyesClosed = false;
    _headTurned = false;
  }

  void update(FaceSample sample) {
    if (isDone) return;

    if (sample.faceCount != 1) {
      _lostFrames++;
      if (_lostFrames >= _framesToResetOnLoss) {
        reset();
        _lostFrames = _framesToResetOnLoss;
      }
      message = sample.faceCount == 0
          ? 'ไม่พบใบหน้า กรุณาหันหน้าเข้าหากล้อง'
          : 'พบมากกว่า 1 ใบหน้า กรุณาอยู่คนเดียวในกรอบ';
      return;
    }
    _lostFrames = 0;

    switch (step) {
      case LivenessStep.alignFace:
        _checkAlign(sample);
      case LivenessStep.blink:
        _checkBlink(sample);
      case LivenessStep.turnHead:
        _checkTurn(sample);
      case LivenessStep.done:
        break;
    }
  }

  void _checkAlign(FaceSample s) {
    final tooFar = s.widthRatio < 0.3;
    final tooClose = s.widthRatio > 0.9;
    final offCenter =
        (s.centerX - 0.5).abs() > 0.2 || (s.centerY - 0.5).abs() > 0.2;

    if (tooFar || tooClose || offCenter || s.headYaw.abs() > _yawStraight) {
      _alignedFrames = 0;
      message = tooFar
          ? 'ขยับเข้าใกล้กล้องอีกนิด'
          : tooClose
              ? 'ถอยห่างจากกล้องอีกนิด'
              : offCenter
                  ? 'จัดใบหน้าให้อยู่กลางกรอบ'
                  : 'มองตรงเข้าหากล้อง';
      return;
    }

    _alignedFrames++;
    message = 'ดีมาก อยู่นิ่ง ๆ สักครู่';
    if (_alignedFrames >= _framesToAlign) {
      step = LivenessStep.blink;
      message = 'กะพริบตา 1 ครั้ง';
    }
  }

  void _checkBlink(FaceSample s) {
    final left = s.leftEyeOpen;
    final right = s.rightEyeOpen;
    if (left == null || right == null) return;

    final open = left > _eyeOpen && right > _eyeOpen;
    final closed = left < _eyeClosed && right < _eyeClosed;

    if (!_eyesWereOpen) {
      _eyesWereOpen = open;
    } else if (closed) {
      _eyesClosed = true;
    } else if (open && _eyesClosed) {
      step = LivenessStep.turnHead;
      message = 'ค่อย ๆ หันหน้าไปด้านข้าง แล้วกลับมามองตรง';
    }
  }

  void _checkTurn(FaceSample s) {
    if (s.headYaw.abs() > _yawTurned) {
      _headTurned = true;
      message = 'ดีมาก หันกลับมามองตรง';
    } else if (_headTurned && s.headYaw.abs() < _yawStraight) {
      step = LivenessStep.done;
      message = 'ตรวจสอบใบหน้าเรียบร้อย';
    }
  }
}
