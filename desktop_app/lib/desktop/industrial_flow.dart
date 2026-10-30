import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import 'note_tutor_screen.dart';

/// Altrobyte Industrial's training run on the team's computer (30 Oct 2026, founder: a premium, real demo for plants):
/// a worker is registered, Altron teaches the programme's lesson in Hinglish, the worker takes its test, and a pass earns
/// a certificate with a number anyone can verify. Every result goes to the plant's record on the server (industrial.py).

const indInk = Color(0xFF0B1424);
const indPanel = Color(0xFF13203A);
const indGold = Color(0xFFD9A441);
const indGoldSoft = Color(0xFFF3D99B);
const indLine = Color(0xFF243656);
const indGood = Color(0xFF4ADE80);
const indBad = Color(0xFFEF7D6D);

class IndQuestion {
  final String q;
  final List<String> options;
  final int right;
  final String why;
  const IndQuestion(this.q, this.options, this.right, this.why);
}

class IndProgramme {
  final String key, title, line, size;
  final int contentId;
  final IconData icon;
  final List<IndQuestion> test;
  const IndProgramme(this.key, this.title, this.line, this.size, this.contentId, this.icon, this.test);
}

/// The programmes with a lesson and a test today. The lessons are the notes in docs/industrial (modules 11-13, not
/// published, so learners never see them); the questions are the same as at the end of each lesson.
const indProgrammes = [
  IndProgramme('safety_induction', 'Safety Induction',
      'Hazards, PPE, lockout-tagout, hot metal, cranes, gas, fire, height and emergency, for every new joiner and contract worker.',
      '13 sections · 12 drills · Hindi', 102, Icons.health_and_safety_rounded, [
    // In simple Hindi, as the lesson is (30 Oct 2026, founder: workers are not used to English).
    IndQuestion('Conveyor में jam है। सबसे पहले क्या करेंगे?',
        ['Gloves पहनकर जल्दी से निकाल देंगे', 'LOTO: मशीन बंद, बिजली काटो, अपना ताला लगाओ, चलाकर देखो', 'Operator से कहेंगे कि start button पर नज़र रखे'],
        1, 'सिर्फ़ आपका अपना ताला पक्का करता है कि कोई मशीन चालू नहीं कर सकता।'),
    IndQuestion('तेल के drum में आग लगी है। कौन सा सिलेंडर कभी नहीं?', ['पानी', 'Foam', 'CO₂'], 0, 'पानी से जलता तेल फैल जाता है।'),
    IndQuestion('Crane coil लेकर आपकी तरफ़ आ रहा है। क्या करेंगे?',
        ['जल्दी से नीचे से निकल जाएँगे', 'रुकेंगे या घूमकर जाएँगे, load के नीचे कभी नहीं', 'खुद crane operator को इशारा करेंगे'], 1,
        'Load के नीचे कोई नहीं जाता, और इशारा सिर्फ़ trained signal वाला देता है।'),
    IndQuestion('CO meter 80 ppm दिखा रहा है। क्या करेंगे?', ['काम जल्दी खत्म करेंगे', 'तुरंत बाहर, हवा की उल्टी तरफ़, alarm बजाएँगे', 'खिड़की खोलकर काम करते रहेंगे'],
        1, '50 से ऊपर खतरा है।'),
    IndQuestion('Gas वाली जगह एक साथी गिर गया है। क्या करेंगे?',
        ['दौड़कर अंदर जाकर उसे खींच लाएँगे', 'Alarm बजाएँगे और gas rescue team को बुलाएँगे', 'उसके चेहरे पर पानी डालेंगे'], 1,
        'ज़्यादातर मौतें बचाने वालों की होती हैं। दूसरे शिकार मत बनो।'),
    IndQuestion('सीढ़ी दीवार पर 4 मीटर ऊपर टिकी है। नीचे का हिस्सा दीवार से कितना दूर हो?', ['लगभग 1 मीटर', 'दीवार से सटा हुआ', 'लगभग 3 मीटर'], 0,
        '4 ऊपर, 1 बाहर।'),
    IndQuestion('Lathe पर काम करते समय क्या सही है?',
        ['मोटे gloves पहनें', 'Gloves नहीं, आस्तीन कसी, बाल बँधे, चश्मा पहना', 'आराम के लिए ढीले कपड़े'], 1,
        'Gloves और ढीले कपड़े घूमते हिस्से में फँस जाते हैं।'),
    IndQuestion('Platform से spanner गिरा और एक worker के पास आकर लगा। किसी को चोट नहीं। यह क्या है?',
        ['कुछ नहीं हुआ, कुछ करना नहीं', 'Near miss: उसी शिफ्ट में बताओ', 'Worker की गलती'], 1, 'Near miss बताने से बड़े हादसे रुकते हैं।'),
  ]),
  IndProgramme('electrical_panel', 'Electrical Panel Safety',
      'Inside a motor control centre, shock and arc flash, test before touch, protection devices and panel room rules.',
      '7 sections · 5 drills', 103, Icons.electrical_services_rounded, [
    IndQuestion('A feeder switch is in the OFF position. Is the motor circuit safe to touch?',
        ['Yes, it is off', 'Only after lock, tag and a live-dead-live test', 'Yes, if the motor is not running'], 1, 'OFF is not proof; only the test is.'),
    IndQuestion('Why do you test the tester again after the circuit reads dead?',
        ['To use up time', 'To prove the tester did not fail during the test', 'It is not needed'], 1, 'A failed tester also reads "dead".'),
    IndQuestion('Which current through the body can stop the heart?', ['1 mA', '100 mA', 'Only above 10 A'], 1, 'Around 100 mA causes fibrillation.'),
    IndQuestion('A person touches a live wire and current leaks to earth through them. What trips?',
        ['The overload relay', 'The RCCB / ELCB at 30 mA', 'Nothing'], 1, 'That is the job of the RCCB.'),
    IndQuestion('You switched off a VFD. When can you work on it?',
        ['Immediately', 'After the waiting time on the drive and testing the DC bus', 'After the fan stops'], 1, 'Its capacitors stay charged.'),
    IndQuestion('What is an arc flash?', ['A spark from a welding rod', 'A fault through air with extreme heat, blast and molten metal', 'A light on the panel'], 1,
        'Around 20,000 °C in a split second.'),
    IndQuestion('Cartons are kept in front of a panel to save space. What is wrong?',
        ['Nothing', 'The panel needs 1 metre clear; cartons are fuel and block escape', 'Only that it looks untidy'], 1, 'Keep 1 metre clear.'),
    IndQuestion('Why must the motor frame be earthed?',
        ['To make it heavier', 'So a fault goes to earth and trips the protection, not through a person', 'It is only for lightning'], 1,
        'Earthing makes the protection trip.'),
  ]),
  IndProgramme('connectivity', 'Industrial Connectivity',
      'The automation pyramid, 4-20 mA, fieldbus, OPC UA and MQTT, predictive maintenance in a rolling mill, OT security.',
      '7 sections · 5 drills', 104, Icons.hub_rounded, [
    IndQuestion("Which level runs the mill's motors and interlocks in milliseconds?", ['ERP', 'PLC and drives (level 1)', 'MES'], 1,
        'Level 1 works in milliseconds.'),
    IndQuestion('A 4-20 mA transmitter for 0-1,200 °C sends 12 mA. What is the temperature?', ['600 °C', '720 °C', '1,200 °C'], 0,
        '(12 − 4) ÷ 16 × 1,200 = 600.'),
    IndQuestion('A transmitter reads 0 mA. What does it most likely mean?', ['Zero degrees', 'A broken wire or a failed transmitter', 'Maximum temperature'], 1,
        'That is why the scale starts at 4 mA.'),
    IndQuestion('Which protocol lets SCADA and MES read PLC tags from any vendor, securely?', ['OPC UA', 'RS-232', 'Bluetooth'], 0, 'OPC UA is vendor-neutral.'),
    IndQuestion("In MQTT, how does a dashboard get a sensor's readings?",
        ['It polls the sensor every second', 'It subscribes to the topic on the broker', 'Through email'], 1, 'Publish and subscribe.'),
    IndQuestion("A stand motor's vibration rose from 2 to 8 mm/s over three weeks. What do you do?",
        ['Nothing, it still runs', 'Plan a bearing check in the next shutdown', 'Increase the speed'], 1, 'Alarm zone: plan it before it breaks.'),
    IndQuestion('A vendor asks you to install TeamViewer on the HMI for support. What is right?',
        ['Install it, it is quicker', "Refuse: remote access only through the plant's approved, logged system", 'Install it and remove it later'], 1,
        'Approved, logged remote access only.'),
    IndQuestion('Why is the plant network separated from the office network?',
        ['To make cables shorter', 'So an attack in the office cannot reach the PLCs', 'It is not needed'], 1, 'Segmentation keeps attacks out of the plant.'),
  ]),
];

