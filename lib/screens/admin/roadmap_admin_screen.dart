// Admin for the roadmap curriculum.
//
// The syllabus is a tree — stage, phase, group, then the items a student ticks
// — so this edits it as one, in place, rather than as a flat list with a
// parent dropdown nobody would fill in correctly.
//
// Adding is contextual: the button on a stage adds a phase, on a phase a
// group, on a group an item. That is the only reliable way to keep a
// four-level tree well formed from a phone.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../services/api_service.dart';

/// What a child of each kind should be. Ends at 'topic', which is a leaf.
const _childKind = {
  'month': 'phase',
  'phase': 'group',
  'group': 'topic',
  'outcome': 'deliverable',
};

const _kindLabel = {
  'month': 'Stage',
  'phase': 'Phase',
  'group': 'Group',
  'topic': 'Item',
  'outcome': 'Outcomes',
  'deliverable': 'Deliverable',
  'note': 'Note',
  'milestone': 'Milestone',
};

class RoadmapAdminScreen extends StatefulWidget {
  const RoadmapAdminScreen({super.key});

  @override
  State<RoadmapAdminScreen> createState() => _RoadmapAdminScreenState();
}

class _RoadmapAdminScreenState extends State<RoadmapAdminScreen> {
  List<dynamic> _roadmaps = [];
  Map<String, dynamic>? _selected;
  List<dynamic> _tree = [];
  bool _loading = true;
  final Set<int> _open = {};

  @override
  void initState() {
    super.initState();
    _loadRoadmaps();
  }

  Future<void> _loadRoadmaps() async {
    try {
      _roadmaps = await ApiService.adminGetRoadmaps();
      if (_roadmaps.isNotEmpty) {
        // Default to the roadmap with the most steps rather than the first
        // one. Sorting by id opened a near-empty placeholder and gave no way
        // to reach the real curriculum.
        final sorted = [..._roadmaps]..sort((a, b) =>
            ((b['step_count'] as int?) ?? 0).compareTo((a['step_count'] as int?) ?? 0));
        _selected = sorted.first as Map<String, dynamic>;
        await _loadSteps();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadSteps() async {
    if (_selected == null) return;
    try {
      _tree = await ApiService.adminGetRoadmapSteps(_selected!['id'] as int);
    } catch (_) {
      _tree = [];
    }
    if (mounted) setState(() {});
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m), backgroundColor: error ? AppColors.error : AppColors.success));
  }

