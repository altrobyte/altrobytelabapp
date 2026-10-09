// The few things only this app can do on this computer: make a folder to start in, and open a file in VS Code.
// Everything else (the board, the project files, PlatformIO, the serial port) is done by the helper.

import 'dart:io';

/// A ready folder under Documents, so a learner never has to find or pick one to begin.
String? starterFolder({Map<String, String>? env}) {
  try {
    final e = env ?? Platform.environment;
    final home = e['USERPROFILE'] ?? e['HOME'];
    if (home == null || home.isEmpty) return null;
    final sep = Platform.pathSeparator;
    final dir = Directory('$home${sep}Documents${sep}Altrobyte${sep}esp32-temperature');
    dir.createSync(recursive: true);
    return dir.path;
  } catch (_) {
    return null;
  }
}

/// Where VS Code's command line is, most likely first.
List<String> codeCandidates({Map<String, String>? env}) {
  final e = env ?? Platform.environment;
  final sep = Platform.pathSeparator;
  final local = e['LOCALAPPDATA'];
  return [
    if (local != null && local.isNotEmpty) '$local${sep}Programs${sep}Microsoft VS Code${sep}bin${sep}code.cmd',
    r'C:\Program Files\Microsoft VS Code\bin\code.cmd',
    'code',
  ];
}

/// The project a file belongs to: the nearest folder above it that holds a platformio.ini (looked for a few levels up).
String? projectRootOf(String file, {bool Function(String path)? exists}) {
  final has = exists ?? (p) => File(p).existsSync();
  final sep = file.contains('\\') ? '\\' : '/';
  var dir = file;
  for (var i = 0; i < 5; i++) {
    final cut = dir.lastIndexOf(sep);
    if (cut <= 0) return null;
    dir = dir.substring(0, cut);
    if (has('$dir${sep}platformio.ini')) return dir;
  }
  return null;
}

/// Opens a whole project folder in VS Code. False when VS Code could not be started.
Future<bool> openFolderInVsCode(String folder) async {
  for (final exe in codeCandidates()) {
    try {
      final r = await Process.run(exe, [folder], runInShell: true).timeout(const Duration(seconds: 20));
      if (r.exitCode == 0) return true;
    } catch (_) {
      // not there, try the next
    }
  }
  return false;
}

/// Brings a file to a line in VS Code, if it is installed. The helper asks for this when no VS Code window is connected
/// to it, which is the normal case while this app is the only one open.
Future<void> openInVsCode(String path, int line) async {
  final at = line < 1 ? 1 : line;
  // Open the project folder too, not just the file: without it VS Code cannot find the libraries and underlines the code in red.
  final root = projectRootOf(path);
  for (final exe in codeCandidates()) {
    try {
      final r = await Process.run(exe, [if (root != null) root, '-g', '$path:$at'], runInShell: true).timeout(const Duration(seconds: 20));
      if (r.exitCode == 0) return;
    } catch (_) {
      // not there, try the next
    }
  }
}