/// Set by the tablet app (it has share_plus and url_launcher; the desktop app does not): hands a file to another app, and
/// opens a link. Null on the desktop, which saves and opens files itself.
Future<void> Function(String path, String mime, String subject)? indShareFile;
Future<void> Function(String url)? indOpenUrl;

const indDepartments = ['Production', 'Maintenance', 'Quality', 'Stores & logistics', 'Contract workforce', 'Office & admin'];

String indVerifyUrl(String cert) => 'https://altrobytelab.com/verify/?c=$cert';

/// Registers the worker, runs the lesson and the test, records the result, and shows the certificate.
/// Returns true when a result was recorded (the plant view refreshes).
/// [lesson] is the lesson screen of the device (the tablet has its own); by default the desktop's note tutor.
Future<bool> runIndustrialTraining(BuildContext context, int plantId, IndProgramme p, {Widget Function(IndProgramme p)? lesson}) async {
  final worker = await showDialog<Map<String, dynamic>>(context: context, builder: (_) => _WorkerDialog(plantId: plantId, programme: p));
  if (worker == null || !context.mounted) return false;
  final started = DateTime.now();
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => lesson?.call(p) ??
      // When the lesson is complete the test opens by itself (30 Oct 2026: it waited for the back button).
      NoteTutorScreen(contentId: p.contentId, title: p.title, lang: 'hi', resume: false, audience: 'worker', nextTitle: 'Test (8 sawaal)')));
  if (!context.mounted) return false;
  final minutes = DateTime.now().difference(started).inMinutes;
  final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => IndustrialTestScreen(programme: p, worker: worker, minutes: minutes)));
  if (result == null || !context.mounted) return false;
  if (result['passed'] == true) {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => IndustrialCertificateScreen(result: result)));
  }
  return true;
}

