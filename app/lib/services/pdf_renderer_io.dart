import 'package:flutter/services.dart';

/// Pembungkus android.graphics.pdf.PdfRenderer (lihat MainActivity.kt).
/// Dipakai karena ringan, tanpa library PDF pihak ketiga.
class NativePdfDocument {
  NativePdfDocument._(this._id, this.pageSizes);

  static const _channel = MethodChannel('qorybook/pdf');

  final int _id;

  /// Ukuran setiap halaman dalam satuan point PDF.
  final List<Size> pageSizes;
  final _cache = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  bool _closed = false;

  int get pageCount => pageSizes.length;

  static Future<NativePdfDocument> open(String path) async {
    final res = await _channel.invokeMapMethod<String, Object?>('open', {'path': path});
    if (res == null) throw PlatformException(code: 'open_failed', message: 'PDF tidak bisa dibuka');
    final sizes = (res['sizes'] as List)
        .cast<List<Object?>>()
        .map((s) => Size((s[0] as num).toDouble(), (s[1] as num).toDouble()))
        .toList(growable: false);
    return NativePdfDocument._(res['id'] as int, sizes);
  }

  /// Gambar JPEG halaman [index] dengan lebar [widthPx] piksel.
  Future<Uint8List> render(int index, int widthPx) {
    final w = widthPx.clamp(200, 2400);
    final key = '$index@$w';
    final cached = _cache.remove(key);
    if (cached != null) {
      _cache[key] = cached; // pindahkan ke paling baru
      return Future.value(cached);
    }
    return _pending.putIfAbsent(key, () async {
      try {
        if (_closed) throw StateError('closed');
        final bytes = await _channel.invokeMethod<Uint8List>('render', {'id': _id, 'page': index, 'width': w});
        if (bytes == null) throw PlatformException(code: 'render_failed');
        _cache[key] = bytes;
        while (_cache.length > 8) {
          _cache.remove(_cache.keys.first);
        }
        return bytes;
      } finally {
        _pending.remove(key);
      }
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _cache.clear();
    await _channel.invokeMethod('close', {'id': _id});
  }
}
