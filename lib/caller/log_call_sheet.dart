// "Log this call": opened by itself when a call ends, already filled in from the phone (how long, whether anyone
// picked up). Everything is a tap; the usual log is one tap on Save.

import 'package:flutter/material.dart';

import '../constants/app_colors.dart';
import 'caller_native.dart';
import 'models.dart';
import 'widgets.dart';

/// The follow-up chips, worked out from [now] in the phone's own time zone.
Map<String, DateTime?> followupChoices(DateTime now) {
  final l = now.toLocal();
  DateTime at11(int days) => DateTime(l.year, l.month, l.day + days, 11);
  return {
    'In 2 h': l.add(const Duration(hours: 2)),
    'Tomorrow 11 am': at11(1),
    'In 3 days': at11(3),
    'None': null,
  };
}

/// The follow-up a caller would pick anyway: try again soon when nobody answered, tomorrow when they asked for a call
/// back, nothing otherwise.
String defaultFollowup(String outcome) {
  if (unanswered.contains(outcome)) return 'In 2 h';
  if (outcome == 'call_back') return 'Tomorrow 11 am';
  return 'None';
}

class LogCallSheet extends StatefulWidget {
  final Lead lead;
  final CallEnded? call;
  final bool isNew;
  final List<String> labels;
  final List<Map<String, dynamic>> quickMessages;
  final DateTime now;
  final String Function() newId;
  final Future<String> Function(String kind)? onQuickWa;
  final Future<String?> Function()? onSpeech;

  const LogCallSheet({
    super.key,
    required this.lead,
    required this.labels,
    required this.now,
    required this.newId,
    this.call,
    this.isNew = false,
    this.quickMessages = const [],
    this.onQuickWa,
    this.onSpeech,
  });

  @override
  State<LogCallSheet> createState() => _LogCallSheetState();
}

class _LogCallSheetState extends State<LogCallSheet> {
  String? _outcome;
  String _interest = '';
  late String _stage;
  String _lostReason = '';
  late Set<String> _labels;
  late Map<String, DateTime?> _choices;
  String _followup = 'None';
  DateTime? _picked;
  bool _stageTouched = false, _followupTouched = false;
  final _note = TextEditingController();
  final _name = TextEditingController();
  String? _waSaid;

