/// Re-encrypts a plaintext (recovered) JSON file with a fresh AES-256-GCM key
/// and writes both the encrypted data file and the key file to the same directory.
///
/// Usage:
///   dart run tools/reencrypt_data.dart <plaintext_json_path>
///
/// Writes:
///   <dir>/calendartask_data.json  — encrypted with new key (v2: format)
///   <dir>/calendartask_key.b64   — the new key in base64

import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;

const _kDataFileName = 'calendartask_data.json';
const _kKeyFileName  = 'calendartask_key.b64';
const _kGcmPrefix    = 'v2:';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Usage: dart run tools/reencrypt_data.dart <plaintext_json_path>');
    exit(1);
  }

  final inputPath = args[0];
  final inputFile = File(inputPath);
  if (!inputFile.existsSync()) {
    stderr.writeln('File not found: $inputPath');
    exit(1);
  }

  final plaintext = inputFile.readAsStringSync();
  final dir       = inputFile.parent.path;
  final outData   = '$dir/$_kDataFileName';
  final outKey    = '$dir/$_kKeyFileName';

  // Generate a fresh 256-bit key.
  final key       = enc.Key.fromSecureRandom(32);
  final iv        = enc.IV.fromSecureRandom(12);
  final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
  final cipher    = encrypter.encrypt(plaintext, iv: iv);
  final encrypted = '$_kGcmPrefix${iv.base64}:${cipher.base64}';

  File(outData).writeAsStringSync(encrypted, flush: true);
  File(outKey).writeAsStringSync(key.base64,  flush: true);

  stdout.writeln('✓ Encrypted  → $outData');
  stdout.writeln('✓ Key file   → $outKey');
  stdout.writeln('  Key (base64): ${key.base64}');
}
