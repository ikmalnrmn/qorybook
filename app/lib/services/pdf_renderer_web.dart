import 'dart:js_interop';
import 'dart:ui' show Size;

import 'package:flutter/services.dart' show Uint8List;

extension type _OpenResult._(JSObject _) implements JSObject {
  external JSNumber get id;
  external JSArray<JSNumber> get sizes;
}

@JS('qoryPdf.open')
external JSPromise<_OpenResult> _open(JSString url);

@JS('qoryPdf.render')
external JSPromise<JSUint8Array> _render(JSNumber id, JSNumber page, JSNumber width);

@JS('qoryPdf.close')
external void _close(JSNumber id);

/// Pembaca PDF versi web lewat pdf.js. API-nya sama dengan versi Android
/// (lihat pdf_renderer_io.dart); [open] menerima URL, bukan jalur file.
class NativePdfDocument {
  NativePdfDocument._(this._id, this.pageSizes);

  final int _id;

  /// Ukuran setiap halaman dalam satuan point PDF.
  final List<Size> pageSizes;
  final _cache = <String, Uint8List>{};
  final _pending = <String, Future<Uint8List>>{};
  bool _closed = false;

  int get pageCount => pageSizes.length;

  static Future<NativePdfDocument> open(String url) async {
    final res = await _open(url.toJS).toDart;
    final flat = res.sizes.toDart.map((n) => n.toDartDouble).toList(growable: false);
    final sizes = [for (var i = 0; i + 1 < flat.length; i += 2) Size(flat[i], flat[i + 1])];
    return NativePdfDocument._(res.id.toDartInt, sizes);
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
        final bytes = (await _render(_id.toJS, index.toJS, w.toJS).toDart).toDart;
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
    _close(_id.toJS);
  }
}
