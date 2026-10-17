// Calls: the phone's own call history, like the phone app's Recents, with each number matched to the CRM. Tap a call to
// log it on the lead, or to add the number as a lead. Read on the phone only; a call reaches the CRM when it is logged.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/app_colors.dart';
import 'caller_controller.dart';
import 'caller_native.dart';
import 'models.dart';
import 'widgets.dart';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> with WidgetsBindingObserver {
  /// Personal calls (saved contacts who are not leads) are hidden unless asked for.
  bool _showPersonal = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<CallerController>().loadDeviceCalls();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) context.read<CallerController>().loadDeviceCalls();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    final calls = c.deviceCalls;
    if (calls == null) return const Center(child: CircularProgressIndicator());
    if (!c.callLogAllowed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.history, size: 48, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            const Text('Allow "Read the call log" to see your calls here.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () async {
                await c.native.requestPermission('call_log');
                await c.loadDeviceCalls();
              },
              child: const Text('Allow'),
            ),
          ]),
        ),
      );
    }
    final work = calls.where((d) => !c.isPersonal(d)).toList();
    final shown = _showPersonal ? calls : work;
    return RefreshIndicator(
      onRefresh: c.loadDeviceCalls,
      child: ListView.builder(
        itemCount: shown.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(spacing: 8, children: [
                ChoiceChip(
                    label: Text('Leads & new numbers (${work.length})'),
                    selected: !_showPersonal,
                    onSelected: (_) => setState(() => _showPersonal = false)),
                ChoiceChip(
                    label: Text('All calls, with personal (${calls.length})'),
                    selected: _showPersonal,
                    onSelected: (_) => setState(() => _showPersonal = true)),
              ]),
            );
          }
          return CallRow(shown[i - 1], key: ValueKey(shown[i - 1].key));
        },
      ),
    );
  }
}

class CallRow extends StatelessWidget {
  final DeviceCall call;
  const CallRow(this.call, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<CallerController>();
    final lead = c.leadFor(call.phone);
    final logged = c.isLogged(call);
    final (icon, color) = switch (call.type) {
      'in' => (Icons.call_received, AppColors.success),
      'out' => (Icons.call_made, AppColors.primaryLight),
      _ => (Icons.call_missed, AppColors.error),
    };
    final name = lead?.displayName ?? (call.contactName.isNotEmpty ? call.contactName : last10(call.phone));
    final when = CallerController.when(call.at);
    final detail = switch (call.type) {
      'missed' => 'Missed',
      'rejected' => 'Rejected',
      'blocked' => 'Blocked',
      _ => call.durationS > 0 ? duration(call.durationS) : 'Not picked up',
    };
    final personal = c.ignored.contains(last10(call.phone));
    return ListTile(
      onTap: () => c.logDeviceCall(call),
      onLongPress: () => showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (!personal)
              ListTile(
                leading: const Icon(Icons.report, color: AppColors.error),
                title: const Text('Mark as spam'),
                subtitle: const Text('Never sent again, and taken out of the whole team\'s list.'),
                onTap: () {
                  c.markSpam(call.phone);
                  Navigator.pop(ctx);
                },
              ),
            ListTile(
              leading: Icon(personal ? Icons.sync : Icons.person_off),
              title: Text(personal ? 'Send this number\'s calls to the CRM again' : 'Personal number: don\'t send its calls'),
              subtitle: Text(personal ? '' : 'Its calls stay on this phone and it never becomes a lead.'),
              onTap: () {
                c.setPersonal(call.phone, !personal);
                Navigator.pop(ctx);
              },
            ),
          ]),
        ),
      ),
      leading: Icon(icon, color: color),
      title: Row(children: [
        Flexible(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600))),
        const SizedBox(width: 6),
        if (lead != null) HeatBadge(lead.heat, converted: lead.converted),
      ]),
      subtitle: Text([
        when,
        detail,
        if (c.isPersonal(call)) 'Personal, stays on this phone',
        if (lead == null && !c.isPersonal(call)) 'Not a lead yet',
        if (lead != null) stages[lead.stage] ?? lead.stage,
      ].join(' · ')),
      trailing: logged
          ? const Tooltip(message: 'Logged', child: Icon(Icons.check_circle, color: AppColors.success))
          : IconButton(
              tooltip: 'Call back',
              icon: const Icon(Icons.call, color: AppColors.success),
              onPressed: () => c.call(lead ?? Lead(phone: last10(call.phone), name: call.contactName)),
            ),
    );
  }
}
