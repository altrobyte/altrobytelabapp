import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// What a node currently is to this student.
enum MindState {
  /// The student. Always at the centre, always the brightest thing.
  you,

  /// On the current recommended direction.
  current,

  /// Still counts on the future being explored.
  shared,

  /// New, required by the future being explored.
  grown,

  /// Reachable, just no longer on the direct route. Dimmed, never removed.
  fading,

  /// A possible direction we have no evidence about yet.
  faint,
}

class MindNode {
  final String id;
  final String label;
  final MindState state;

  /// 0–100 where we can honestly count one, null where we cannot. A null is
  /// drawn as a node with no ring rather than a node with a zero.
  final int? signal;

  /// Optional one-liner shown under the label on larger nodes.
  final String note;

  /// Ring index from the centre. 0 is the student.
  final int ring;

  const MindNode({
    required this.id,
    required this.label,
    this.state = MindState.faint,
    this.signal,
    this.note = '',
    this.ring = 1,
  });
}

class MindEdge {
  final String from;
  final String to;
  const MindEdge(this.from, this.to);
}

/// The living map.
///
/// A list of futures is a menu; a student reads it the way they read a course
/// catalogue and feels nothing. The same futures drawn around them, with the
/// strong ones held close and the unevidenced ones left faint at the edge,
/// say something a list cannot: that this is about *them*, and that the
/// picture would look different for somebody else.
///
/// Three things carry that and nothing else needs to:
///   • position — distance from the centre is how well something currently
///     fits, so the shape of the map is already the answer;
///   • weight — a node we have evidence for is drawn solid, one we do not is
///     left faint, and the difference is visible before any text is read;
///   • motion — a slow drift, well under the threshold of distraction, so the
///     thing reads as alive rather than printed.
class MindMap extends StatefulWidget {
  final List<MindNode> nodes;
  final List<MindEdge> edges;
  final void Function(MindNode node)? onTap;
  final String? selectedId;

  /// Larger type and spacing, for a projector in a demo class.
  final bool present;

  const MindMap({
    super.key,
    required this.nodes,
    required this.edges,
    this.onTap,
    this.selectedId,
    this.present = false,
  });

  @override
  State<MindMap> createState() => _MindMapState();
}

class _MindMapState extends State<MindMap> with SingleTickerProviderStateMixin {
  late final AnimationController _drift;

  /// Where each node is, as a fraction of the radius, remembered by id so a
  /// node keeps its place when the graph changes around it. A future that
  /// jumped across the screen every time something else moved would read as
  /// noise rather than as a change.
  final Map<String, double> _angles = {};

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  /// Angles assigned once per id, spread so neighbours never collide.
  ///
  /// Deliberately not evenly spaced: a perfect ring reads as a diagram, and
  /// the brief asked for something organic. The offset is derived from the id
  /// so it is stable across rebuilds rather than random each frame.
  void _layout(List<MindNode> ring, int index) {
    if (ring.isEmpty) return;
    final step = 2 * math.pi / ring.length;
    for (var i = 0; i < ring.length; i++) {
      final n = ring[i];
      _angles.putIfAbsent(n.id, () {
        final jitter = ((n.id.hashCode & 0xFF) / 255 - 0.5) * step * 0.45;
        // Rings alternate their starting angle so an outer node never hides
        // directly behind an inner one.
        return -math.pi / 2 + i * step + jitter + (index.isEven ? 0 : step / 2);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final centre = widget.nodes.where((n) => n.state == MindState.you).toList();
    final ring1 = widget.nodes.where((n) => n.state != MindState.you && n.ring <= 1).toList();
    final ring2 = widget.nodes.where((n) => n.state != MindState.you && n.ring >= 2).toList();
    _layout(ring1, 1);
    _layout(ring2, 2);

    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return AnimatedBuilder(
        animation: _drift,
        builder: (context, _) {
          final placed = _place(size, centre, ring1, ring2);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _hit(placed, d.localPosition),
            child: CustomPaint(
              size: size,
              painter: _MindPainter(
                placed: placed,
                edges: widget.edges,
                selectedId: widget.selectedId,
                t: _drift.value,
                present: widget.present,
              ),
            ),
          );
        },
      );
    });
  }

