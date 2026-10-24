import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

/// Web memakai SQLite WebAssembly (web/sqlite3.wasm) yang disimpan di IndexedDB browser.
void initPlatform() {
  sqflite.databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
