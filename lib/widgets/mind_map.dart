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

  /// "Strong signal", "Emerging", "Possible", "Unexplored" — the word that
  /// stops a number from reading as a probability.
  final String tier;

  const MindNode({
    required this.id,
    required this.label,
    this.state = MindState.faint,
    this.signal,
    this.note = '',
    this.ring = 1,
    this.tier = '',
  });
}

class MindEdge {
  final String from;
  final String to;

  /// Why these two are connected. A line that means nothing is decoration.
  final String relation;

  const MindEdge(this.from, this.to, {this.relation = ''});
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
  final void Function(MindEdge edge)? onEdgeTap;
  final String? selectedId;

  /// The node the map is currently arranged around. Everything else gives it
  /// room — which is what "focus" has to mean on a graph, rather than a
  /// border on a card.
  final String? focusId;

  /// Larger type and spacing, for a projector in a demo class.
  final bool present;

  const MindMap({
    super.key,
    required this.nodes,
    required this.edges,
    this.onTap,
    this.onEdgeTap,
    this.selectedId,
    this.focusId,
    this.present = false,
  });

  @override
  State<MindMap> createState() => _MindMapState();
}

class _MindMapState extends State<MindMap> with TickerProviderStateMixin {
  late final AnimationController _drift;

  /// Drives every rearrangement: a what-if, a focus, a new fact about the
  /// student. Nodes travel from where they were to where they belong instead
  /// of teleporting, which is the whole difference between a graph that
  /// redrew and a future that changed.
  late final AnimationController _morph;

  /// Where each node sat when the last change began, so it can be
  /// interpolated rather than replaced.
  Map<String, Offset> _from = {};
  Map<String, double> _fromRadius = {};
  Map<String, _Placed> _last = {};

