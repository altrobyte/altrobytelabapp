import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/api_service.dart';

/// What is currently broken, and how often.
///
/// One row per distinct failure with a count, so a single broken endpoint hit
/// four hundred times does not bury the other three things that are also
/// wrong.
class ErrorsScreen extends StatefulWidget {
  const ErrorsScreen({super.key});

  @override
  State<ErrorsScreen> createState() => _ErrorsScreenState();
}

class _ErrorsScreenState extends State<ErrorsScreen> {
  List<dynamic> _rows = [];
  bool _loading = true;
  bool _includeResolved = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final r = await ApiService.getErrors(includeResolved: _includeResolved);
      if (mounted) setState(() { _rows = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _resolve(int id) async {
    try {
      await ApiService.resolveError(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not resolve: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: Text('Errors',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0B2450),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 21),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(children: [
            for (final t in const [(false, 'Open'), (true, 'All')])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(t.$2, style: GoogleFonts.inter(fontSize: 12.5)),
                  selected: _includeResolved == t.$1,
                  onSelected: (_) {
                    setState(() => _includeResolved = t.$1);
                    _load();
                  },
                ),
              ),
            const Spacer(),
            Text('${_rows.length}',
                style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF12326B))),
          ]),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error, textAlign: TextAlign.center)))
                  : _rows.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check_circle_outline_rounded,
                                      size: 42, color: Color(0xFF2E7D32)),
                                  const SizedBox(height: 12),
                                  Text('Nothing broken',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0B2450))),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Failures on the server and in the app both '
                                    'land here, with a count, as they happen.',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        height: 1.5,
                                        color: const Color(0xFF5A6B82)),
                                  ),
                                ]),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(14),
                            itemCount: _rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) =>
                                _row(_rows[i] as Map<String, dynamic>),
                          ),
                        ),
        ),
      ]),
    );
  }

  Widget _row(Map<String, dynamic> e) {
    final count = (e['count'] as int?) ?? 1;
    final resolved = e['resolved'] == true;
    final isApp = '${e['source']}' == 'app';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: resolved ? const Color(0xFFE6EBF3) : const Color(0xFFFFCDD2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: (isApp ? const Color(0xFF6A1B9A) : const Color(0xFF12326B))
                  .withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(isApp ? 'app' : 'server',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: isApp
                        ? const Color(0xFF6A1B9A)
                        : const Color(0xFF12326B))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${e['where_at']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF5A6B82))),
          ),
          // The count is the difference between a one-off and an outage.
          if (count > 1)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFC62828).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('×$count',
                  style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFFC62828))),
            ),
        ]),
        const SizedBox(height: 8),
        Text('${e['kind']}',
            style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF0B2450))),
        const SizedBox(height: 3),
        Text('${e['message']}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
                fontSize: 12, height: 1.45, color: const Color(0xFF5A6B82))),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if ('${e['detail'] ?? ''}'.isNotEmpty)
            _act(Icons.notes_rounded, 'Stack', () => _showDetail(e)),
          _act(Icons.copy_rounded, 'Copy', () {
            Clipboard.setData(ClipboardData(
                text: '${e['where_at']}\n${e['kind']}: ${e['message']}\n\n'
                    '${e['detail'] ?? ''}'));
            ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied')));
          }),
          if (!resolved)
            _act(Icons.check_rounded, 'Resolve',
                () => _resolve(e['id'] as int)),
        ]),
      ]),
    );
  }

  void _showDetail(Map<String, dynamic> e) => showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (_, controller) => Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(controller: controller, children: [
              Text('${e['kind']}',
                  style: GoogleFonts.poppins(
                      fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${e['where_at']}',
                  style: GoogleFonts.inter(
                      fontSize: 12, color: const Color(0xFF5A6B82))),
              const SizedBox(height: 12),
              SelectableText('${e['detail'] ?? ''}',
                  style: const TextStyle(
                      fontSize: 11, height: 1.5, fontFamily: 'monospace')),
            ]),
          ),
        ),
      );

  Widget _act(IconData icon, String label, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F4F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 14, color: const Color(0xFF12326B)),
            const SizedBox(width: 5),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF12326B))),
          ]),
        ),
      );
}
