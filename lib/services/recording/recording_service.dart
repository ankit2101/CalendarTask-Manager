import 'package:flutter/services.dart';

/// Thin MethodChannel wrapper around RecordingBridge.swift.
class RecordingService {
  static final instance = RecordingService._();
  RecordingService._();

  static const _ch = MethodChannel('com.calendartask/recording');

  Future<void> startRecording(String mode) =>
      _ch.invokeMethod('startRecording', {'mode': mode});

  /// Stops recording and returns the path to the WAV file.
  Future<String> stopRecording() async {
    try {
      return await _ch.invokeMethod<String>('stopRecording') ?? '';
    } on PlatformException catch (e) {
      throw Exception('Stop recording failed: ${e.message ?? e.code}');
    }
  }

  /// Runs whisper-cli subprocess and returns the transcript text.
  Future<String> transcribeAudio({
    required String wavPath,
    required String modelPath,
    required String binaryPath,
  }) async =>
      await _ch.invokeMethod<String>('transcribeAudio', {
        'wavPath': wavPath,
        'modelPath': modelPath,
        'binaryPath': binaryPath,
      }) ?? '';

  /// Removes com.apple.quarantine xattr from a downloaded binary.
  Future<void> removeQuarantine(String path) =>
      _ch.invokeMethod('removeQuarantine', {'path': path});

  Future<String> getMicrophonePermission() async =>
      await _ch.invokeMethod<String>('getMicrophonePermission') ?? 'notDetermined';

  Future<bool> requestMicrophonePermission() async =>
      await _ch.invokeMethod<bool>('requestMicrophonePermission') ?? false;

  Future<List<String>> getAudioInputDevices() async =>
      await _ch.invokeListMethod<String>('getAudioInputDevices') ?? [];

  Future<bool> isScreenCaptureAvailable() async =>
      await _ch.invokeMethod<bool>('isScreenCaptureAvailable') ?? false;

  Future<bool> isRecording() async =>
      await _ch.invokeMethod<bool>('isRecording') ?? false;
}
