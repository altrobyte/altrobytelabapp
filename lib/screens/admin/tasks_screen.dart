// My tasks (14 Nov 2026, founder: "a task page for me and Jarvis, where I or Jarvis update tasks and Jarvis reminds me;
// I was using Google Tasks"). The same list Jarvis reads and writes by voice (list_tasks, add_task, update_task). A task
// with a time gets a WhatsApp reminder at that time (within the hour, never at night); the morning brief lists today's.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

DateTime? _parse(dynamic v) => v == null ? null : DateTime.tryParse('$v')?.toLocal();

/// "Today 11:00 AM", "Tomorrow 9:30 AM", "Sat 16 Nov, 10:00 AM".
String taskWhen(DateTime d, [DateTime? now]) {
  final n = now ?? DateTime.now();
  final day = DateTime(d.year, d.month, d.day), today = DateTime(n.year, n.month, n.day);
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12, m = d.minute.toString().padLeft(2, '0'), ap = d.hour < 12 ? 'AM' : 'PM';
  final time = '$h:$m $ap';
  final diff = day.difference(today).inDays;
  if (diff == 0) return 'Today $time';
  if (diff == 1) return 'Tomorrow $time';
  if (diff == -1) return 'Yesterday $time';
  const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  return '${wd[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}, $time';
}

