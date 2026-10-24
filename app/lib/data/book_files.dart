// Android/desktop menyimpan buku sebagai file; web hanya mengalirkannya dari server.
export 'book_files_io.dart' if (dart.library.js_interop) 'book_files_web.dart';
