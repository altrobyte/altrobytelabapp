// A small server-sent-events parser: feed it text as it arrives, get whole events out.
// Kept free of any Flutter or network code so it can be tested on its own.

class SseEvent {
  final String event;
  final String data;
  const SseEvent(this.event, this.data);
}

class SseParser {
  String _buffer = '';

  /// Add a chunk; returns every event that is now complete, in order.
  List<SseEvent> push(String chunk) {
    _buffer += chunk.replaceAll('\r\n', '\n');
    final out = <SseEvent>[];
    int idx;
    while ((idx = _buffer.indexOf('\n\n')) >= 0) {
      final block = _buffer.substring(0, idx);
      _buffer = _buffer.substring(idx + 2);
      var event = 'message';
      final data = <String>[];
      for (final line in block.split('\n')) {
        if (line.isEmpty || line.startsWith(':')) continue; // blank, or a keep-alive comment
        final colon = line.indexOf(':');
        final field = colon < 0 ? line : line.substring(0, colon);
        var value = colon < 0 ? '' : line.substring(colon + 1);
        if (value.startsWith(' ')) value = value.substring(1);
        if (field == 'event') {
          event = value;
        } else if (field == 'data') {
          data.add(value);
        }
      }
      if (data.isNotEmpty || event != 'message') out.add(SseEvent(event, data.join('\n')));
    }
    return out;
  }
}