  /// Node id → where it sits and how big it is, for this frame.
  Map<String, _Placed> _place(
      Size size, List<MindNode> centre, List<MindNode> ring1, List<MindNode> ring2) {
    final c = Offset(size.width / 2, size.height / 2);
    // The map has to fit the narrow side, or the outer ring falls off a phone.
    final unit = math.min(size.width, size.height) / 2;
    final out = <String, _Placed>{};

    for (final n in centre) {
      out[n.id] = _Placed(n, c, widget.present ? 46 : 38);
    }

    void ring(List<MindNode> nodes, double fraction, double radius) {
      for (final n in nodes) {
        final a = _angles[n.id] ?? 0;
        // Each node breathes on its own phase, so the field moves the way a
        // living thing does rather than the way a carousel does.
        final phase = (n.id.hashCode & 0x3FF) / 0x3FF;
        final wobble = math.sin((_drift.value + phase) * 2 * math.pi) * unit * 0.018;
        // A node we have evidence for is held closer in. Distance is the
        // first thing read on a graph, so it should carry the real meaning.
        final pull = n.signal == null ? 1.08 : 1.0 - (n.signal! / 100) * 0.18;
        final r = unit * fraction * pull + wobble;
        out[n.id] = _Placed(n, c + Offset(math.cos(a) * r, math.sin(a) * r * 0.92),
            radius);
      }
    }

    ring(ring1, 0.56, widget.present ? 34 : 27);
    ring(ring2, 0.88, widget.present ? 26 : 21);
    return out;
  }

  void _hit(Map<String, _Placed> placed, Offset p) {
    if (widget.onTap == null) return;
    _Placed? best;
    var bestD = double.infinity;
    for (final v in placed.values) {
      final d = (v.at - p).distance;
      // A generous target: these are finger-sized on a phone and a near miss
      // that does nothing feels broken.
      if (d < v.radius + 14 && d < bestD) {
        best = v;
        bestD = d;
      }
    }
    if (best != null) widget.onTap!(best.node);
  }
}

class _Placed {
  final MindNode node;
  final Offset at;
  final double radius;
  const _Placed(this.node, this.at, this.radius);
}

// ── Paint ──────────────────────────────────────────────────────────────────

const _navy = Color(0xFF12326B);
const _sky = Color(0xFF3E7BD6);
const _green = Color(0xFF2E7D32);
const _grey = Color(0xFF9AA5B5);

class _MindPainter extends CustomPainter {
  final Map<String, _Placed> placed;
  final List<MindEdge> edges;
  final String? selectedId;
  final double t;
  final bool present;

  _MindPainter({
    required this.placed,
    required this.edges,
    required this.selectedId,
    required this.t,
    required this.present,
  });

  (Color, double) _style(MindState s) => switch (s) {
        MindState.you => (_navy, 1.0),
        MindState.current => (_navy, 0.95),
        MindState.shared => (_green, 1.0),
        MindState.grown => (_sky, 1.0),
        MindState.fading => (_grey, 0.42),
        MindState.faint => (_grey, 0.55),
      };

  @override
  void paint(Canvas canvas, Size size) {
    _paintEdges(canvas);
    for (final p in placed.values) {
      _paintNode(canvas, p);
    }
  }

