/// Recovery script — decrypts calendartask_data.json with a known base64 key
/// and writes the plaintext JSON to stdout (or a file).
///
/// Usage:
///   dart run tools/recover_data.dart <base64_key> [path_to_data_file]
///
/// Example:
///   dart run tools/recover_data.dart "abc123==" \
///     "/Users/ankit/Library/CloudStorage/OneDrive-Blend360(2)/calendartask_data.json"
///
/// If no file path is given, it falls back to the default OneDrive location.

import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;

const _kGcmPrefix = 'v2:';
// No default — data file path must be supplied as the second argument.

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/recover_data.dart <base64_key> [data_file_path]');
    exit(1);
  }

  if (args.length < 2) {
    stderr.writeln('Usage: dart run tools/recover_data.dart <base64_key> <data_file_path>');
    exit(1);
  }
  final base64Key  = args[0].trim();
  final dataPath   = args[1];
  final outputPath = '$dataPath.recovered.json';

  enc.Key key;
  try {
    key = enc.Key.fromBase64(base64Key);
  } catch (e) {
    stderr.writeln('Invalid base64 key: $e');
    exit(1);
  }

  final file = File(dataPath);
  if (!file.existsSync()) {
    stderr.writeln('Data file not found: $dataPath');
    exit(1);
  }

  final content = file.readAsStringSync().trim();
  String? plaintext;

  if (content.startsWith(_kGcmPrefix)) {
    // v2 GCM format
    final body = content.substring(_kGcmPrefix.length);
    final sep  = body.indexOf(':');
    if (sep == -1) { stderr.writeln('Malformed v2 header'); exit(1); }
    try {
      final iv        = enc.IV.fromBase64(body.substring(0, sep));
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
      plaintext = encrypter.decrypt64(body.substring(sep + 1), iv: iv);
    } catch (e) {
      stderr.writeln('GCM decryption failed (wrong key?): $e');
      exit(1);
    }
  } else {
    // Legacy CBC format
    final sep = content.indexOf(':');
    if (sep == -1) { stderr.writeln('Unrecognised file format'); exit(1); }
    try {
      final iv        = enc.IV.fromBase64(content.substring(0, sep));
      final encrypter = enc.Encrypter(enc.AES(key));
      plaintext = encrypter.decrypt64(content.substring(sep + 1), iv: iv);
    } catch (e) {
      stderr.writeln('CBC decryption failed (wrong key?): $e');
      exit(1);
    }
  }

  if (plaintext == null) { stderr.writeln('Decryption returned null'); exit(1); }

  File(outputPath).writeAsStringSync(plaintext, flush: true);
  stdout.writeln('✓ Decrypted successfully → $outputPath');
  stdout.writeln('  First 120 chars: ${plaintext.substring(0, plaintext.length.clamp(0, 120))}');
}
