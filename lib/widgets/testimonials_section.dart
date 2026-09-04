import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';
import '../services/api_service.dart';

/// What people who did this actually said.
///
/// Placed where a reader has just been asked to believe something — under the
/// roadmap's claim, and on the home page below the programme. The college
/// beside each name is doing most of the work: a student in Indore who reads
/// "SGSITS" is reading about somebody they could have sat next to.
///
/// Renders nothing at all when there are no published testimonials. An empty
/// "What students say" heading over blank space is worse than silence — it
/// says we asked and nobody answered.
class TestimonialsSection extends StatefulWidget {
  /// 'home' or 'roadmap'.
  final String place;

  /// Dark background, for the navy sections.
  final bool onDark;

  const TestimonialsSection({
    super.key,
    required this.place,
    this.onDark = false,
  });

  @override
  State<TestimonialsSection> createState() => _TestimonialsSectionState();
}

class _TestimonialsSectionState extends State<TestimonialsSection> {
  List _items = const [];
  double _average = 0;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getTestimonials(place: widget.place);
      if (!mounted) return;
      setState(() {
        _items = (d['testimonials'] as List?) ?? const [];
        _average = (d['average_rating'] as num?)?.toDouble() ?? 0;
        _loaded = true;
      });
    } catch (_) {
      // Silent: a page that cannot reach the server should still show the
      // thing the reader came for, minus this.
      if (mounted) setState(() => _loaded = true);
    }
  }

  Color get _title => widget.onDark ? Colors.white : AppColors.primary;
  Color get _body =>
      widget.onDark ? Colors.white.withValues(alpha: 0.82) : const Color(0xFF44546C);
  Color get _muted =>
      widget.onDark ? Colors.white.withValues(alpha: 0.55) : const Color(0xFF8A97AA);

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _items.isEmpty) return const SizedBox.shrink();
    final wide = MediaQuery.of(context).size.width >= 900;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('What people who did it say',
              style: GoogleFonts.poppins(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _title)),
          const Spacer(),
          if (_average > 0) ...[
            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF5A623)),
            const SizedBox(width: 4),
            Text('${_average.toStringAsFixed(1)} · ${_items.length}',
                style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _muted)),
          ],
        ]),
        const SizedBox(height: 12),
        if (wide)
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final t in _items)
                SizedBox(width: 330, child: _card(Map<String, dynamic>.from(t))),
            ],
          )
        else
          // A horizontal rail on a phone: three cards stacked is a wall, and
          // a reader who has to scroll past all of them reads none.
          SizedBox(
            height: 186,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 11),
              itemBuilder: (_, i) => SizedBox(
                  width: 290,
                  child: _card(Map<String, dynamic>.from(_items[i]))),
            ),
          ),
      ]),
    );
  }

  Widget _card(Map<String, dynamic> t) {
    final rating = (t['rating'] as num?)?.toInt() ?? 5;
    final where = '${t['affiliation'] ?? ''}'.trim();
    final role = '${t['role'] ?? ''}'.trim();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: widget.onDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: widget.onDark
                ? Colors.white.withValues(alpha: 0.14)
                : const Color(0xFFE6EBF3)),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              for (var i = 0; i < 5; i++)
                Icon(
                    i < rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    size: 14,
                    color: const Color(0xFFF5A623)),
            ]),
            const SizedBox(height: 9),
            Expanded(
              child: Text('"${t['quote'] ?? ''}"',
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12.5, height: 1.55, color: _body)),
            ),
            const SizedBox(height: 11),
            Text('${t['name'] ?? ''}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _title)),
            if (where.isNotEmpty || role.isNotEmpty)
              Text([role, where].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 11.5, color: _muted)),
          ]),
    );
  }
}
