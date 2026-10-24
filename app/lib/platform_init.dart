// Penyiapan khusus platform sebelum database dibuka.
export 'platform_init_io.dart' if (dart.library.js_interop) 'platform_init_web.dart';
