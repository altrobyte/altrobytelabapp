// The learner's modules kept on this computer, so the home opens at once: what was fetched last time is shown straight
// away and the fresh copy replaces it when it arrives. One small JSON file per thing, per account, under
// %APPDATA%\Altrobyte\cache. A file that cannot be read or written is simply ignored: the network copy still works.

import 'dart:convert';
import 'dart:io';

class ModuleCache {
  ModuleCache(String account, {Map<String, String>? env}) : _dir = _folder(account, env ?? Platform.environment);

  final Directory? _dir;

  static Directory? _folder(String account, Map<String, String> env) {
    final base = env['APPDATA'] ?? env['HOME'];
    if (base == null || base.isEmpty) return null;
    final sep = Platform.pathSeparator;
    // The account's own folder: two people on one computer never see each other's modules.
    final id = account.codeUnits.fold<int>(7, (h, c) => (h * 31 + c) & 0x7fffffff).toRadixString(36);
    return Directory('$base${sep}Altrobyte${sep}cache$sep$id');
  }

  File? _file(String key) {
    final d = _dir;
    return d == null ? null : File('${d.path}${Platform.pathSeparator}$key.json');
  }

  dynamic read(String key) {
    try {
      final f = _file(key);
      if (f == null || !f.existsSync()) return null;
      return jsonDecode(f.readAsStringSync());
    } catch (_) {
      return null;
    }
  }

  void write(String key, Object? value) {
    try {
      final f = _file(key);
      if (f == null) return;
      f.parent.createSync(recursive: true);
      final tmp = File('${f.path}.tmp')..writeAsStringSync(jsonEncode(value));
      tmp.renameSync(f.path);                       // whole file or nothing: a half-written file is never read
    } catch (_) {}
  }
}
