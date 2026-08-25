import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/api_service.dart';

/// Six questions that tell a reader where they stand on the roadmap.
///
/// The roadmap lists 165 things. That answers "what is covered" and not the
/// two questions somebody actually arrives with — am I behind, and where
/// would I start. This asks those, and the answer is the argument for the
/// roadmap that the list itself was never making.
///
/// One question at a time, on purpose. Six at once is a form; one at a time
/// is a conversation, and a reader will finish a conversation.
class PlacementTestSheet extends StatefulWidget {
  /// Offered at the end, since somebody who just saw a gap is the person
  /// most worth talking to.
  final VoidCallback? onTalkToUs;
  const PlacementTestSheet({super.key, this.onTalkToUs});

  static Future<void> show(BuildContext context, {VoidCallback? onTalkToUs}) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PlacementTestSheet(onTalkToUs: onTalkToUs),
      );

  @override
  State<PlacementTestSheet> createState() => _PlacementTestSheetState();
}

class _PlacementTestSheetState extends State<PlacementTestSheet> {
  List<dynamic> _questions = [];
  final Set<String> _yes = {};
  int _at = 0;
  bool _loading = true;
  bool _sending = false;
  String _error = '';
  Map<String, dynamic>? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await ApiService.getPlacementQuestions();
      if (mounted) setState(() { _questions = r; _loading = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : 'Could not load. $e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _answer(bool yes) async {
    final q = _questions[_at] as Map<String, dynamic>;
    if (yes) _yes.add('${q['id']}');
    if (_at < _questions.length - 1) {
      setState(() => _at++);
      return;
    }
    setState(() => _sending = true);
    try {
      final r = await ApiService.getPlacementResult(_yes.toList());
      if (mounted) setState(() { _result = r; _sending = false; });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is ApiException ? e.message : '$e';
          _sending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 22),
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: _loading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()))
                : _error.isNotEmpty
                    ? _errorBox()
                    : _result != null
                        ? _resultView()
                        : _questionView(),
          ),
        ),
      );

  Widget _grab() => Center(
        child: Container(
          width: 38,
          height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
              color: const Color(0xFFD7DEE8),
              borderRadius: BorderRadius.circular(2)),
        ),
      );

  Widget _errorBox() => Column(mainAxisSize: MainAxisSize.min, children: [
        _grab(),
        const Icon(Icons.error_outline_rounded, size: 38, color: Color(0xFFC62828)),
        const SizedBox(height: 10),
        Text(_error,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12.5, height: 1.5)),
      ]);

  Widget _questionView() {
    final q = _questions[_at] as Map<String, dynamic>;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _grab(),
          Row(children: [
            Text('WHERE DO YOU STAND',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: const Color(0xFF9AA5B5))),
            const Spacer(),
            Text('${_at + 1} of ${_questions.length}',
                style: GoogleFonts.inter(
                    fontSize: 11, color: const Color(0xFF9AA5B5))),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: (_at + 1) / _questions.length,
              minHeight: 4,
              backgroundColor: const Color(0xFFE1E7F0),
              valueColor: const AlwaysStoppedAnimation(Color(0xFF12326B)),
            ),
          ),
          const SizedBox(height: 20),
          Text('${q['text']}',
              style: GoogleFonts.poppins(
                  fontSize: 17,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF0B2450))),
          if ('${q['why'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F4F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('${q['why']}',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      height: 1.5,
                      color: const Color(0xFF5A6B82))),
            ),
          ],
          const SizedBox(height: 22),
          if (_sending)
            const Center(child: CircularProgressIndicator())
          else
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _answer(false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Not yet',
                      style: GoogleFonts.poppins(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _answer(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF12326B),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Yes, done that',
                      style: GoogleFonts.poppins(
                          fontSize: 14.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
          const SizedBox(height: 10),
          Center(
            child: Text('Nothing is scored or saved.',
                style: GoogleFonts.inter(
                    fontSize: 10.5, color: const Color(0xFF9AA5B5))),
          ),
        ]);
  }

  Widget _resultView() {
    final r = _result!;
    final gaps = (r['gaps'] as List?) ?? [];
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _grab(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF12326B),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text('START AT STAGE ${r['start_stage']}',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Colors.white)),
          ),
          const SizedBox(height: 12),
          Text('${r['headline']}',
              style: GoogleFonts.poppins(
                  fontSize: 19,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0B2450))),
          const SizedBox(height: 8),
          Text('${r['detail']}',
              style: GoogleFonts.inter(
                  fontSize: 13, height: 1.6, color: const Color(0xFF5A6B82))),
          if (gaps.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('WHAT YOU HAVE NOT DONE YET',
                style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.9,
                    color: const Color(0xFFE65100))),
            const SizedBox(height: 8),
            for (final g in gaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(Icons.radio_button_unchecked_rounded,
                        size: 14, color: Color(0xFFE65100)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${(g as Map)['text']}',
                              style: GoogleFonts.inter(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF0B2450))),
                          const SizedBox(height: 2),
                          Text('${g['why']}',
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.45,
                                  color: const Color(0xFF9AA5B5))),
                        ]),
                  ),
                ]),
              ),
          ],
          const SizedBox(height: 18),
          if (widget.onTalkToUs != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onTalkToUs!();
                },
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF12326B),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.phone_in_talk_rounded,
                    size: 18, color: Colors.white),
                label: Text('Talk about starting here',
                    style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Back to the roadmap',
                  style: GoogleFonts.inter(
                      fontSize: 12.5, color: const Color(0xFF5A6B82))),
            ),
          ),
        ]);
  }
}
