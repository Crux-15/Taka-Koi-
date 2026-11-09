import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../utils/offline.dart';

/// Profile photos, kept small inside the database (no paid file storage).
///
/// A photo is cropped to a square and shrunk to about 20 KB, then saved in
/// `avatars/{uid}`. Profiles and tour members store the short token
/// `fs:{uid}` instead of a web address; [AvatarStore] turns that back into
/// the picture, always the latest one.
class AvatarService {
  AvatarService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  static const String collection = 'avatars';
  static const String _prefix    = 'fs:';
  static const int    _maxBytes  = 90 * 1024;

  static String tokenFor(String uid) => '$_prefix$uid';

  /// The user id behind a `fs:` token, or null for ordinary web addresses.
  static String? uidFromToken(String? url) =>
      url != null && url.startsWith(_prefix) && url.length > _prefix.length ? url.substring(_prefix.length) : null;

  /// Square-crops, upright-rotates and compresses a photo to a small JPEG.
  /// Throws [FormatException] if the file isn't a picture we can read.
  static Uint8List shrink(Uint8List original) {
    final decoded = img.decodeImage(original);
    if (decoded == null) throw const FormatException('That file isn\'t a photo we can read.');
    final square = img.copyResizeCropSquare(img.bakeOrientation(decoded), size: 256);
    for (final quality in const [78, 65, 50, 35]) {
      final jpg = Uint8List.fromList(img.encodeJpg(square, quality: quality));
      if (jpg.length <= _maxBytes) return jpg;
    }
    return Uint8List.fromList(img.encodeJpg(img.copyResize(square, width: 160), quality: 40));
  }

  /// Saves [original] as [uid]'s photo and returns the token to store on
  /// their profile. Works offline: it syncs when the phone is back online.
  Future<String> save(String uid, Uint8List original) async {
    final jpg = await compute(shrink, original);
    await saveOrQueue(
      _db.collection(collection).doc(uid).set({
        'data':      base64Encode(jpg),
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      'save avatar',
    );
    return tokenFor(uid);
  }

  Stream<Uint8List?> watch(String uid) => _db.collection(collection).doc(uid).snapshots().map((snap) {
        final data = snap.data()?['data'];
        if (data is! String || data.isEmpty) return null;
        try {
          return base64Decode(data);
        } catch (_) {
          return null;
        }
      });
}

/// Shared, cached photos: every avatar of the same person on screen uses one
/// database listener, and pictures stay in memory while the app runs.
class AvatarStore {
  AvatarStore._();

  static final Map<String, ValueNotifier<Uint8List?>> _photos = {};
  static final Map<String, StreamSubscription<Uint8List?>> _subs = {};
  static AvatarService? _service;

  static ValueListenable<Uint8List?> photoOf(String uid) {
    final existing = _photos[uid];
    if (existing != null) return existing;
    final notifier = ValueNotifier<Uint8List?>(null);
    _photos[uid] = notifier;
    try {
      _service ??= AvatarService();
      _subs[uid] = _service!.watch(uid).listen(
        (bytes) => notifier.value = bytes,
        onError: (Object _) {}, // no photo (or not allowed): initials show instead
      );
    } catch (_) {
      // Firebase isn't available (e.g. in tests): initials show instead.
    }
    return notifier;
  }

  /// Shows a just-picked photo straight away, before the save syncs.
  static void preview(String uid, Uint8List bytes) {
    (_photos[uid] ??= ValueNotifier<Uint8List?>(null)).value = bytes;
  }
}