  void _paintEdges(Canvas canvas) {
    for (final e in edges) {
      final a = placed[e.from], b = placed[e.to];
      if (a == null || b == null) continue;

      final (colour, opacity) = _style(b.node.state);
      final dim = b.node.state == MindState.fading;

      // Curved, not straight. Straight lines between labelled boxes is what a
      // flowchart looks like, and this is meant to look like a mind.
      final mid = Offset.lerp(a.at, b.at, 0.5)!;
      final normal = (b.at - a.at);
      final bend = Offset(-normal.dy, normal.dx) * 0.10;
      final path = Path()
        ..moveTo(a.at.dx, a.at.dy)
        ..quadraticBezierTo(mid.dx + bend.dx, mid.dy + bend.dy, b.at.dx, b.at.dy);

      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = dim ? 1.0 : (b.node.signal == null ? 1.2 : 1.8)
          ..color = colour.withValues(alpha: opacity * (dim ? 0.30 : 0.42)),
      );

      // A slow point of light travelling the connection — only on the links
      // we have evidence for, so the eye is drawn to the real signal rather
      // than to decoration. This is the whole of the "alive" budget.
      if (!dim && b.node.signal != null) {
        final phase = ((t * 1.0) + (b.node.id.hashCode & 0xFF) / 255) % 1.0;
        final metric = path.computeMetrics().firstOrNull;
        if (metric != null) {
          final pos = metric.getTangentForOffset(metric.length * phase)?.position;
          if (pos != null) {
            canvas.drawCircle(
                pos,
                2.2,
                Paint()..color = colour.withValues(alpha: 0.55 * (1 - phase * 0.6)));
          }
        }
      }
    }
  }

  void _paintNode(Canvas canvas, _Placed p) {
    final n = p.node;
    final (colour, opacity) = _style(n.state);
    final selected = selectedId == n.id;
    final isYou = n.state == MindState.you;

    // A soft halo instead of a hard border. The brief asked for cell-like,
    // and a stroked circle reads as a button.
    if (n.signal != null || isYou || selected) {
      canvas.drawCircle(
        p.at,
        p.radius + (selected ? 13 : 7),
        Paint()
          ..color = colour.withValues(alpha: (selected ? 0.20 : 0.10) * opacity)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }

    canvas.drawCircle(
      p.at,
      p.radius,
      Paint()
        ..color = isYou
            ? colour.withValues(alpha: 0.96)
            : colour.withValues(alpha: 0.10 * opacity + (selected ? 0.10 : 0)),
    );
    canvas.drawCircle(
      p.at,
      p.radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.2 : 1.3
        ..color = colour.withValues(alpha: opacity * (selected ? 0.9 : 0.55)),
    );

    // The signal drawn as an arc of the circle itself — the node is more full
    // the better it currently fits. No number needed to read the map.
    if (n.signal != null && !isYou) {
      canvas.drawArc(
        Rect.fromCircle(center: p.at, radius: p.radius + 4),
        -math.pi / 2,
        2 * math.pi * (n.signal! / 100),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.75),
      );
    }

    _text(canvas, p, colour, opacity, isYou);
  }

  void _text(Canvas canvas, _Placed p, Color colour, double opacity, bool isYou) {
    final n = p.node;
    final painter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      text: TextSpan(children: [
        TextSpan(
          text: n.label,
          style: GoogleFonts.poppins(
            fontSize: isYou ? (present ? 15 : 12.5) : (present ? 11.5 : 9.8),
            height: 1.15,
            fontWeight: FontWeight.w700,
            color: isYou ? Colors.white : colour.withValues(alpha: opacity),
          ),
        ),
        if (n.note.isNotEmpty)
          TextSpan(
            text: '\n${n.note}',
            style: GoogleFonts.inter(
              fontSize: isYou ? (present ? 10.5 : 8.8) : (present ? 9 : 7.6),
              height: 1.35,
              fontWeight: FontWeight.w500,
              color: isYou
                  ? Colors.white.withValues(alpha: 0.78)
                  : colour.withValues(alpha: opacity * 0.72),
            ),
          ),
      ]),
    )..layout(maxWidth: p.radius * 2.5);

    painter.paint(canvas,
        p.at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.t != t ||
      old.selectedId != selectedId ||
      old.placed.length != placed.length;
}