class _WorkerDialog extends StatefulWidget {
  final int plantId;
  final IndProgramme programme;
  const _WorkerDialog({required this.plantId, required this.programme});
  @override
  State<_WorkerDialog> createState() => _WorkerDialogState();
}

class _WorkerDialogState extends State<_WorkerDialog> {
  final _name = TextEditingController();
  final _id = TextEditingController();
  final _role = TextEditingController();
  String _dept = indDepartments.first;
  bool _busy = false;
  String? _problem;

  Future<void> _go() async {
    final name = _name.text.trim(), id = _id.text.trim();
    if (name.length < 2 || id.isEmpty) {
      setState(() => _problem = 'Enter the worker\'s name and employee ID.');
      return;
    }
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final w = await ApiService.industrialPost('plants/${widget.plantId}/workers',
          {'name': name, 'emp_id': id, 'department': _dept, 'role': _role.text.trim()});
      if (mounted) Navigator.of(context).pop(w);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = e is ApiException && e.statusCode == 403
              ? 'Industrial training opens with an Altrobyte team login on this computer.'
              : 'Could not reach the server. Check the internet and try again.';
        });
      }
    }
  }

  InputDecoration _box(String label) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        filled: true,
        fillColor: indInk,
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: indLine)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: indGold)),
      );

  @override
  Widget build(BuildContext context) {
    final p = widget.programme;
    return Dialog(
      backgroundColor: indPanel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: indLine)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(p.icon, color: indGold, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
                  Text('Who is taking the training?', style: GoogleFonts.inter(color: Colors.white60, fontSize: 13)),
                ]),
              ),
            ]),
            const SizedBox(height: 20),
            TextField(controller: _name, autofocus: true, style: const TextStyle(color: Colors.white), decoration: _box('Full name')),
            const SizedBox(height: 12),
            TextField(controller: _id, style: const TextStyle(color: Colors.white), decoration: _box('Employee ID')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _dept,
              dropdownColor: indPanel,
              style: const TextStyle(color: Colors.white),
              decoration: _box('Department'),
              items: [for (final d in indDepartments) DropdownMenuItem(value: d, child: Text(d))],
              onChanged: (v) => setState(() => _dept = v ?? _dept),
            ),
            const SizedBox(height: 12),
            TextField(controller: _role, style: const TextStyle(color: Colors.white), decoration: _box('Role (optional), e.g. Fitter, Crane operator'),
                onSubmitted: (_) => _go()),
            if (_problem != null) ...[
              const SizedBox(height: 12),
              Text(_problem!, style: GoogleFonts.inter(color: indBad, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: Text('Altron teaches in Hinglish. Then an 8-question test; 70% earns the certificate.',
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 12)),
              ),
              const SizedBox(width: 12),
              TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Cancel')),
              const SizedBox(width: 6),
              FilledButton(
                onPressed: _busy ? null : _go,
                style: FilledButton.styleFrom(backgroundColor: indGold, foregroundColor: indInk),
                child: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: indInk))
                    : Text('Start training', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

/// One question at a time, the answer explained at once, the result recorded at the end.
class IndustrialTestScreen extends StatefulWidget {
  final IndProgramme programme;
  final Map<String, dynamic> worker;
  final int minutes;
  const IndustrialTestScreen({super.key, required this.programme, required this.worker, required this.minutes});
  @override
  State<IndustrialTestScreen> createState() => _IndustrialTestScreenState();
}

class _IndustrialTestScreenState extends State<IndustrialTestScreen> {
  int _at = 0, _score = 0;
  int? _picked;
  bool _saving = false;
  Map<String, dynamic>? _result;
  String? _problem;

  List<IndQuestion> get _qs => widget.programme.test;

  void _pick(int i) {
    if (_picked != null) return;
    setState(() {
      _picked = i;
      if (i == _qs[_at].right) _score++;
    });
  }

  Future<void> _next() async {
    if (_at < _qs.length - 1) {
      setState(() {
        _at++;
        _picked = null;
      });
      return;
    }
    await _save();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _problem = null;
    });
    try {
      final r = await ApiService.industrialPost('results', {
        'worker_id': widget.worker['id'],
        'programme': widget.programme.key,
        'score': _score,
        'total': _qs.length,
        'minutes': widget.minutes,
      });
      if (mounted) setState(() => _result = r);
    } catch (_) {
      if (mounted) setState(() => _problem = 'The result could not be saved. Check the internet and try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: indInk,
      appBar: AppBar(
        backgroundColor: indInk,
        foregroundColor: Colors.white,
        title: Text('${widget.programme.title} · Test', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        automaticallyImplyLeading: _result == null,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Padding(padding: const EdgeInsets.all(28), child: _result != null ? _done() : _question()),
        ),
      ),
    );
  }

  Widget _question() {
    final q = _qs[_at];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('Question ${_at + 1} of ${_qs.length}', style: GoogleFonts.inter(color: indGold, fontWeight: FontWeight.w700)),
        const Spacer(),
        Text(widget.worker['name'] ?? '', style: GoogleFonts.inter(color: Colors.white54)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: (_at + (_picked == null ? 0 : 1)) / _qs.length, minHeight: 6, backgroundColor: indPanel, color: indGold),
      ),
      const SizedBox(height: 28),
      Text(q.q, style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, height: 1.3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 22),
      for (var i = 0; i < q.options.length; i++) _option(q, i),
      const SizedBox(height: 10),
      if (_picked != null)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: indPanel, borderRadius: BorderRadius.circular(12)),
          child: Text('${_picked == q.right ? 'Right.' : 'Not quite.'} ${q.why}',
              style: GoogleFonts.inter(color: _picked == q.right ? indGood : indGoldSoft, fontSize: 15)),
        ),
      const Spacer(),
      if (_problem != null) Text(_problem!, style: GoogleFonts.inter(color: indBad)),
      Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: _picked == null || _saving ? null : _next,
          style: FilledButton.styleFrom(backgroundColor: indGold, foregroundColor: indInk, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: indInk))
              : Text(_at < _qs.length - 1 ? 'Next question' : (_problem != null ? 'Try again' : 'See my result'),
                  style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }

  Widget _option(IndQuestion q, int i) {
    final chosen = _picked == i, shown = _picked != null;
    final good = shown && i == q.right, bad = chosen && i != q.right;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _pick(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: good ? indGood.withValues(alpha: 0.14) : bad ? indBad.withValues(alpha: 0.14) : indPanel,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: good ? indGood : bad ? indBad : indLine, width: good || bad ? 2 : 1),
          ),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: good ? indGood : bad ? indBad : Colors.white30)),
              child: good
                  ? const Icon(Icons.check_rounded, size: 18, color: indGood)
                  : bad
                      ? const Icon(Icons.close_rounded, size: 18, color: indBad)
                      : Text(String.fromCharCode(65 + i), style: GoogleFonts.inter(color: Colors.white70, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Text(q.options[i], style: GoogleFonts.inter(color: Colors.white, fontSize: 16))),
          ]),
        ),
      ),
    );
  }

  Widget _done() {
    final r = _result!;
    final passed = r['passed'] == true;
    final pct = ((r['score'] as num) * 100 / (r['total'] as num)).round();
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 150,
        height: 150,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: passed ? indGold : indBad, width: 6)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$pct%', style: GoogleFonts.poppins(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
          Text('${r['score']} of ${r['total']}', style: GoogleFonts.inter(color: Colors.white60)),
        ]),
      ),
      const SizedBox(height: 26),
      Text(passed ? 'Passed. Well done, ${r['name']}.' : 'Not passed this time.',
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(
          passed
              ? 'Certificate ${r['cert_no']} is issued and recorded in the plant report.'
              : 'You need ${r['pass_percent']}%. The re-test is due; the result is in the plant report.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(color: Colors.white70, fontSize: 15)),
      const SizedBox(height: 28),
      FilledButton(
        onPressed: () => Navigator.of(context).pop(r),
        style: FilledButton.styleFrom(backgroundColor: indGold, foregroundColor: indInk, padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16)),
        child: Text(passed ? 'View certificate' : 'Back to the plant', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

/// The certificate on screen, and saved as a page to print or keep as PDF.
class IndustrialCertificateScreen extends StatelessWidget {
  final Map<String, dynamic> result;
  const IndustrialCertificateScreen({super.key, required this.result});

  static String _date(String? iso) {
    final d = DateTime.tryParse(iso ?? '')?.toLocal() ?? DateTime.now();
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  static String _esc(Object? s) => '${s ?? ''}'.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

  /// The certificate as a printable page (A4 landscape), saved in Documents\Altrobyte Certificates and opened in the browser.
  static Future<String> saveAndOpen(Map<String, dynamic> r) async {
    if (!Platform.isWindows) {
      // The tablet: the page is shared (to a printer app, WhatsApp or Drive), where it prints or saves as PDF.
      final f = File('${Directory.systemTemp.path}/${r['cert_no']}.html');
      await f.writeAsString(certificateHtml(r));
      await indShareFile?.call(f.path, 'text/html', 'Certificate ${r['cert_no']}');
      return f.path;
    }
    final home = Platform.environment['USERPROFILE'] ?? Directory.systemTemp.path;
    final dir = Directory('$home\\Documents\\Altrobyte Certificates');
    await dir.create(recursive: true);
    final f = File('${dir.path}\\${r['cert_no']}.html');
    await f.writeAsString(certificateHtml(r));
    await Process.run('cmd', ['/c', 'start', '', f.path]);
    return f.path;
  }

  static String certificateHtml(Map<String, dynamic> r) => '''<!doctype html><html><head><meta charset="utf-8"><title>${_esc(r['cert_no'])}</title>
<style>@page{size:A4 landscape;margin:0}body{margin:0;background:#E9E4D8;font-family:Georgia,serif}
.c{width:297mm;height:210mm;box-sizing:border-box;padding:16mm;margin:auto;background:#FFFDF7;position:relative}
.b{position:absolute;inset:9mm;border:2px solid #B8862E;outline:6px double #D9A441;outline-offset:4px}
.in{position:relative;text-align:center;padding-top:8mm}.k{font:700 12px Arial;letter-spacing:5px;color:#B8862E}
h1{font-size:44px;margin:6mm 0 2mm;color:#0B1424}.to{font:14px Arial;color:#5A6675;letter-spacing:2px}
.n{font-size:40px;margin:5mm 0 1mm;color:#0B1424;font-style:italic}.m{font:15px Arial;color:#3A4656}
.p{font-size:26px;color:#0B1424;margin:6mm 0 2mm;font-weight:700}.row{display:flex;justify-content:space-between;margin:14mm 18mm 0;font:13px Arial;color:#3A4656;text-align:center}
.row b{display:block;font-size:15px;color:#0B1424;border-top:1px solid #B8862E;padding-top:2mm;margin-top:8mm;min-width:55mm}
.seal{position:absolute;right:22mm;top:20mm;width:34mm;height:34mm;border-radius:50%;background:radial-gradient(#F3D99B,#D9A441 60%,#B8862E);display:flex;align-items:center;justify-content:center;font:700 11px Arial;color:#0B1424;text-align:center;letter-spacing:1px}
.v{position:absolute;left:0;right:0;bottom:13mm;font:11px Arial;color:#5A6675;text-align:center}
@media print{body{background:none}}</style></head><body><div class="c"><div class="b"></div><div class="seal">ALTROBYTE<br>INDUSTRIAL<br>CERTIFIED</div><div class="in">
<div class="k">ALTROBYTE INDUSTRIAL</div><h1>Certificate of Training</h1><div class="to">THIS CERTIFIES THAT</div>
<div class="n">${_esc(r['name'])}</div><div class="m">Employee ID ${_esc(r['emp_id'])} · ${_esc(r['department'])} · ${_esc(r['plant'])}${(r['city'] ?? '').toString().isEmpty ? '' : ', ${_esc(r['city'])}'}</div>
<div class="m" style="margin-top:6mm">has completed the training and passed the assessment in</div><div class="p">${_esc(r['programme'])}</div>
<div class="m">Score ${_esc(r['score'])} / ${_esc(r['total'])} · ${_date(r['finished_at'] as String?)}</div>
<div class="row"><div><b>Altron AI Trainer</b>Delivered by</div><div><b>${_esc(r['cert_no'])}</b>Certificate number</div><div><b>Training Head</b>For the plant</div></div></div>
<div class="v">Verify this certificate at ${_esc(indVerifyUrl('${r['cert_no']}'))}</div></div><script>setTimeout(function(){print()},600)</script></body></html>''';

  @override
  Widget build(BuildContext context) {
    final r = result;
    return Scaffold(
      backgroundColor: indInk,
      appBar: AppBar(backgroundColor: indInk, foregroundColor: Colors.white, title: Text('Certificate', style: GoogleFonts.poppins(fontWeight: FontWeight.w600))),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(children: [
            SizedBox(
              width: 900,
              child: AspectRatio(
                aspectRatio: 297 / 210,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: const Color(0xFFFFFDF7), borderRadius: BorderRadius.circular(6),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 30, offset: const Offset(0, 14))]),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: indGold, width: 3)),
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                    child: Stack(children: [
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 92,
                          height: 92,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                              shape: BoxShape.circle, gradient: RadialGradient(colors: [indGoldSoft, indGold, Color(0xFFB8862E)])),
                          child: Text('ALTROBYTE\nINDUSTRIAL\nCERTIFIED', textAlign: TextAlign.center,
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: indInk, letterSpacing: 1)),
                        ),
                      ),
                      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('ALTROBYTE INDUSTRIAL', style: GoogleFonts.inter(letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFB8862E))),
                        const SizedBox(height: 8),
                        Text('Certificate of Training', style: GoogleFonts.playfairDisplay(fontSize: 38, fontWeight: FontWeight.w700, color: indInk)),
                        const SizedBox(height: 10),
                        Text('THIS CERTIFIES THAT', style: GoogleFonts.inter(letterSpacing: 2, fontSize: 12, color: Colors.black54)),
                        const SizedBox(height: 6),
                        Text('${r['name']}', style: GoogleFonts.playfairDisplay(fontSize: 36, fontStyle: FontStyle.italic, color: indInk)),
                        Text('Employee ID ${r['emp_id']} · ${r['department']} · ${r['plant']}',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 12),
                        Text('has completed the training and passed the assessment in', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 4),
                        Text('${r['programme']}', style: GoogleFonts.playfairDisplay(fontSize: 26, fontWeight: FontWeight.w700, color: indInk)),
                        Text('Score ${r['score']} / ${r['total']} · ${_date(r['finished_at'] as String?)}', style: GoogleFonts.inter(fontSize: 13, color: Colors.black87)),
                        const SizedBox(height: 18),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                          _sign('Altron AI Trainer', 'Delivered by'),
                          _sign('${r['cert_no']}', 'Certificate number'),
                          _sign('Training Head', 'For the plant'),
                        ]),
                        const SizedBox(height: 10),
                        Text('Verify at ${indVerifyUrl('${r['cert_no']}')}', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.black54)),
                      ]),
                    ]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Wrap(spacing: 12, children: [
              FilledButton.icon(
                onPressed: () => saveAndOpen(r),
                style: FilledButton.styleFrom(backgroundColor: indGold, foregroundColor: indInk, padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                icon: const Icon(Icons.print_rounded),
                label: Text('Print or save as PDF', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              ),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white30),
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16)),
                child: const Text('Back to the plant'),
              ),
            ]),
          ]),
        ),
      ),
    );
  }

  Widget _sign(String a, String b) => Column(children: [
        Container(width: 170, height: 1, color: const Color(0xFFB8862E)),
        const SizedBox(height: 6),
        Text(a, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: indInk)),
        Text(b, style: GoogleFonts.inter(fontSize: 11, color: Colors.black54)),
      ]);
}