  Future<void> _addChild(Map<String, dynamic>? parent) async {
    final kind = parent == null ? 'month' : (_childKind[parent['kind']] ?? 'topic');
    final siblings = parent == null ? _tree : (parent['children'] as List?) ?? [];
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StepSheet(
        roadmapId: _selected!['id'] as int,
        kind: kind,
        parentId: parent?['id'] as int?,
        orderIndex: siblings.length,
      ),
    );
    if (saved == true) {
      if (parent != null) _open.add(parent['id'] as int);
      await _loadSteps();
    }
  }

  Future<void> _edit(Map<String, dynamic> step) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StepSheet(
        roadmapId: _selected!['id'] as int,
        kind: step['kind'] as String,
        parentId: step['parent_id'] as int?,
        orderIndex: (step['order'] as int?) ?? 0,
        step: step,
      ),
    );
    if (saved == true) await _loadSteps();
  }

  Future<void> _delete(Map<String, dynamic> step) async {
    final children = (step['children'] as List?) ?? [];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this?'),
        content: Text(children.isEmpty
            ? '"${step['title']}" will be removed.'
            : '"${step['title']}" and everything inside it '
                '(${children.length} items) will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.adminDeleteRoadmapStep(step['id'] as int);
      _snack('Deleted');
      await _loadSteps();
    } catch (e) {
      _snack(e is ApiException ? e.message : 'Could not delete', error: true);
    }
  }

  /// Swapping order_index with the neighbour is enough here: the list is short
  /// and the alternative — drag and drop across four nesting levels on a
  /// phone — is far easier to get wrong than to use.
  Future<void> _move(List siblings, int index, int delta) async {
    final target = index + delta;
    if (target < 0 || target >= siblings.length) return;
    final a = siblings[index] as Map<String, dynamic>;
    final b = siblings[target] as Map<String, dynamic>;
    try {
      await ApiService.adminSaveRoadmapStep({
        ..._payloadOf(a),
        'order_index': target,
      }, id: a['id'] as int);
      await ApiService.adminSaveRoadmapStep({
        ..._payloadOf(b),
        'order_index': index,
      }, id: b['id'] as int);
      await _loadSteps();
    } catch (e) {
      _snack('Could not reorder', error: true);
    }
  }

  Map<String, dynamic> _payloadOf(Map<String, dynamic> s) => {
        'kind': s['kind'],
        'ref_id': s['ref_id'],
        'title': s['title'] ?? '',
        'description': s['description'] ?? '',
        'duration_label': s['duration_label'] ?? '',
        'level_label': s['level_label'] ?? '',
        'is_optional': s['is_optional'] ?? false,
        'parent_id': s['parent_id'],
        'order_index': s['order'] ?? 0,
      };

  int _countLeaves(List nodes) {
    var n = 0;
    for (final x in nodes) {
      final node = x as Map<String, dynamic>;
      final kids = (node['children'] as List?) ?? [];
      n += kids.isEmpty
          ? (node['kind'] == 'topic' || node['kind'] == 'deliverable' ? 1 : 0)
          : _countLeaves(kids);
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        // The theme paints AppBar foreground white for the dark bars used
        // elsewhere; on a white bar that hides the title and every action.
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: Text('Curriculum',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 17)),
        actions: [
          IconButton(
              onPressed: _loadSteps, icon: const Icon(Icons.refresh_rounded, size: 21)),
        ],
      ),
      floatingActionButton: _selected == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addChild(null),
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add),
              label: const Text('Add stage'),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _selected == null
              ? Center(
                  child: Text('No roadmap yet.',
                      style: GoogleFonts.inter(color: AppColors.textSecondary)))
              : Column(children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                    color: Colors.white,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (_roadmaps.length > 1)
                        DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            value: _selected!['id'] as int,
                            items: [
                              for (final r in _roadmaps)
                                DropdownMenuItem(
                                  value: r['id'] as int,
                                  child: Row(children: [
                                    Flexible(
                                      child: Text(r['title'] as String? ?? '',
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.poppins(
                                              fontSize: 14.5,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    if (r['is_published'] != true) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.textSecondary
                                              .withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text('hidden',
                                            style: GoogleFonts.inter(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w600,
                                                color: AppColors.textSecondary)),
                                      ),
                                    ],
                                  ]),
                                ),
                            ],
                            onChanged: (id) async {
                              final r = _roadmaps.firstWhere((x) => x['id'] == id);
                              setState(() {
                                _selected = r as Map<String, dynamic>;
                                _tree = [];
                                _open.clear();
                              });
                              await _loadSteps();
                            },
                          ),
                        )
                      else
                        Text(_selected!['title'] as String? ?? '',
                            style: GoogleFonts.poppins(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(
                          '${_tree.length} stages · ${_countLeaves(_tree)} tickable items',
                          style: GoogleFonts.inter(
                              fontSize: 12, color: AppColors.textSecondary)),
                    ]),
                  ),
                  Expanded(
                    child: _tree.isEmpty
                        ? Center(
                            child: Text('No stages yet — add the first one.',
                                style: GoogleFonts.inter(color: AppColors.textSecondary)))
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(10, 10, 10, 90),
                            children: [
                              for (var i = 0; i < _tree.length; i++)
                                _StepTile(
                                  step: _tree[i] as Map<String, dynamic>,
                                  siblings: _tree,
                                  index: i,
                                  depth: 0,
                                  openIds: _open,
                                  onToggle: (id) => setState(() =>
                                      _open.contains(id) ? _open.remove(id) : _open.add(id)),
                                  onAdd: _addChild,
                                  onEdit: _edit,
                                  onDelete: _delete,
                                  onMove: _move,
                                ),
                            ],
                          ),
                  ),
                ]),
    );
  }
}

class _StepTile extends StatelessWidget {
  final Map<String, dynamic> step;
  final List siblings;
  final int index;
  final int depth;
  final Set<int> openIds;
  final void Function(int id) onToggle;
  final Future<void> Function(Map<String, dynamic>? parent) onAdd;
  final Future<void> Function(Map<String, dynamic> step) onEdit;
  final Future<void> Function(Map<String, dynamic> step) onDelete;
  final Future<void> Function(List siblings, int index, int delta) onMove;

  const _StepTile({
    required this.step,
    required this.siblings,
    required this.index,
    required this.depth,
    required this.openIds,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onMove,
  });