  /// Nodes that were not on the previous map. They grow in rather than
  /// appearing, and are drawn last so they arrive on top.
  Set<String> _arriving = {};

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
    // Long enough to be followed, short enough not to be waited through.
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      value: 1,
    );
    // The first draw is a reveal: the student appears, then their
    // possibilities are found one at a time. It happens once.
    _morph.forward(from: 0);
  }

  @override
  void didUpdateWidget(MindMap old) {
    super.didUpdateWidget(old);
    final before = {for (final n in old.nodes) n.id};
    final now = {for (final n in widget.nodes) n.id};
    final rearranged = widget.focusId != old.focusId ||
        before.length != now.length ||
        !before.containsAll(now);
    if (rearranged) {
      _from = {for (final e in _last.entries) e.key: e.value.at};
      _fromRadius = {for (final e in _last.entries) e.key: e.value.radius};
      _arriving = now.difference(before);
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _morph.dispose();
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
        animation: Listenable.merge([_drift, _morph]),
        builder: (context, _) {
          final placed = _place(size, centre, ring1, ring2);
          _last = placed;
          // Pinch and drag, so a phone gets the same map rather than a
          // shrunken one.
          return InteractiveViewer(
            minScale: 0.7,
            maxScale: 2.6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapUp: (d) => _hit(placed, d.localPosition),
              child: CustomPaint(
                size: size,
                painter: _MindPainter(
                  placed: placed,
                  edges: widget.edges,
                  selectedId: widget.selectedId,
                  focusId: widget.focusId,
                  t: _drift.value,
                  morph: Curves.easeOutCubic.transform(_morph.value),
                  arriving: _arriving,
                  present: widget.present,
                ),
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
    final morphNow = Curves.easeOutCubic.transform(_morph.value);
    // The map has to fit the narrow side, or the outer ring falls off a phone.
    final unit = math.min(size.width, size.height) / 2;
    final out = <String, _Placed>{};

    for (final n in centre) {
      out[n.id] = _Placed(
          n, c, (widget.present ? 44.0 : 36.0) * (0.75 + 0.25 * morphNow));
    }

    final morph = morphNow;

    void ring(List<MindNode> nodes, double fraction, double radius) {
      for (final n in nodes) {
        final a = _angles[n.id] ?? 0;
        // Each node breathes on its own phase, so the field moves the way a
        // living thing does rather than the way a carousel does.
        final phase = (n.id.hashCode & 0x3FF) / 0x3FF;
        final wobble = math.sin((_drift.value + phase) * 2 * math.pi) * unit * 0.018;
        // A node we have evidence for is held closer in. Distance is the
        // first thing read on a graph, so it should carry the real meaning.
        var pull = n.signal == null ? 1.08 : 1.0 - (n.signal! / 100) * 0.18;
        // The focused node comes in; everything else steps back to give it
        // the room. Focus on a graph is space, not a border.
        if (widget.focusId != null) {
          pull *= n.id == widget.focusId ? 0.62 : 1.16;
        }
        final r = unit * fraction * pull + wobble;

        // Size carries the signal too, so weight is legible before any
        // number is read.
        final grow = n.signal == null ? 0.82 : 0.9 + (n.signal! / 100) * 0.5;
        var size = radius * grow * (n.id == widget.focusId ? 1.25 : 1.0);

        var at = c + Offset(math.cos(a) * r, math.sin(a) * r * 0.92);

        // Travel from wherever this node last was. A node with no history is
        // new: it grows out of the centre rather than fading in on the spot.
        final origin = _from[n.id] ?? c;
        at = Offset.lerp(origin, at, morph)!;
        size = _lerp(_fromRadius[n.id] ?? 0, size, morph);

        out[n.id] = _Placed(n, at, size);
      }
    }

    // One ring for the futures, with the radius doing the talking: a node we
    // have evidence for is pulled in, one we do not drifts out. Two rings for
    // seven nodes left the outer one with gaps you could park a car in.
    ring(ring1, 0.60, widget.present ? 22 : 17);
    ring(ring2, 0.90, widget.present ? 19 : 15);
    return out;
  }

  void _hit(Map<String, _Placed> placed, Offset p) {
    if (widget.onTap == null) return;
    _Placed? best;
    var bestD = double.infinity;
    for (final v in placed.values) {
      final d = (v.at - p).distance;
      // Generous, and reaching down over the label: the circle is a marker
      // now, and people aim at the word they can read.
      final reach = v.node.state == MindState.you ? v.radius + 8 : v.radius + 34;
      if (d < reach && d < bestD) {
        best = v;
        bestD = d;
      }
    }
    if (best != null) {
      widget.onTap!(best.node);
      return;
    }
    if (widget.onEdgeTap != null) _hitEdge(placed, p);
  }

  /// A tap that missed every node might have meant the line between two.
  void _hitEdge(Map<String, _Placed> placed, Offset p) {
    for (final e in widget.edges) {
      if (e.relation.isEmpty) continue;
      final a = placed[e.from], b = placed[e.to];
      if (a == null || b == null) continue;
      if (_distanceToSegment(p, a.at, b.at) < 14) {
        widget.onEdgeTap!(e);
        return;
      }
    }
  }

  static double _distanceToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    var t = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
    t = t.clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;

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
  final String? focusId;
  final double t;

  /// 0 at the start of a rearrangement, 1 once it has settled.
  final double morph;

  /// Nodes that were not on the previous map.
  final Set<String> arriving;
  final bool present;

  _MindPainter({
    required this.placed,
    required this.edges,
    required this.selectedId,
    required this.focusId,
    required this.t,
    required this.morph,
    required this.arriving,
    required this.present,
  });

  /// How far into the rearrangement this particular node is.
  ///
  /// Staggered by position in the list, so the map assembles itself rather
  /// than snapping into place all at once — the difference between watching
  /// something be worked out and watching a screen refresh.
  double _progress(String id) {
    final index = placed.keys.toList().indexOf(id);
    final start = (index * 0.055).clamp(0.0, 0.55);
    return ((morph - start) / (1 - start)).clamp(0.0, 1.0);
  }

  (Color, double) _style(MindState s) => switch (s) {
        MindState.you => (_navy, 1.0),
        MindState.current => (_navy, 0.95),
        MindState.shared => (_green, 1.0),
        MindState.grown => (_sky, 1.0),
        MindState.fading => (_grey, 0.42),
        // Unknown, not unimportant. At 0.55 on a dark field the whole map
        // read as switched off, which says something we do not mean: these
        // are real directions we simply have no evidence about yet.
        MindState.faint => (const Color(0xFF93A9C9), 0.78),
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

      // The line draws itself towards the node it leads to, so a new
      // possibility looks like it is being reached rather than switched on.
      final grow = _progress(b.node.id);
      final metric = path.computeMetrics().firstOrNull;
      final drawn = metric == null
          ? path
          : metric.extractPath(0, metric.length * grow);

      final strong = b.node.signal != null && b.node.signal! >= 80;
      canvas.drawPath(
        drawn,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth =
              dim ? 1.0 : (b.node.signal == null ? 1.1 : (strong ? 2.4 : 1.7))
          ..color = colour.withValues(
              alpha: opacity * (dim ? 0.28 : (strong ? 0.62 : 0.40))),
      );

      // A slow point of light travelling the connection — only on the links
      // we have evidence for, so the eye is drawn to the real signal rather
      // than to decoration. This is the whole of the "alive" budget.
      if (!dim && b.node.signal != null && grow > 0.98) {
        final phase = ((t * 1.0) + (b.node.id.hashCode & 0xFF) / 255) % 1.0;
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
    var (colour, opacity) = _style(n.state);
    final selected = selectedId == n.id || focusId == n.id;
    final isYou = n.state == MindState.you;

    final grow = isYou ? 1.0 : _progress(n.id);
    if (grow <= 0.01) return;
    opacity *= grow;

    // Emerging directions breathe. Only those: a map where everything
    // pulsed would be a screensaver, and the pulse is meant to say "this one
    // is moving" about a specific thing.
    final emerging = !isYou &&
        n.signal != null &&
        n.signal! >= 65 &&
        n.signal! < 80;
    final breath = emerging
        ? 1 + math.sin(t * 2 * math.pi * 2) * 0.045
        : 1.0;
    p = _Placed(n, p.at, p.radius * grow * breath);

    // A soft halo instead of a hard border. The brief asked for cell-like,
    // and a stroked circle reads as a button.
    canvas.drawCircle(
      p.at,
      p.radius + (selected ? 13 : 7),
      Paint()
        ..color = colour.withValues(
            alpha: (selected ? 0.24 : (n.signal == null && !isYou ? 0.07 : 0.13)) *
                opacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

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

  /// The label.
  ///
  /// Inside the circle it had to be shrunk until it fitted, which turned
  /// "Software Engineering" into three cramped lines and "IoT & Connected
  /// Products" into a smudge. Outside, the circle can stay small — it is a
  /// marker, not a box — and the words get the room they need.
  void _text(Canvas canvas, _Placed p, Color colour, double opacity, bool isYou) {
    final n = p.node;
    final painter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
      text: TextSpan(children: [
        TextSpan(
          text: n.label,
          style: GoogleFonts.poppins(
            fontSize: isYou ? (present ? 16 : 13.5) : (present ? 13 : 11.5),
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: isYou ? Colors.white : colour.withValues(alpha: opacity),
          ),
        ),
        if (!isYou && n.tier.isNotEmpty)
          TextSpan(
            // The words first. "Emerging · 81" cannot be misread as a
            // probability the way a bare 81 can.
            text: '\n${n.tier}${n.signal == null ? '' : ' · ${n.signal}'}',
            style: GoogleFonts.inter(
              fontSize: present ? 9.5 : 8.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: colour.withValues(alpha: opacity * 0.72),
            ),
          ),
        if (n.note.isNotEmpty)
          TextSpan(
            text: '\n${n.note}',
            style: GoogleFonts.inter(
              fontSize: isYou ? (present ? 11 : 9.5) : (present ? 10 : 9),
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: isYou
                  ? Colors.white.withValues(alpha: 0.8)
                  : colour.withValues(alpha: opacity * 0.7),
            ),
          ),
      ]),
    )..layout(maxWidth: isYou ? p.radius * 2 : (present ? 132 : 112));

    // The centre keeps its label inside — it is the one node big enough, and
    // a name floating under it would stop reading as the middle of anything.
    final origin = isYou
        ? p.at - Offset(painter.width / 2, painter.height / 2)
        : Offset(p.at.dx - painter.width / 2, p.at.dy + p.radius + 9);

    if (!isYou) {
      // A little ground under the text so a label crossing a connection
      // stays readable.
      final box = Rect.fromLTWH(
          origin.dx - 5, origin.dy - 3, painter.width + 10, painter.height + 6);
      canvas.drawRRect(
        RRect.fromRectAndRadius(box, const Radius.circular(6)),
        Paint()..color = const Color(0xFF0A1628).withValues(alpha: 0.55),
      );
    }
    painter.paint(canvas, origin);
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.t != t ||
      old.morph != morph ||
      old.selectedId != selectedId ||
      old.focusId != focusId ||
      old.placed.length != placed.length;
}
