// The View All and detail pages behind Top Stories and Lab Setups.
//
// Same data, two presentations: stories read like an album of moments, lab
// setups read like a catalogue of things you can buy. The detail page serves
// both — a story opens as a full read with all its media, a lab setup opens as
// a product page with the same media and a price.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';
import '../../widgets/showcase_widgets.dart';

/// Grid of every published item of one kind.
class ShowcaseAlbumScreen extends StatefulWidget {
  final String kind;
  const ShowcaseAlbumScreen({super.key, required this.kind});

  @override
  State<ShowcaseAlbumScreen> createState() => _ShowcaseAlbumScreenState();
}

class _ShowcaseAlbumScreenState extends State<ShowcaseAlbumScreen> {
  List<dynamic> _items = [];
  bool _loading = true;

  bool get _isLab => widget.kind == 'lab_setup';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      _items = await ApiService.getShowcase(widget.kind);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final columns = width > 1100
        ? 4
        : width > 760
            ? 3
            : 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_isLab ? 'Lab Setups' : 'Top Stories',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _Empty(
                  icon: _isLab ? Icons.science_outlined : Icons.auto_stories_outlined,
                  message: _isLab
                      ? 'Lab setups are being added.'
                      : 'Stories are being added.')
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      // Lab setups are square with a price under them; stories
                      // are portrait, so they need the taller cell.
                      childAspectRatio: _isLab ? 0.72 : 0.62,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) {
                      final item = _items[i] as Map<String, dynamic>;
                      return _AlbumTile(
                        item: item,
                        square: _isLab,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => ShowcaseDetailScreen(item: item)),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _AlbumTile extends StatelessWidget {
  final Map<String, dynamic> item;
  final bool square;
  final VoidCallback onTap;
  const _AlbumTile({required this.item, required this.square, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final price = item['price_label'] as String? ?? '';
    final count = (item['media_count'] as int?) ?? 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              ShowcaseCover(item: item),
              if (count > 1)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.collections_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 3),
                      Text('$count',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Text(item['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        if ((item['short_description'] as String? ?? '').isNotEmpty)
          Text(item['short_description'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                  fontSize: 11, height: 1.3, color: AppColors.textSecondary)),
        if (price.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(price,
                style: GoogleFonts.poppins(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
      ]),
    );
  }
}

/// The full item — every photo and video, the body text, and its CTA.
class ShowcaseDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ShowcaseDetailScreen({super.key, required this.item});

  @override
  State<ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<ShowcaseDetailScreen> {
  late Map<String, dynamic> _item = widget.item;
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// The list endpoint already carries media, so the page renders immediately;
  /// this only fills in a longer body if the list was trimmed.
  Future<void> _refresh() async {
    try {
      final full = await ApiService.getShowcaseItem(_item['id'] as int);
      if (mounted) setState(() => _item = full);
    } catch (_) {}
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCta() async {
    final url = _item['cta_url'] as String? ?? '';
    if (url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Could not open that link')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = (_item['media'] as List?) ?? [];
    final price = _item['price_label'] as String? ?? '';
    final ctaLabel = _item['cta_label'] as String? ?? '';
    final body = _item['body'] as String? ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(_item['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        if (media.isNotEmpty)
          SizedBox(
            height: 320,
            child: Stack(children: [
              PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                itemCount: media.length,
                itemBuilder: (context, i) {
                  final m = media[i] as Map<String, dynamic>;
                  return _MediaSlide(media: m);
                },
              ),
              if (media.length > 1)
                Positioned(
                  bottom: 12,
                  left: 0,
                  right: 0,
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    for (var i = 0; i < media.length; i++)
                      Container(
                        width: _page == i ? 18 : 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: BoxDecoration(
                          color: _page == i ? Colors.white : Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ]),
                ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_item['title'] as String? ?? '',
                style: GoogleFonts.poppins(
                    fontSize: 20, fontWeight: FontWeight.w700, height: 1.25)),
            if ((_item['short_description'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(_item['short_description'] as String,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.5, color: AppColors.textSecondary)),
            ],
            if (price.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(price,
                    style: GoogleFonts.poppins(
                        fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.primary)),
              ),
            ],
            if (body.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(body,
                  style: GoogleFonts.inter(
                      fontSize: 14, height: 1.65, color: AppColors.textPrimary)),
            ],
            if (ctaLabel.isNotEmpty && (_item['cta_url'] as String? ?? '').isNotEmpty) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _openCta,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(ctaLabel,
                      style: GoogleFonts.poppins(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
            const SizedBox(height: 30),
          ]),
        ),
      ]),
    );
  }
}

/// One slide. A video opens YouTube rather than embedding a player — an
/// inline player on web needs an iframe per slide, and a Short plays better in
/// the app the viewer already has.
class _MediaSlide extends StatelessWidget {
  final Map<String, dynamic> media;
  const _MediaSlide({required this.media});

  @override
  Widget build(BuildContext context) {
    final isVideo = media['media_type'] == 'youtube';
    final url = media['thumbnail_url'] as String? ?? '';
    final caption = media['caption'] as String? ?? '';

    return GestureDetector(
      onTap: isVideo
          ? () {
              final id = media['youtube_id'] as String? ?? '';
              if (id.isEmpty) return;
              launchUrl(Uri.parse('https://www.youtube.com/watch?v=$id'),
                  mode: LaunchMode.externalApplication);
            }
          : null,
      child: Container(
        color: Colors.black,
        child: Stack(fit: StackFit.expand, children: [
          if (url.isNotEmpty)
            Image.network(url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                    color: Colors.white38, size: 40)),
          if (isVideo)
            Center(
              child: Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 38),
              ),
            ),
          if (caption.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 30),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
                  ),
                ),
                child: Text(caption,
                    style: GoogleFonts.inter(
                        color: Colors.white, fontSize: 12.5, height: 1.4)),
              ),
            ),
        ]),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String message;
  const _Empty({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 46, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: 12),
          Text(message,
              style: GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 13.5)),
        ]),
      );
}