  @override
  void initState() {
    super.initState();
    _choices = followupChoices(widget.now);
    _stage = widget.lead.stage;
    _labels = {...widget.lead.labels};
    final c = widget.call;
    _name.text = c?.typedName.isNotEmpty == true ? c!.typedName : (widget.isNew ? widget.lead.name : '');
    if (c != null && c.known) _pickOutcome(c.connected ? 'connected' : 'no_answer');
    // The choice tapped on the after-call card.
    switch (c?.preset) {
      case 'interested':
        _pickOutcome('connected');
        _interest = 'hot';
        if (!_stageTouched && const {'new', 'contacted'}.contains(widget.lead.stage)) _stage = 'interested';
      case 'call_back':
        _pickOutcome('call_back');
      case 'not_interested':
        _pickOutcome(_outcome ?? 'connected');
        _interest = 'not_interested';
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _name.dispose();
    super.dispose();
  }

  void _pickOutcome(String o) {
    _outcome = o;
    if (!_followupTouched) _followup = defaultFollowup(o);
    if (!_stageTouched) {
      _stage = o == 'connected' && widget.lead.stage == 'new' ? 'contacted' : widget.lead.stage;
    }
  }

  bool get _canSave => _outcome != null && (_stage != 'lost' || _lostReason.isNotEmpty);

  DateTime? get _followupAt => _followup == 'Pick a date' ? _picked : _choices[_followup];

  Future<void> _pickDate() async {
    final l = widget.now.toLocal();
    final d = await showDatePicker(
        context: context, initialDate: l.add(const Duration(days: 1)), firstDate: l, lastDate: l.add(const Duration(days: 365)));
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 11, minute: 0));
    if (!mounted) return;
    setState(() {
      _followupTouched = true;
      _followup = 'Pick a date';
      _picked = DateTime(d.year, d.month, d.day, t?.hour ?? 11, t?.minute ?? 0);
    });
  }

  void _save() {
    final c = widget.call;
    final log = CallLog(
      clientId: widget.newId(),
      phone: widget.lead.phone,
      startedAt: (c?.startedAt ?? widget.now).toUtc(),
      durationS: c?.durationS ?? 0,
      direction: c?.type == 'in' ? 'in' : 'out',
      outcome: _outcome!,
      interest: _interest,
      stage: _stage == widget.lead.stage ? '' : _stage,
      lostReason: _stage == 'lost' ? _lostReason : '',
      labels: _sameLabels ? null : _labels.toList(),
      nextFollowupAt: _followupAt?.toUtc(),
      note: _note.text.trim(),
      name: _name.text.trim(),
    );
    Navigator.of(context).pop(log);
  }

  bool get _sameLabels =>
      _labels.length == widget.lead.labels.length && _labels.every(widget.lead.labels.contains);

  Widget _title(String t) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 6),
        child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      );

  Widget _chips(Map<String, String> options, String? selected, void Function(String) onTap, {String prefix = ''}) =>
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in options.entries)
          ChoiceChip(
            key: ValueKey('$prefix${e.key}'),
            label: Text(e.value),
            selected: selected == e.key,
            onSelected: (_) => setState(() => onTap(e.key)),
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final c = widget.call;
    final lead = widget.lead;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.isNew ? 'Add as a lead?' : 'Log this call',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  Text(lead.displayName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                  if (c != null)
                    Text(
                        '${c.type == 'in' ? 'They called' : 'You called'} · '
                        '${!c.known ? 'how did it go?' : c.connected ? 'talked ${duration(c.durationS)}' : 'not picked up'}',
                        key: const ValueKey('call_summary'),
                        style: const TextStyle(color: AppColors.textSecondary)),
                ]),
              ),
              if (!widget.isNew) HeatBadge(lead.heat, converted: lead.converted),
            ]),
            if (widget.isNew || widget.lead.name.trim().isEmpty) ...[
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Their name (you can leave it)', border: OutlineInputBorder()),
              ),
            ],
            _title('What happened'),
            _chips(outcomes, _outcome, _pickOutcome, prefix: 'outcome_'),
            _title('How interested'),
            _chips(interests, _interest, (k) => _interest = _interest == k ? '' : k, prefix: 'interest_'),
            _title('Stage'),
            _chips(stages, _stage, (k) {
              _stageTouched = true;
              _stage = k;
            }, prefix: 'stage_'),
            if (_stage == 'lost') ...[
              _title('Why lost'),
              _chips({for (final r in lostReasons) r: r}, _lostReason, (k) => _lostReason = k, prefix: 'lost_'),
            ],
            if (widget.labels.isNotEmpty) ...[
              _title('Labels'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final l in widget.labels)
                  FilterChip(
                    key: ValueKey('label_$l'),
                    label: Text(l),
                    selected: _labels.contains(l),
                    onSelected: (on) => setState(() => on ? _labels.add(l) : _labels.remove(l)),
                  ),
              ]),
            ],
            _title('Next follow-up'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final k in _choices.keys)
                ChoiceChip(
                  key: ValueKey('follow_$k'),
                  label: Text(k),
                  selected: _followup == k,
                  onSelected: (_) => setState(() {
                    _followupTouched = true;
                    _followup = k;
                  }),
                ),
              ChoiceChip(
                key: const ValueKey('follow_pick'),
                label: Text(_followup == 'Pick a date' && _picked != null ? _pickedText : 'Pick a date'),
                selected: _followup == 'Pick a date',
                onSelected: (_) => _pickDate(),
              ),
            ]),
            _title('Note'),
            TextField(
              key: const ValueKey('note'),
              controller: _note,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Optional',
                border: const OutlineInputBorder(),
                suffixIcon: widget.onSpeech == null
                    ? null
                    : IconButton(
                        tooltip: 'Speak the note',
                        icon: const Icon(Icons.mic),
                        onPressed: () async {
                          final said = await widget.onSpeech!();
                          if (said != null && said.trim().isNotEmpty && mounted) {
                            setState(() => _note.text = [_note.text.trim(), said.trim()].where((s) => s.isNotEmpty).join(' '));
                          }
                        },
                      ),
              ),
            ),
            if (widget.onQuickWa != null && !widget.isNew && widget.quickMessages.isNotEmpty) ...[
              _title('Quick WhatsApp'),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final m in widget.quickMessages)
                  ActionChip(
                    key: ValueKey('wa_${m['kind']}'),
                    avatar: const Icon(Icons.chat, size: 16, color: AppColors.whatsapp),
                    label: Text(_waLabel('${m['kind']}')),
                    tooltip: '${m['text'] ?? ''}',
                    onPressed: () async {
                      final said = await widget.onQuickWa!('${m['kind']}');
                      if (mounted) setState(() => _waSaid = said);
                    },
                  ),
              ]),
              if (_waSaid != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(_waSaid!, style: const TextStyle(color: AppColors.textSecondary)),
                ),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                key: const ValueKey('save'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
                onPressed: _canSave ? _save : null,
                child: Text(_stage == 'lost' && _lostReason.isEmpty ? 'Pick why it was lost' : 'Save',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String get _pickedText {
    final p = _picked!;
    final h = p.hour % 12 == 0 ? 12 : p.hour % 12;
    return '${p.day}/${p.month}, $h:${p.minute.toString().padLeft(2, '0')} ${p.hour < 12 ? 'am' : 'pm'}';
  }

  static String _waLabel(String kind) =>
      const {'missed_call': 'Tried calling you', 'roadmap': 'Send roadmap', 'thanks': 'Thanks for your time'}[kind] ?? kind;
}

/// Opens the sheet; resolves to the log, or null when the caller swiped it away.
Future<CallLog?> showLogCallSheet(BuildContext context, LogCallSheet sheet) => showModalBottomSheet<CallLog>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.cardBg,
      builder: (_) => FractionallySizedBox(heightFactor: 0.92, child: sheet),
    );
