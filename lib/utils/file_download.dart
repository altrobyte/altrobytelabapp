// Saves bytes as a file from the browser. Web-only, like the notes editor.
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytes(String filename, Uint8List bytes, {String mime = 'application/pdf'}) {
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