  @override
  Widget build(BuildContext context) {
    final kind = step['kind'] as String? ?? '';
    final children = (step['children'] as List?) ?? [];
    final id = step['id'] as int;
    final isOpen = openIds.contains(id);
    final canHaveChildren = _childKind.containsKey(kind);
    final isLeaf = kind == 'topic' || kind == 'deliverable';

    return Padding(
      padding: EdgeInsets.only(left: depth * 12.0, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          decoration: BoxDecoration(
            color: isLeaf ? Colors.transparent : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: isLeaf
                ? null
                : Border.all(color: Colors.black.withValues(alpha: 0.07)),
          ),
          child: Row(children: [
            if (children.isNotEmpty)
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                onPressed: () => onToggle(id),
                icon: Icon(
                    isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    size: 19),
              )
            else
              const SizedBox(width: 32),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(_kindLabel[kind] ?? kind,
                          style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                    ),
                    if (children.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Text('${children.length}',
                          style: GoogleFonts.inter(
                              fontSize: 10, color: AppColors.textSecondary)),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(step['title'] as String? ?? '',
                      style: GoogleFonts.inter(
                          fontSize: isLeaf ? 12.5 : 13.5,
                          fontWeight: isLeaf ? FontWeight.w400 : FontWeight.w600,
                          height: 1.3)),
                ]),
              ),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed: index == 0 ? null : () => onMove(siblings, index, -1),
              icon: const Icon(Icons.arrow_upward_rounded, size: 15),
            ),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
              onPressed:
                  index == siblings.length - 1 ? null : () => onMove(siblings, index, 1),
              icon: const Icon(Icons.arrow_downward_rounded, size: 15),
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              iconSize: 18,
              onSelected: (v) {
                if (v == 'edit') onEdit(step);
                if (v == 'add') onAdd(step);
                if (v == 'delete') onDelete(step);
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                if (canHaveChildren)
                  PopupMenuItem(
                      value: 'add',
                      child: Text('Add ${_kindLabel[_childKind[kind]] ?? 'item'}')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
        ),
        if (isOpen)
          for (var i = 0; i < children.length; i++)
            _StepTile(
              step: children[i] as Map<String, dynamic>,
              siblings: children,
              index: i,
              depth: depth + 1,
              openIds: openIds,
              onToggle: onToggle,
              onAdd: onAdd,
              onEdit: onEdit,
              onDelete: onDelete,
              onMove: onMove,
            ),
      ]),
    );
  }
}

class _StepSheet extends StatefulWidget {
  final int roadmapId;
  final String kind;
  final int? parentId;
  final int orderIndex;
  final Map<String, dynamic>? step;

  const _StepSheet({
    required this.roadmapId,
    required this.kind,
    required this.parentId,
    required this.orderIndex,
    this.step,
  });

  @override
  State<_StepSheet> createState() => _StepSheetState();
}

class _StepSheetState extends State<_StepSheet> {
  late final _title = TextEditingController(text: widget.step?['title'] as String? ?? '');
  late final _desc =
      TextEditingController(text: widget.step?['description'] as String? ?? '');
  late final _duration =
      TextEditingController(text: widget.step?['duration_label'] as String? ?? '');
  late final _level =
      TextEditingController(text: widget.step?['level_label'] as String? ?? '');
  late bool _optional = widget.step?['is_optional'] as bool? ?? false;
  bool _saving = false;

  bool get _isStage => widget.kind == 'month';

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Add a title'), backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final body = {
        'kind': widget.kind,
        'title': _title.text.trim(),
        'description': _desc.text.trim(),
        'duration_label': _duration.text.trim(),
        'level_label': _level.text.trim(),
        'is_optional': _optional,
        'parent_id': widget.parentId,
        'order_index': widget.orderIndex,
      };
      await ApiService.adminSaveRoadmapStep(body,
          id: widget.step?['id'] as int?, roadmapId: widget.roadmapId);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e is ApiException ? e.message : 'Could not save'),
            backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _kindLabel[widget.kind] ?? widget.kind;
    return Container(
      margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 60),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 12, 4),
          child: Row(children: [
            Expanded(
              child: Text(widget.step == null ? 'New $label' : 'Edit $label',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            IconButton(
                onPressed: () => Navigator.pop(context, false),
                icon: const Icon(Icons.close)),
          ]),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: EdgeInsets.fromLTRB(
                18, 4, 18, MediaQuery.of(context).viewInsets.bottom + 24),
            children: [
              _field(_title, 'Title'),
              _field(_desc, 'Description', maxLines: 4),
              if (_isStage) ...[
                _field(_duration, 'Duration label', hint: 'Stage 1 of 4'),
                _field(_level, 'Level label', hint: 'Foundation / Advanced'),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _optional,
                onChanged: (v) => setState(() => _optional = v),
                title: Text('Optional',
                    style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w500)),
                subtitle: Text('Left out of progress and never marked "you are here"',
                    style: GoogleFonts.inter(
                        fontSize: 11.5, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Save',
                          style: GoogleFonts.poppins(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _field(TextEditingController c, String label,
          {String hint = '', int maxLines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: c,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint.isEmpty ? null : hint,
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
}
