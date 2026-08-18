// Top Stories and Lab Setups — the two admin-curated strips on the homepage.
//
// Both come from the same API and the same model; only the shape differs.
// Stories rotate on their own because a strip nobody scrolls shows one photo
// forever. Lab setups are square product cards, since a lab setup is a thing
// you buy rather than a thing you read.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constants/app_colors.dart';

/// A cover image with a play badge when the item leads with a video.
class ShowcaseCover extends StatelessWidget {
  final Map<String, dynamic> item;
  final double? width;
  final double? height;
  final BoxFit fit;
  const ShowcaseCover({
    super.key,
    required this.item,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  /// The cover if the admin set one, else the first media's thumbnail — a
  /// story added as "three photos" should not need a cover typed in as well.
  String get _url {
    final cover = item['cover_url'] as String? ?? '';
    if (cover.isNotEmpty) return cover;
    final media = (item['media'] as List?) ?? [];
    if (media.isEmpty) return '';
    return (media.first as Map)['thumbnail_url'] as String? ?? '';
  }

  bool get _hasVideo =>
      ((item['media'] as List?) ?? []).any((m) => (m as Map)['media_type'] == 'youtube');

  @override
  Widget build(BuildContext context) {
    final url = _url;
    return Stack(fit: StackFit.expand, children: [
      if (url.isEmpty)
        Container(color: AppColors.primary.withValues(alpha: 0.12),
            child: Icon(Icons.photo_outlined,
                color: AppColors.primary.withValues(alpha: 0.4), size: 30))
      else
        Image.network(url, width: width, height: height, fit: fit,
            errorBuilder: (_, __, ___) => Container(
                color: AppColors.primary.withValues(alpha: 0.12),
                child: Icon(Icons.broken_image_outlined,
                    color: AppColors.primary.withValues(alpha: 0.4), size: 26)),
            loadingBuilder: (c, child, p) => p == null
                ? child
                : Container(color: Colors.black.withValues(alpha: 0.05))),
      if (_hasVideo)
        Center(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
          ),
        ),
    ]);
  }
}

/// One story card. Portrait, like the stories it is named after, and it cycles
/// its own media so a card with five photos shows five photos.
class StoryCard extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const StoryCard({super.key, required this.item, required this.onTap});

  @override
  State<StoryCard> createState() => _StoryCardState();
}

class _StoryCardState extends State<StoryCard> {
  int _index = 0;
  Timer? _timer;

  List get _media => (widget.item['media'] as List?) ?? [];

  @override
  void initState() {
    super.initState();
    if (_media.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 4), (_) {
        if (mounted) setState(() => _index = (_index + 1) % _media.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = _media;
    final current = media.isEmpty ? null : media[_index % media.length] as Map;
    final url = current?['thumbnail_url'] as String? ??
        widget.item['cover_url'] as String? ??
        '';

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 150,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(fit: StackFit.expand, children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  child: url.isEmpty
                      ? Container(
                          key: const ValueKey('empty'),
                          color: AppColors.primary.withValues(alpha: 0.12))
                      : Image.network(url,
                          key: ValueKey(url), fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              color: AppColors.primary.withValues(alpha: 0.12))),
                ),
                // A gradient so white text stays readable on any photo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        stops: const [0.45, 1],
                      ),
                    ),
                  ),
                ),
                if (current?['media_type'] == 'youtube')
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 22),
                    ),
                  ),
                // Progress pips, so the rotation reads as deliberate rather
                // than as the image glitching.
                if (media.length > 1)
                  Positioned(
                    top: 8,
                    left: 8,
                    right: 8,
                    child: Row(children: [
                      for (var i = 0; i < media.length; i++) ...[
                        Expanded(
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: i == _index % media.length
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (i != media.length - 1) const SizedBox(width: 3),
                      ],
                    ]),
                  ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Text(
                    widget.item['title'] as String? ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25),
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

/// A lab setup — square, priced, and read as a product rather than a post.
class LabSetupCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const LabSetupCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = item['price_label'] as String? ?? '';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 178,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 1,
              child: ShowcaseCover(item: item),
            ),
          ),
          const SizedBox(height: 9),
          Text(item['title'] as String? ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
          if ((item['short_description'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(item['short_description'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11, height: 1.35, color: AppColors.textSecondary)),
          ],
          if (price.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(price,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ],
        ]),
      ),
    );
  }
}

