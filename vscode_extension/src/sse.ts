// A small server-sent-events parser: feed it text as it arrives, get whole events out.
// Kept free of any VS Code or network code so it can be tested on its own.

export interface SseEvent {
  event: string;
  data: string;
}

export class SseParser {
  private buffer = '';

  /** Add a chunk; returns every event that is now complete (in order). */
  push(chunk: string): SseEvent[] {
    this.buffer += chunk.replace(/\r\n/g, '\n');
    const out: SseEvent[] = [];
    let idx: number;
    while ((idx = this.buffer.indexOf('\n\n')) >= 0) {
      const block = this.buffer.slice(0, idx);
      this.buffer = this.buffer.slice(idx + 2);
      let event = 'message';
      const data: string[] = [];
      for (const line of block.split('\n')) {
        if (!line || line.startsWith(':')) {
          continue; // blank, or a keep-alive comment
        }
        const colon = line.indexOf(':');
        const field = colon < 0 ? line : line.slice(0, colon);
        const value = colon < 0 ? '' : line.slice(colon + 1).replace(/^ /, '');
        if (field === 'event') {
          event = value;
        } else if (field === 'data') {
          data.push(value);
        }
      }
      if (data.length || event !== 'message') {
        out.push({ event, data: data.join('\n') });
      }
    }
    return out;
  }
}
