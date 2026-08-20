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
      // The strip mixes kinds, so View All has to as well — otherwise a
      // placement seen on the homepage vanishes when you tap through to
      // "see all".
      if (widget.kind == 'story') {
        for (final k in const ['placement', 'review']) {
          try {
            _items = [...await ApiService.getShowcase(k), ..._items];
          } catch (_) {}
        }
      }
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
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(
            switch (widget.kind) {
              'lab_setup' => 'Lab Setups',
              'placement' => 'Where our students are now',
              'review' => 'What students say',
              _ => 'Top Stories',
            },
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? _Empty(
                  icon: _isLab ? Icons.science_outlined : Icons.auto_stories_outlined,
                  message: switch (widget.kind) {
                    'lab_setup' => 'Lab setups are being added.',
                    'placement' => 'Placements are being added.',
                    'review' => 'Reviews are being added.',
                    _ => 'Stories are being added.',
                  })
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(14),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                      // Lab setups are square with a price under them.
                      // Everything else is a portrait poster, and a poster
                      // wants the proportion it was designed at — cropping one
                      // to a square cuts the name off the bottom.
                      childAspectRatio: _isLab ? 0.72 : 0.66,
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
    final attrs = (item['attributes'] as Map?) ?? {};
    final company = '${attrs['company'] ?? ''}';
    final rating = int.tryParse('${attrs['rating'] ?? ''}') ?? 0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(fit: StackFit.expand, children: [
              ShowcaseCover(item: item),
              if (company.isNotEmpty)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.work_rounded, size: 11, color: Colors.white),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 110),
                        child: Text(company,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ]),
                  ),
                )
              else if (rating > 0)
                Positioned(
                  top: 8,
                  left: 8,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    for (var i = 0; i < rating.clamp(0, 5); i++)
                      const Icon(Icons.star_rounded,
                          size: 13, color: Color(0xFFFFC107)),
                  ]),
                ),
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
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text(_item['title'] as String? ?? '',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
      ),
      body: ListView(padding: EdgeInsets.zero, children: [
        if (media.isNotEmpty)
          SizedBox(
            // Tall enough for a portrait poster to be readable. At 320 a 4:5
            // congratulations poster shrank to a stamp between two black bars
            // that took up more of the screen than it did.
            height: MediaQuery.of(context).size.height * 0.62,
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
              _BodyRenderer(body: body),
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
        // A poster on black is a poster in a cinema. These are shared to
        // WhatsApp and read on a phone; a light ground sits with the page
        // instead of punching a hole in it.
        color: const Color(0xFFF2F4F8),
        child: Stack(fit: StackFit.expand, children: [
          if (url.isNotEmpty)
            // 800 is plenty for a poster read at arm's length on a phone, and
            // it is a twentieth of what these files weigh whole.
            Image.network(
                url.contains('/uploads/image/')
                    ? (url.contains('?') ? '$url&w=800' : '$url?w=800')
                    : url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined,
                    color: Colors.black26, size: 40)),
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

/// Renders the admin's body text as a product page rather than a wall of text.
///
/// Admins write plain text; asking them for structured spec rows would mean a
/// second editor and a schema for something they can already type. So the
/// shape is inferred:
///
///   "• Name — 2 pcs"   a spec row: name left, quantity right-aligned
///   "Heading"          a section heading (a short line before bullets)
///   anything else      a paragraph
///
/// Space-aligned columns were the first attempt at this and they only line up
/// in a monospace font; the page uses a proportional one, so every quantity
/// landed in a different place.
class _BodyRenderer extends StatelessWidget {
  final String body;
  const _BodyRenderer({required this.body});

  // Greedy on the name so the split happens at the LAST separator, not the
  // first: "LEDs — Red, Green, Yellow — 1 each" is one component whose name
  // contains a dash, and a non-greedy match read it as a component called
  // "LEDs" with a quantity of "Red, Green, Yellow — 1 each".
  static final _specLine = RegExp(r'^\s*[•\-\*]\s*(.+)\s+[—–-]\s+(.+)$');

  /// The other way people write a parts list: name, a run of spaces, quantity.
  ///
  /// This is what a list pasted from a spec sheet looks like, and it is what
  /// the first version of this renderer missed entirely — it only understood
  /// bulleted lines, so an existing list changed not at all and looked exactly
  /// as broken as before. The quantity must be short and contain a digit, so a
  /// sentence that happens to hold a double space is not turned into a row.
  static final _columnLine = RegExp(r'^\s*(\S.*?\S)\s{2,}(\d[\w. ]{0,11})\s*$');

  @override
  Widget build(BuildContext context) {
    final lines = body.split('\n');
    final out = <Widget>[];

    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final line = raw.trim();

      if (line.isEmpty) {
        out.add(const SizedBox(height: 14));
        continue;
      }

      final spec = _specLine.firstMatch(raw) ?? _columnLine.firstMatch(raw);
      if (spec != null) {
        out.add(_SpecRow(name: spec.group(1)!.trim(), qty: spec.group(2)!.trim()));
        continue;
      }

      // A short line immediately followed by bullets is a group heading. This
      // is what keeps "Sensors & display" from rendering as a sentence.
      final next = i + 1 < lines.length ? lines[i + 1] : '';
      final headsAList = _specLine.hasMatch(next) ||
          _columnLine.hasMatch(next) ||
          next.trimLeft().startsWith('•') ||
          next.trimLeft().startsWith('-');
      if (headsAList && line.length <= 48) {
        out.add(Padding(
          padding: EdgeInsets.only(top: out.isEmpty ? 0 : 6, bottom: 6),
          child: Text(line.toUpperCase(),
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: AppColors.primary)),
        ));
        continue;
      }

      // A bullet with no quantity is still a bullet.
      if (line.startsWith('•') || line.startsWith('- ')) {
        out.add(Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 9),
              child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.textSecondary, shape: BoxShape.circle)),
            ),
            Expanded(
              child: Text(line.replaceFirst(RegExp(r'^[•\-]\s*'), ''),
                  style: GoogleFonts.inter(
                      fontSize: 13.5, height: 1.5, color: AppColors.textPrimary)),
            ),
          ]),
        ));
        continue;
      }

      out.add(Text(line,
          style: GoogleFonts.inter(
              fontSize: 14, height: 1.65, color: AppColors.textPrimary)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: out);
  }
}

/// One component: name on the left, quantity pinned right so a column of them
/// lines up regardless of how long the names are.
class _SpecRow extends StatelessWidget {
  final String name;
  final String qty;
  const _SpecRow({required this.name, required this.qty});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          border: Border(
              bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
        ),
        child: Row(children: [
          Expanded(
            child: Text(name,
                style: GoogleFonts.inter(
                    fontSize: 13.5, height: 1.35, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(qty,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
        ]),
      );
}
