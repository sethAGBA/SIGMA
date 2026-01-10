import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
// firebase_auth and firebase_app_check are optional in this package.
// Avoid direct imports here to keep this service buildable for all targets.

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  String _sanitizeFileName(String name) {
    var n = name.replaceAll(RegExp(r"\s+"), "_");
    n = n.replaceAll(RegExp(r"[\\/]+"), "_");
    n = n.replaceAll(RegExp(r"[^A-Za-z0-9._-]"), "");
    if (n.isEmpty) n = "file";
    return n;
  }

  String _sanitizePath(String path) {
    if (path.isEmpty) return path;
    final parts = path.split('/');
    if (parts.isEmpty) return path;
    final fileName = parts.removeLast();
    final safe = _sanitizeFileName(fileName);
    return [...parts, safe].join('/');
  }

  Future<String> uploadFile(String path, File file) async {
    final safePath = _sanitizePath(path);
    final ref = _storage.ref().child(safePath);
    try {
      final bucketFromOptions = Firebase.app().options.storageBucket;
      // ignore: avoid_print
      print('[Storage] Uploading to bucket: ref.bucket=${ref.bucket}; app.options=$bucketFromOptions; path=${ref.fullPath}');
    } catch (_) {}

    // Attach simple metadata (content type guessed from extension)
    final contentType = _guessContentType(file.path);
    final metadata = SettableMetadata(contentType: contentType);

    // Basic retry loop for transient network errors
    const int maxAttempts = 3;
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // Debug: print app options; avoid importing firebase_auth/firebase_app_check here
        try {
          final opts = Firebase.app().options;
          // ignore: avoid_print
          print('[StorageDebug] projectId=${opts.projectId}; storageBucket=${opts.storageBucket}');
        } catch (_) {
          // ignore: avoid_print
          print('[StorageDebug] Firebase app options not available');
        }

        final uploadTask = ref.putFile(file, metadata);
        final snapshot = await uploadTask.whenComplete(() => null);
        final url = await snapshot.ref.getDownloadURL();
        // ignore: avoid_print
        print('[Storage] Upload succeeded: $url');
        return url;
      } on FirebaseException catch (e) {
        // HTTP 404 or specific codes likely indicate config/bucket issues and should not be retried
        // ignore: avoid_print
        print('[Storage] attempt=$attempt error=${e.code} message=${e.message}');
        if (e.code == 'object-not-found' || e.code == 'unauthenticated') {
          // Try fallback non-resumable upload once before giving up
          if (attempt == 1) {
            try {
              final bytes = await file.readAsBytes();
              // ignore: avoid_print
              print('[Storage] trying putData fallback (non-resumable)');
              final snapshot = await ref.putData(bytes, metadata).whenComplete(() => null);
              final url = await snapshot.ref.getDownloadURL();
              // ignore: avoid_print
              print('[Storage] putData fallback succeeded: $url');
              return url;
            } catch (fallbackErr) {
              // ignore: avoid_print
              print('[Storage] putData fallback failed: $fallbackErr');
            }
          }
          if (attempt == maxAttempts) rethrow;
        }
        // small delay between retries
        await Future.delayed(Duration(seconds: 1 * attempt));
      } catch (e) {
        // ignore: avoid_print
        print('[Storage] unexpected error on attempt=$attempt: $e');
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(Duration(seconds: 1 * attempt));
      }
    }
    throw Exception('Upload failed after $maxAttempts attempts');
  }

  /// Start an upload and return the [UploadTask] so callers can listen to
  /// progress events and control the upload (cancel, pause, resume).
  UploadTask startUpload(String path, File file) {
    final safePath = _sanitizePath(path);
    final ref = _storage.ref().child(safePath);
    try {
      final bucketFromOptions = Firebase.app().options.storageBucket;
      // ignore: avoid_print
      print('[Storage] Start upload: ref.bucket=${ref.bucket}; app.options=$bucketFromOptions; path=${ref.fullPath}');
    } catch (_) {}
    final metadata = SettableMetadata(contentType: _guessContentType(file.path));
    return ref.putFile(file, metadata);
  }

  String? _guessContentType(String path) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return null;
    }
  }
}
