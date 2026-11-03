import 'package:flutter_test/flutter_test.dart';
import 'package:ndid_mobile/services/liveness_checker.dart';

const _straightOpen = FaceSample(
  faceCount: 1,
  centerX: 0.5,
  centerY: 0.5,
  widthRatio: 0.5,
  leftEyeOpen: 0.9,
  rightEyeOpen: 0.9,
);

const _closed = FaceSample(
  faceCount: 1,
  centerX: 0.5,
  centerY: 0.5,
  widthRatio: 0.5,
  leftEyeOpen: 0.1,
  rightEyeOpen: 0.1,
);

const _turned = FaceSample(
  faceCount: 1,
  centerX: 0.5,
  centerY: 0.5,
  widthRatio: 0.5,
  leftEyeOpen: 0.9,
  rightEyeOpen: 0.9,
  headYaw: 30,
);

void _align(LivenessChecker checker) {
  for (var i = 0; i < 8; i++) {
    checker.update(_straightOpen);
  }
}

void main() {
  test('completes after align, blink and head turn in order', () {
    final checker = LivenessChecker();

    _align(checker);
    expect(checker.step, LivenessStep.blink);

    checker
      ..update(_straightOpen)
      ..update(_closed)
      ..update(_straightOpen);
    expect(checker.step, LivenessStep.turnHead);

    checker
      ..update(_turned)
      ..update(_straightOpen);
    expect(checker.isDone, isTrue);
  });

  test('a static face with open eyes never passes the blink step', () {
    final checker = LivenessChecker();
    _align(checker);
    for (var i = 0; i < 100; i++) {
      checker.update(_straightOpen);
    }
    expect(checker.step, LivenessStep.blink);
  });

  test('eyes closed from the start do not count as a blink', () {
    final checker = LivenessChecker();
    _align(checker);
    checker
      ..update(_closed)
      ..update(_closed);
    expect(checker.step, LivenessStep.blink);
  });

  test('head turn must return to straight before completing', () {
    final checker = LivenessChecker();
    _align(checker);
    checker
      ..update(_straightOpen)
      ..update(_closed)
      ..update(_straightOpen)
      ..update(_straightOpen);
    expect(checker.step, LivenessStep.turnHead);

    checker.update(_turned);
    expect(checker.isDone, isFalse);
  });

  test('losing the face for a while restarts the check', () {
    final checker = LivenessChecker();
    _align(checker);
    expect(checker.step, LivenessStep.blink);

    for (var i = 0; i < 10; i++) {
      checker.update(const FaceSample(faceCount: 0));
    }
    expect(checker.step, LivenessStep.alignFace);
  });

  test('two faces do not advance alignment', () {
    final checker = LivenessChecker();
    for (var i = 0; i < 20; i++) {
      checker.update(const FaceSample(faceCount: 2));
    }
    expect(checker.step, LivenessStep.alignFace);
    expect(checker.message, contains('มากกว่า 1'));
  });

  test('off-center and far faces do not count as aligned', () {
    final checker = LivenessChecker();
    for (var i = 0; i < 20; i++) {
      checker.update(const FaceSample(
        faceCount: 1,
        centerX: 0.9,
        centerY: 0.5,
        widthRatio: 0.5,
      ));
    }
    expect(checker.step, LivenessStep.alignFace);

    for (var i = 0; i < 20; i++) {
      checker.update(const FaceSample(
        faceCount: 1,
        centerX: 0.5,
        centerY: 0.5,
        widthRatio: 0.1,
      ));
    }
    expect(checker.step, LivenessStep.alignFace);
  });
}
