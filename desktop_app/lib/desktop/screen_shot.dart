// One picture of the learner's screen for Altron (B7, 25 Oct 2026: "Altron, dekho ye error kya hai").
//
// Taken with Windows' own GDI (BitBlt of the primary screen) through FFI: no script, nothing to install. A PowerShell
// version was blocked by antivirus as "malicious content", which would have happened on learners' PCs too. The picture is
// shrunk to at most 1280 px wide and sent as a JPEG, in a background isolate so the app never stutters.

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:win32/win32.dart';

/// Base64 JPEG of the primary screen, or null when it could not be taken.
Future<String?> screenshotJpegBase64() async {
  if (!Platform.isWindows) return null;
  try {
    final raw = _grab();
    if (raw == null) return null;
    return await compute(_encode, raw);
  } catch (_) {
    return null;
  }
}

typedef _Raw = ({int w, int h, Uint8List bgra});

_Raw? _grab() {
  final w = GetSystemMetrics(SM_CXSCREEN), h = GetSystemMetrics(SM_CYSCREEN);
  if (w <= 0 || h <= 0) return null;
  final screen = GetDC(NULL);
  final mem = CreateCompatibleDC(screen);
  final bmp = CreateCompatibleBitmap(screen, w, h);
  final old = SelectObject(mem, bmp);
  final info = calloc<BITMAPINFO>();
  final buf = calloc<Uint8>(w * h * 4);
  try {
    BitBlt(mem, 0, 0, w, h, screen, 0, 0, SRCCOPY);
    info.ref.bmiHeader
      ..biSize = sizeOf<BITMAPINFOHEADER>()
      ..biWidth = w
      ..biHeight = -h                                // top-down rows
      ..biPlanes = 1
      ..biBitCount = 32
      ..biCompression = BI_RGB;
    if (GetDIBits(mem, bmp, 0, h, buf.cast(), info, DIB_RGB_COLORS) == 0) return null;
    return (w: w, h: h, bgra: Uint8List.fromList(buf.asTypedList(w * h * 4)));
  } finally {
    SelectObject(mem, old);
    DeleteObject(bmp);
    DeleteDC(mem);
    ReleaseDC(NULL, screen);
    calloc.free(info);
    calloc.free(buf);
  }
}

String _encode(_Raw r) {
  final full = img.Image.fromBytes(width: r.w, height: r.h, bytes: r.bgra.buffer, numChannels: 4, order: img.ChannelOrder.bgra);
  final small = r.w > 1280 ? img.copyResize(full, width: 1280) : full;
  return base64Encode(img.encodeJpg(small, quality: 70));
}