/// Section heading with a View All on the right, matching the existing rows.
class ShowcaseHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onViewAll;
  const ShowcaseHeader({
    super.key,
    required this.title,
    this.subtitle = '',
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Container(
            width: 3.5,
            height: 20,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title,
                  style: GoogleFonts.poppins(
                      fontSize: 16.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              if (subtitle.isNotEmpty)
                Text(subtitle,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppColors.textSecondary)),
            ]),
          ),
          if (onViewAll != null)
            TextButton(
              onPressed: onViewAll,
              child: Text('View All',
                  style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary)),
            ),
        ]),
      );
}

/// Where someone ended up after doing this. The one thing a student and a
/// parent both look for, and the hardest to fake convincingly — which is
/// exactly why it is worth showing when it is real.
class PlacementCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const PlacementCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final attrs = (item['attributes'] as Map?) ?? {};
    final company = '${attrs['company'] ?? ''}';
    final role = '${attrs['role'] ?? ''}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(26),
              child: SizedBox(
                  width: 46, height: 46, child: ShowcaseCover(item: item)),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(item['title'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                if (role.isNotEmpty)
                  Text(role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 11.5, color: AppColors.textSecondary)),
              ]),
            ),
          ]),
          if (company.isNotEmpty) ...[
            const SizedBox(height: 11),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D32).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.work_rounded, size: 13, color: Color(0xFF2E7D32)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF1B5E20))),
                ),
              ]),
            ),
          ],
          if ((item['short_description'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(item['short_description'] as String,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 12, height: 1.45, color: AppColors.textSecondary)),
          ],
        ]),
      ),
    );
  }
}

/// A review in the student's own words. Their sentence converts better than
/// anything written for them, so it is shown whole rather than trimmed to a
/// pull-quote.
class ReviewCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  const ReviewCard({super.key, required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final attrs = (item['attributes'] as Map?) ?? {};
    final rating = int.tryParse('${attrs['rating'] ?? ''}') ?? 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (rating > 0)
            Row(children: [
              for (var i = 0; i < 5; i++)
                Icon(i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 16, color: const Color(0xFFFFA000)),
            ]),
          const SizedBox(height: 9),
          Text(
              '"${item['short_description'] as String? ?? item['body'] as String? ?? ''}"',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.55, color: AppColors.textPrimary)),
          const SizedBox(height: 12),
          Row(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                  width: 32, height: 32, child: ShowcaseCover(item: item)),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(item['title'] as String? ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                      fontSize: 12.5, fontWeight: FontWeight.w600)),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// A horizontal strip that scrolls itself.
///
/// One section instead of three saves the page a lot of height, but a strip
/// nobody swipes only ever shows its first two cards — so it drifts on its
/// own. It stops the moment a finger touches it and does not start again:
/// fighting someone who is reading is worse than never having moved.
class AutoScrollStrip extends StatefulWidget {
  final double height;
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  const AutoScrollStrip({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<AutoScrollStrip> createState() => _AutoScrollStripState();
}

class _AutoScrollStripState extends State<AutoScrollStrip> {
  final _controller = ScrollController();
  Timer? _timer;
  bool _stopped = false;

  @override
  void initState() {
    super.initState();
    if (widget.itemCount > 1) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _step());
    }
  }

  void _step() {
    if (_stopped || !_controller.hasClients) return;
    final max = _controller.position.maxScrollExtent;
    if (max <= 0) return;
    // Back to the start once the end is reached, so the strip keeps offering
    // something rather than sitting on its last card forever.
    final next = _controller.offset >= max - 8 ? 0.0 : _controller.offset + 170;
    _controller.animateTo(
      next.clamp(0.0, max),
      duration: Duration(milliseconds: next == 0 ? 700 : 550),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        height: widget.height,
        child: NotificationListener<ScrollStartNotification>(
          onNotification: (n) {
            if (n.dragDetails != null) {
              _stopped = true;
              _timer?.cancel();
            }
            return false;
          },
          child: ListView.separated(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: widget.itemCount,
            separatorBuilder: (_, __) => const SizedBox(width: 11),
            itemBuilder: widget.itemBuilder,
          ),
        ),
      );
}
