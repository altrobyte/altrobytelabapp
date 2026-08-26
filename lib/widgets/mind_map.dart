import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// What a node currently is to this student.
enum MindState {
  /// The student. The root of the map.
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

  /// 0–100 where we can honestly count one, null where we cannot.
  final int? signal;

  /// Optional second line, under the label.
  final String note;

  /// "Strong signal", "Emerging", "Possible", "Unexplored" — the word that
  /// stops a number from reading as a probability.
  final String tier;

  const MindNode({
    required this.id,
    required this.label,
    this.state = MindState.faint,
    this.signal,
    this.note = '',
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

/// The map, drawn the way a mind map is actually drawn.
///
/// This started as a constellation — futures in a ring around the student —
/// and read as a diagram of seven things rather than a map of a subject. A
/// mind map earns its name by branching: the student is the root, directions
/// grow off them, and what each direction is built out of grows off that. The
/// shape itself then says the thing no caption can, which is that these are
/// not seven separate careers but one body of work that forks.
///
/// Three properties carry the meaning and nothing else needs to:
///   • branching — depth is dependency, so the map reads as a subject rather
///     than a menu;
///   • weight — a branch with evidence behind it is drawn solid and its
///     children are lit, and one without is left faint, which is visible
///     before a word is read;
///   • motion — nodes travel to their new places when a what-if rearranges
///     the map, because a graph that redrew and a future that changed look
///     identical unless you watch it happen.
class MindMap extends StatefulWidget {
  final List<MindNode> nodes;
  final List<MindEdge> edges;
  final void Function(MindNode node)? onTap;
  final void Function(MindEdge edge)? onEdgeTap;
  final String? selectedId;

  /// The branch the map is currently arranged around: it and its children are
  /// lit, everything else recedes.
  final String? focusId;

  /// Larger type, for a projector in a demo class.
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
  /// Drives every rearrangement. Nodes travel from where they were to where
  /// they belong instead of teleporting.
  late final AnimationController _morph;

  Map<String, Offset> _from = {};
  Map<String, _Placed> _last = {};

  final TransformationController _view = TransformationController();

  Size _canvas = Size.zero;

  /// The canvas the view was last framed against. A tap grows the map, which
  /// makes the canvas bigger, and leaving the view where it was pushed the
  /// new branches off the top and bottom of the screen.
  Size _framed = Size.zero;

  /// Set the moment somebody pans or pinches. After that the view is theirs
  /// and nothing here moves it — being dragged back to centre while you are
  /// reading something is worse than having to scroll.
  bool _moved = false;

  @override
  void initState() {
    super.initState();
    _morph = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
      value: 1,
    );
    // The first draw is a reveal: the student, then their branches found one
    // at a time.
    _morph.forward(from: 0);
  }

  @override
  void didUpdateWidget(MindMap old) {
    super.didUpdateWidget(old);
    final before = {for (final n in old.nodes) n.id};
    final now = {for (final n in widget.nodes) n.id};
    // Backing out to the whole map hands the view back to us; anything else
    // they did with it stands.
    if (widget.focusId == null && old.focusId != null) {
      _moved = false;
      _framed = Size.zero;
    }
    if (widget.focusId != old.focusId ||
        before.length != now.length ||
        !before.containsAll(now)) {
      _from = {for (final e in _last.entries) e.key: e.value.at};
      _morph.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _view.dispose();
    super.dispose();
  }

  /// Frame the map: on the node just tapped if there is one, otherwise the
  /// whole tree.
  ///
  /// Centring on the tapped node matters more than fitting everything once
  /// the map is large. What somebody wants to see after tapping is what grew
  /// out of what they tapped, and a whole-tree fit at that point just makes
  /// every label too small to read.
  void _frame(Size viewport, Map<String, _Placed> placed) {
    if (_canvas.isEmpty || viewport.isEmpty) return;

    final fit = math.min(
        math.min(viewport.width / _canvas.width, viewport.height / _canvas.height),
        1.0);

    final target = widget.focusId == null ? null : placed[widget.focusId];
    if (target == null) {
      final dx = (viewport.width - _canvas.width * fit) / 2;
      final dy = (viewport.height - _canvas.height * fit) / 2;
      _view.value = Matrix4.identity()
        ..translateByDouble(dx, dy, 0, 1)
        ..scaleByDouble(fit, fit, 1, 1);
      return;
    }

    // Readable rather than complete: never shrink past the point where the
    // labels stop being words.
    final scale = math.max(fit, 0.62).clamp(0.25, 1.0);
    _view.value = Matrix4.identity()
      ..translateByDouble(viewport.width / 2 - target.at.dx * scale,
          viewport.height / 2 - target.at.dy * scale, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final size = Size(box.maxWidth, box.maxHeight);
      return AnimatedBuilder(
        animation: _morph,
        builder: (context, _) {
          final placed = _layout();
          _last = placed;

          // The canvas is the size of the tree, not the size of the window.
          // Painting a 900px map onto a 500px canvas simply cut the rest off,
          // and panning stopped at the canvas edge — so the branches were
          // there, unreachable, which is exactly what it looked like.
          // Re-frame whenever the tree changes shape, which is what a tap
          // does. Left alone the view stayed put and the new branches were
          // drawn past the top and bottom of the screen.
          if (_canvas != _framed && !_moved) {
            final canvas = _canvas;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted || _canvas != canvas) return;
              _frame(size, placed);
              _framed = canvas;
            });
          }

          return InteractiveViewer(
            constrained: false,
            // Deliberately not onInteractionStart: that fires on a plain
            // tap too, so the very first node tap would have switched
            // following off before it ever worked.
            onInteractionUpdate: (d) {
              if (d.scale != 1.0 || d.focalPointDelta.distance > 2) {
                _moved = true;
              }
            },
            minScale: 0.25,
            maxScale: 2.5,
            boundaryMargin: const EdgeInsets.all(120),
            transformationController: _view,
            child: SizedBox(
              width: _canvas.width,
              height: _canvas.height,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _hit(placed, d.localPosition),
                child: CustomPaint(
                  size: _canvas,
                  painter: _MindPainter(
                    placed: placed,
                    edges: widget.edges,
                    selectedId: widget.selectedId,
                    focusId: widget.focusId,
                    morph: Curves.easeOutCubic.transform(_morph.value),
                    present: widget.present,
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  // ── Layout ────────────────────────────────────────────────────────────────

  /// A tidy tree, balanced either side of the root.
  ///
  /// Everything hanging off the student is split into two halves that grow
  /// left and right, because a single left-to-right run puts the root against
  /// one edge and wastes the screen it was given.
  Map<String, _Placed> _layout() {
    final byId = {for (final n in widget.nodes) n.id: n};
    final children = <String, List<String>>{};
    final hasParent = <String>{};
    for (final e in widget.edges) {
      if (!byId.containsKey(e.from) || !byId.containsKey(e.to)) continue;
      if (hasParent.contains(e.to)) continue; // a tree, not a graph
      children.putIfAbsent(e.from, () => []).add(e.to);
      hasParent.add(e.to);
    }
    final rootId = widget.nodes
        .firstWhere((n) => n.state == MindState.you,
            orElse: () => widget.nodes.isEmpty
                ? const MindNode(id: '_', label: '')
                : widget.nodes.first)
        .id;

    // Every node is measured, and a branch is as tall as what it holds. The
    // old version gave each leaf a fixed thirty pixels, which was fine for a
    // one-line label and nowhere near enough once a node carried a second
    // line — so siblings were laid out on top of one another.
    const gapY = 13.0;
    const gapX = 34.0;

    final sizes = <String, Size>{};
    for (final n in widget.nodes) {
      var depth = 0;
      var cursor = n.id;
      while (depth < 8) {
        final parent = widget.edges.where((e) => e.to == cursor).firstOrNull?.from;
        if (parent == null) break;
        cursor = parent;
        depth++;
      }
      sizes[n.id] = _MindPainter.measure(n, depth, widget.present);
    }

    final heights = <String, double>{};
    double heightOf(String id) {
      final kids = children[id] ?? const [];
      final own = (sizes[id]?.height ?? 20) + 10 + gapY;
      if (kids.isEmpty) return heights[id] = own;
      final stacked = kids.fold(0.0, (a, k) => a + heightOf(k));
      return heights[id] = math.max(own, stacked);
    }
    heightOf(rootId);

    // Columns are as wide as the widest box in them, so a long label never
    // reaches into the next level.
    final columnOf = <int, double>{};
    void widths(String id, int depth) {
      final w = (sizes[id]?.width ?? 60) + 14;
      columnOf[depth] = math.max(columnOf[depth] ?? 0, w);
      for (final k in children[id] ?? const []) {
        widths(k, depth + 1);
      }
    }
    widths(rootId, 0);

    double xFor(int depth) {
      var x = 0.0;
      for (var d = 0; d < depth; d++) {
        x += (columnOf[d] ?? 80) / 2 + gapX + (columnOf[d + 1] ?? 80) / 2;
      }
      return x;
    }

    final out = <String, _Placed>{};
    final morph = Curves.easeOutCubic.transform(_morph.value);

    // Split the root's branches so roughly half the weight goes each way.
    final top = children[rootId] ?? const [];
    final total = top.fold(0.0, (a, k) => a + (heights[k] ?? 0));
    final right = <String>[], left = <String>[];
    var running = 0.0;
    for (final id in top) {
      if (running < total / 2) {
        right.add(id);
      } else {
        left.add(id);
      }
      running += heights[id] ?? 0;
    }

    void place(String id, int depth, double side, double slotTop) {
      final n = byId[id];
      if (n == null) return;
      final span = heights[id] ?? 30;
      final target = Offset(side * xFor(depth), slotTop + span / 2);
      out[id] = _Placed(
          n,
          Offset.lerp(_from[id] ?? Offset.zero, target, morph)!,
          depth,
          side,
          sizes[id] ?? const Size(60, 20));

      var cursor = slotTop;
      for (final k in children[id] ?? const []) {
        place(k, depth + 1, side, cursor);
        cursor += heights[k] ?? 30;
      }
    }

    void stack(List<String> ids, double side) {
      final height = ids.fold(0.0, (a, k) => a + (heights[k] ?? 0));
      var cursor = -height / 2;
      for (final id in ids) {
        place(id, 1, side, cursor);
        cursor += heights[id] ?? 0;
      }
    }

    stack(right, 1);
    stack(left, -1);

    final rootNode = byId[rootId];
    if (rootNode != null) {
      out[rootId] = _Placed(rootNode, Offset.zero, 0, 1,
          _MindPainter.measure(rootNode, 0, widget.present));
    }

    // Everything was laid out around the origin. Measure what that came to,
    // and shift it into a canvas that actually holds it.
    var bounds = Rect.zero;
    for (final v in out.values) {
      final r = Rect.fromCenter(
          center: v.at, width: v.size.width + 40, height: v.size.height + 26);
      bounds = bounds == Rect.zero ? r : bounds.expandToInclude(r);
    }
    const pad = 40.0;
    _canvas = Size(bounds.width + pad * 2, bounds.height + pad * 2);
    final shift = Offset(pad - bounds.left, pad - bounds.top);

    return {
      for (final e in out.entries)
        e.key: _Placed(e.value.node, e.value.at + shift, e.value.depth,
            e.value.side, e.value.size)
    };
  }

  void _hit(Map<String, _Placed> placed, Offset p) {
    for (final v in placed.values) {
      if (v.rect.inflate(6).contains(p)) {
        widget.onTap?.call(v.node);
        return;
      }
    }
    if (widget.onEdgeTap == null) return;
    for (final e in widget.edges) {
      if (e.relation.isEmpty) continue;
      final a = placed[e.from], b = placed[e.to];
      if (a == null || b == null) continue;
      if (_toSegment(p, a.at, b.at) < 12) {
        widget.onEdgeTap!(e);
        return;
      }
    }
  }

  static double _toSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
    return (p - (a + ab * t)).distance;
  }
}

class _Placed {
  final MindNode node;
  final Offset at;
  final int depth;

  /// -1 growing left of the root, 1 growing right.
  final double side;
  final Size size;

  const _Placed(this.node, this.at, this.depth, this.side, this.size);

  Rect get rect => Rect.fromCenter(
      center: at, width: size.width + 14, height: size.height + 10);
}

// ── Paint ──────────────────────────────────────────────────────────────────

const _navy = Color(0xFF12326B);
const _sky = Color(0xFF5B9BEA);
const _green = Color(0xFF4CAF50);
const _grey = Color(0xFF93A9C9);

class _MindPainter extends CustomPainter {
  final Map<String, _Placed> placed;
  final List<MindEdge> edges;
  final String? selectedId;
  final String? focusId;
  final double morph;
  final bool present;

  _MindPainter({
    required this.placed,
    required this.edges,
    required this.selectedId,
    required this.focusId,
    required this.morph,
    required this.present,
  });

  static double fontFor(int depth, bool present) => depth == 0
      ? (present ? 16 : 13.5)
      : (depth == 1 ? (present ? 13 : 11.5) : (present ? 11 : 9.8));

  static double _maxWidth(int depth, bool present) =>
      depth == 0 ? 120 : (present ? 150 : 118);

  /// The label, built once and used for both measuring and painting.
  ///
  /// These were two separate pieces of code and they disagreed: the measure
  /// allowed one line for the second row while the paint wrapped it onto
  /// two, so every box was shorter than its contents and the children of a
  /// branch printed straight through each other.
  static TextPainter _painter(MindNode n, int depth, bool present,
      {Color colour = Colors.white, double opacity = 1, bool isYou = false}) {
    final second = n.tier.isNotEmpty
        // The words first. "Emerging · 81" cannot be misread as a probability
        // the way a bare 81 can.
        ? '${n.tier}${n.signal == null ? '' : ' · ${n.signal}'}'
        : n.note;

    return TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 3,
      ellipsis: '…',
      text: TextSpan(children: [
        TextSpan(
          text: n.label,
          style: GoogleFonts.poppins(
            fontSize: fontFor(depth, present),
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: isYou ? Colors.white : colour.withValues(alpha: opacity),
          ),
        ),
        if (second.isNotEmpty)
          TextSpan(
            text: '\n$second',
            style: GoogleFonts.inter(
              fontSize: present ? 9.5 : 8.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: isYou
                  ? Colors.white.withValues(alpha: 0.8)
                  : colour.withValues(alpha: opacity * 0.7),
            ),
          ),
      ]),
    )..layout(maxWidth: _maxWidth(depth, present));
  }

  static Size measure(MindNode n, int depth, bool present) =>
      _painter(n, depth, present).size;

  (Color, double) _style(MindState s) => switch (s) {
        MindState.you => (_navy, 1.0),
        MindState.current => (_sky, 1.0),
        MindState.shared => (_green, 1.0),
        MindState.grown => (_sky, 1.0),
        MindState.fading => (_grey, 0.40),
        MindState.faint => (_grey, 0.72),
      };

  /// Whether this node is inside the focused branch. Focus on a tree is a lit
  /// branch, not a border on one box.
  bool _inFocus(String id) {
    if (focusId == null) return true;
    if (id == focusId || id == 'you') return true;
    var cursor = id;
    for (var i = 0; i < 8; i++) {
      final parent = edges.where((e) => e.to == cursor).firstOrNull?.from;
      if (parent == null) return false;
      if (parent == focusId) return true;
      cursor = parent;
    }
    return false;
  }

  /// How far into the rearrangement this node is. Staggered by depth, so the
  /// map grows outward rather than snapping into place.
  double _progress(int depth) {
    final start = (depth * 0.16).clamp(0.0, 0.5);
    return ((morph - start) / (1 - start)).clamp(0.0, 1.0);
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final e in edges) {
      _paintEdge(canvas, e);
    }
    for (final p in placed.values) {
      _paintNode(canvas, p);
    }
  }

  void _paintEdge(Canvas canvas, MindEdge e) {
    final a = placed[e.from], b = placed[e.to];
    if (a == null || b == null) return;

    final (colour, opacity) = _style(b.node.state);
    final grow = _progress(b.depth);
    if (grow <= 0.01) return;

    // From the edge of the parent box to the edge of the child's, so the line
    // joins two labels rather than crossing them.
    final start = Offset(a.at.dx + b.side * (a.size.width / 2 + 7), a.at.dy);
    final end = Offset(b.at.dx - b.side * (b.size.width / 2 + 7), b.at.dy);
    final dx = (end.dx - start.dx).abs();
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(start.dx + b.side * dx * 0.55, start.dy,
          end.dx - b.side * dx * 0.55, end.dy, end.dx, end.dy);

    final metric = path.computeMetrics().firstOrNull;
    final drawn =
        metric == null ? path : metric.extractPath(0, metric.length * grow);

    final dim = b.node.state == MindState.fading || !_inFocus(b.node.id);
    final strong = (b.node.signal ?? 0) >= 80;
    canvas.drawPath(
      drawn,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = b.depth == 1 ? (strong ? 2.4 : 1.7) : 1.2
        ..color = colour.withValues(
            alpha: opacity * grow * (dim ? 0.22 : (strong ? 0.75 : 0.5))),
    );
  }

  void _paintNode(Canvas canvas, _Placed p) {
    final n = p.node;
    var (colour, opacity) = _style(n.state);
    final grow = _progress(p.depth);
    if (grow <= 0.02) return;
    if (!_inFocus(n.id)) opacity *= 0.38;

    final isYou = n.state == MindState.you;
    final selected = selectedId == n.id || focusId == n.id;
    final rect = p.rect;

    if (isYou || selected) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.inflate(5), const Radius.circular(12)),
        Paint()
          ..color = colour.withValues(alpha: 0.22 * grow)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(isYou ? 12 : 8)),
      Paint()
        ..color = isYou
            ? colour.withValues(alpha: 0.95 * grow)
            : colour.withValues(alpha: (selected ? 0.16 : 0.07) * opacity * grow),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(isYou ? 12 : 8)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1.0
        ..color = colour.withValues(
            alpha: opacity * grow * (selected ? 0.95 : 0.45)),
    );

    // A short bar under a first-level branch, filled to its signal. The
    // strength is then readable without reading, which is the only reason a
    // number belongs on a map at all.
    if (!isYou && p.depth == 1 && n.signal != null) {
      final y = rect.bottom + 3;
      final w = rect.width - 8;
      canvas.drawLine(
        Offset(rect.left + 4, y),
        Offset(rect.left + 4 + w, y),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.14 * grow),
      );
      canvas.drawLine(
        Offset(rect.left + 4, y),
        Offset(rect.left + 4 + w * (n.signal! / 100), y),
        Paint()
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = colour.withValues(alpha: 0.85 * opacity * grow),
      );
    }

    _text(canvas, p, colour, opacity * grow, isYou);
  }

  void _text(Canvas canvas, _Placed p, Color colour, double opacity, bool isYou) {
    final painter = _MindPainter._painter(p.node, p.depth, present,
        colour: colour, opacity: opacity, isYou: isYou);
    painter.paint(canvas, p.at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_MindPainter old) =>
      old.morph != morph ||
      old.selectedId != selectedId ||
      old.focusId != focusId ||
      old.placed.length != placed.length;
}