/// What the server reads as India time: "2026-11-15T11:00".
String taskIso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  String _status = 'open';
  List<Map<String, dynamic>> _tasks = [];
  bool _loading = true;
  String? _error;
  final _title = TextEditingController();
  DateTime? _due;
  String _priority = 'normal';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await ApiService.founderTasks(_status);
      if (!mounted) return;
      setState(() { _tasks = [for (final t in (r['tasks'] as List? ?? [])) Map<String, dynamic>.from(t as Map)]; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Could not load the tasks. Check the connection and tap refresh.'; });
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<DateTime?> _pick(DateTime? start) async {
    final now = DateTime.now();
    final d = await showDatePicker(context: context, initialDate: start ?? now, firstDate: now.subtract(const Duration(days: 365)), lastDate: now.add(const Duration(days: 730)));
    if (d == null || !mounted) return null;
    final t = await showTimePicker(context: context, initialTime: start != null ? TimeOfDay.fromDateTime(start) : const TimeOfDay(hour: 10, minute: 0));
    if (t == null) return null;
    return DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  Future<void> _add() async {
    final title = _title.text.trim();
    if (title.length < 2 || _saving) return;
    setState(() => _saving = true);
    try {
      await ApiService.founderTaskAdd({'title': title, 'priority': _priority, if (_due != null) 'due_at': taskIso(_due!)});
      _title.clear();
      setState(() { _due = null; _priority = 'normal'; });
      await _load();
    } catch (e) {
      _toast('Could not add the task. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _patch(Map<String, dynamic> t, Map<String, dynamic> change, {String? done}) async {
    try {
      await ApiService.founderTaskPatch(t['id'] as int, change);
      if (done != null) _toast(done);
      await _load();
    } catch (e) {
      _toast('Could not save that. Try again.');
    }
  }

  Future<void> _edit(Map<String, dynamic> t) async {
    final title = TextEditingController(text: '${t['title'] ?? ''}');
    final notes = TextEditingController(text: '${t['notes'] ?? ''}');
    DateTime? due = _parse(t['due_at']);
    String pri = '${t['priority'] ?? 'normal'}';
    final change = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
        title: Text('Task #${t['id']}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Task')),
            const SizedBox(height: 8),
            TextField(controller: notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.alarm_rounded, size: 18),
                  label: Text(due == null ? 'Set time & reminder' : taskWhen(due!)),
                  onPressed: () async { final d = await _pick(due); if (d != null) set(() => due = d); },
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: pri,
                items: const [
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                ],
                onChanged: (v) => set(() => pri = v ?? 'normal'),
              ),
            ]),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, {'status': 'dropped'}), child: const Text('Drop task', style: TextStyle(color: Colors.red))),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'title': title.text.trim(), 'notes': notes.text, 'priority': pri,
              if (due != null && due != _parse(t['due_at'])) 'due_at': taskIso(due!),
            }),
            child: const Text('Save'),
          ),
        ],
      )),
    );
    title.dispose();
    notes.dispose();
    if (change != null) await _patch(t, change, done: change['status'] == 'dropped' ? 'Task dropped.' : 'Saved.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text('My tasks', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded), tooltip: 'Refresh')],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: ListView(padding: const EdgeInsets.all(16), children: [
            _addCard(),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'open', label: Text('To do'), icon: Icon(Icons.radio_button_unchecked_rounded)),
                ButtonSegment(value: 'done', label: Text('Done'), icon: Icon(Icons.check_circle_outline_rounded)),
                ButtonSegment(value: 'all', label: Text('All')),
              ],
              selected: {_status},
              onSelectionChanged: (s) { setState(() => _status = s.first); _load(); },
            ),
            const SizedBox(height: 10),
            if (_loading) const Padding(padding: EdgeInsets.all(30), child: Center(child: CircularProgressIndicator())),
            if (_error != null) Padding(padding: const EdgeInsets.all(20), child: Text(_error!, style: GoogleFonts.inter(color: Colors.red.shade700))),
            if (!_loading && _error == null && _tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(30),
                child: Text(_status == 'open' ? 'Nothing pending. Add a task above, or tell Jarvis: "kal 11 baje yaad dilana ki …"' : 'No tasks here yet.',
                    textAlign: TextAlign.center, style: GoogleFonts.inter(color: AppColors.textSecondary)),
              ),
            if (!_loading) for (final t in _tasks) _taskTile(t),
            const SizedBox(height: 10),
            Text('Jarvis sees this list too: ask "aaj kya pending hai?", "task bana do …", "#12 ho gaya". '
                'A task with a time sends you a WhatsApp reminder then (within the hour, never at night).',
                style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          ]),
        ),
      ),
    );
  }

  Widget _addCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
      child: Column(children: [
        TextField(
          controller: _title,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _add(),
          decoration: const InputDecoration(hintText: 'Add a task…', border: InputBorder.none, prefixIcon: Icon(Icons.add_task_rounded)),
        ),
        Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          ActionChip(
            avatar: const Icon(Icons.alarm_rounded, size: 18),
            label: Text(_due == null ? 'Time & reminder' : taskWhen(_due!)),
            onPressed: () async { final d = await _pick(_due); if (d != null) setState(() => _due = d); },
          ),
          if (_due != null) IconButton(onPressed: () => setState(() => _due = null), icon: const Icon(Icons.close_rounded, size: 18), tooltip: 'No time'),
          ChoiceChip(label: const Text('High'), selected: _priority == 'high', onSelected: (v) => setState(() => _priority = v ? 'high' : 'normal')),
          const SizedBox(width: 6),
          FilledButton(onPressed: _saving ? null : _add, child: Text(_saving ? 'Adding…' : 'Add')),
        ]),
      ]),
    );
  }

  Widget _taskTile(Map<String, dynamic> t) {
    final done = t['status'] == 'done', dropped = t['status'] == 'dropped';
    final due = _parse(t['due_at']);
    final late = due != null && !done && !dropped && due.isBefore(DateTime.now());
    final high = t['priority'] == 'high';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: late ? Colors.red.shade200 : Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () => _edit(t),
        leading: Checkbox(
          value: done,
          onChanged: dropped ? null : (v) => _patch(t, {'status': v == true ? 'done' : 'open'}, done: v == true ? 'Done ✓' : null),
        ),
        title: Text('${t['title']}',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600, fontSize: 14.5,
              decoration: done || dropped ? TextDecoration.lineThrough : null,
              color: done || dropped ? AppColors.textSecondary : null,
            )),
        subtitle: Wrap(spacing: 8, runSpacing: 2, children: [
          if (due != null) Text('⏰ ${taskWhen(due)}${late ? '  · overdue' : ''}', style: GoogleFonts.inter(fontSize: 12, color: late ? Colors.red.shade700 : AppColors.textSecondary)),
          if (high) Text('● High', style: GoogleFonts.inter(fontSize: 12, color: Colors.orange.shade800, fontWeight: FontWeight.w600)),
          if (t['created_by'] == 'Jarvis') Text('🎙 by Jarvis', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          if (dropped) Text('dropped', style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
          if ('${t['notes'] ?? ''}'.trim().isNotEmpty) Text('${t['notes']}'.trim(), maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
        ]),
        trailing: Text('#${t['id']}', style: GoogleFonts.robotoMono(fontSize: 11.5, color: AppColors.textSecondary)),
      ),
    );
  }
}
