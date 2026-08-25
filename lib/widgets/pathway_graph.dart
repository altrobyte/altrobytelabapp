import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A node on a pathway, and where it came from.
enum NodeState {
  /// On the current recommended path and still on the new one.
  shared,

  /// Only on the current path — reachable, just no longer next.
  fading,

  /// New on the alternative.
  grown,

  /// Ordinary node on the only path being shown.
  plain,
}

class PathNode {
  final String id;
  final String label;
  final NodeState state;
  const PathNode({
    required this.id,
    required this.label,
    this.state = NodeState.plain,
  });
}

/// The pathway, drawn as something that changes rather than something that is.
///
/// A roadmap printed as a list says "this is the path". The same steps drawn
/// as a graph that visibly rearranges when a student asks "what if" say
/// something else: that the path is one of several, and that most of what
/// they have already done still counts on the others. That second sentence is
/// the one worth building, and no amount of prose delivers it — a student has
/// to watch the shared nodes stay put while the rest moves.
class PathwayGraph extends StatelessWidget {
  final List<PathNode> nodes;

  /// Larger, for a projector.
  final bool present;

  /// Tapping a node asks why it is there.
  final void Function(PathNode node)? onTap;

  const PathwayGraph({
    super.key,
    required this.nodes,
    this.present = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < nodes.length; i++) ...[
          _Node(
            node: nodes[i],
            index: i,
            present: present,
            onTap: onTap == null ? null : () => onTap!(nodes[i]),
          ),
          if (i < nodes.length - 1) _connector(nodes[i], nodes[i + 1]),
        ],
      ],
    );
  }

  /// The line between two steps, coloured by what happens to the one below —
  /// so the eye follows the surviving path without reading anything.
  Widget _connector(PathNode from, PathNode to) {
    final dimmed = to.state == NodeState.fading;
    return Padding(
      padding: const EdgeInsets.only(left: 21),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 420),
        width: 2,
        height: present ? 26 : 20,
        color: dimmed
            ? const Color(0xFF9AA5B5).withValues(alpha: 0.25)
            : const Color(0xFF12326B).withValues(alpha: 0.35),
      ),
    );
  }
}

class _Node extends StatelessWidget {
  final PathNode node;
  final int index;
  final bool present;
  final VoidCallback? onTap;

  const _Node({
    required this.node,
    required this.index,
    required this.present,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = switch (node.state) {
      NodeState.shared => (
          const Color(0xFF2E7D32),
          const Color(0xFF2E7D32).withValues(alpha: 0.08),
          'Still counts',
        ),
      NodeState.grown => (
          const Color(0xFF12326B),
          const Color(0xFF12326B).withValues(alpha: 0.08),
          'New',
        ),
      NodeState.fading => (
          const Color(0xFF9AA5B5),
          Colors.transparent,
          'Less direct',
        ),
      NodeState.plain => (
          const Color(0xFF12326B),
          Colors.white,
          '',
        ),
    };
    final (fg, bg, tag) = palette;
    final faded = node.state == NodeState.fading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 420),
      // Dimmed, never removed. A student who watches a step vanish learns
      // that choosing costs them work; one who watches it dim learns it is
      // still there if they turn back.
      opacity: faded ? 0.45 : 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(
              horizontal: 12, vertical: present ? 14 : 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: faded
                  ? const Color(0xFFE1E7F0)
                  : fg.withValues(alpha: 0.35),
            ),
          ),
          child: Row(children: [
            Container(
              width: present ? 26 : 22,
              height: present ? 26 : 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: faded ? const Color(0xFFF1F4F9) : fg,
                shape: BoxShape.circle,
              ),
              child: Text('${index + 1}',
                  style: GoogleFonts.poppins(
                      fontSize: present ? 12 : 10.5,
                      fontWeight: FontWeight.w700,
                      color: faded ? const Color(0xFF9AA5B5) : Colors.white)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(node.label,
                  style: GoogleFonts.poppins(
                      fontSize: present ? 16 : 13.5,
                      fontWeight: FontWeight.w600,
                      color: faded
                          ? const Color(0xFF9AA5B5)
                          : const Color(0xFF0B2450))),
            ),
            if (tag.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(tag,
                    style: GoogleFonts.inter(
                        fontSize: present ? 11 : 9.5,
                        fontWeight: FontWeight.w700,
                        color: fg)),
              ),
            if (onTap != null) ...[
              const SizedBox(width: 6),
              Icon(Icons.help_outline_rounded,
                  size: present ? 18 : 15, color: const Color(0xFF9AA5B5)),
            ],
          ]),
        ),
      ),
    );
  }
}
