// Talks to the server-side trainer on behalf of the learner's computer.
//
// The server answers a message with either the trainer's reply or a request to
// look at / do something on this machine. The client runs each request through
// LocalMachine (which enforces the learner's permissions and approvals) and
// posts the result back, until the turn is finished. See trainer/remote.py.

import '../models/trainer_model.dart';
import '../services/api_service.dart';
import 'connectors.dart';

abstract class TrainerApi {
  Future<Map<String, dynamic>> start(List<String> grants, {int? moduleId});
  Future<Map<String, dynamic>> send(String sessionId, String text);
  Future<Map<String, dynamic>> envResult(String sessionId, Map<String, dynamic> body);
  Future<Map<String, dynamic>> poll(String sessionId);
  Future<void> setGrants(String sessionId, List<String> connectors);
  Future<void> end(String sessionId);
}

class RealTrainerApi implements TrainerApi {
  @override
  Future<Map<String, dynamic>> start(List<String> grants, {int? moduleId}) => ApiService.startLiveTrainerSession(grants, moduleId: moduleId);
  @override
  Future<Map<String, dynamic>> send(String id, String text) => ApiService.sendTrainerMessage(id, text);
  @override
  Future<Map<String, dynamic>> envResult(String id, Map<String, dynamic> body) =>
      ApiService.trainerEnvResult(id, body);
  @override
  Future<Map<String, dynamic>> poll(String id) => ApiService.trainerPoll(id);
  @override
  Future<void> setGrants(String id, List<String> c) async => ApiService.trainerSetGrants(id, c);
  @override
  Future<void> end(String id) async {
    await ApiService.endTrainerSession(id);
  }
}

class LiveTrainerClient {
  final TrainerApi api;
  final LocalMachine machine;
  String? sessionId;

  /// "reading platformio.ini" etc., while the trainer is looking at this computer.
  void Function(String what)? onActivity;
  void Function(TrainerState state)? onState;

  LiveTrainerClient(this.api, this.machine);

  Future<TrainerTurn> start({int? moduleId}) async {
    final ev = await api.start(machine.grants.toList(), moduleId: moduleId);
    sessionId = ev['id'] as String?;
    return _drive(ev);
  }

  Future<TrainerTurn> say(String text) async {
    final id = sessionId;
    if (id == null) throw StateError('No session yet');
    return _drive(await api.send(id, text));
  }

  Future<void> setGrants() async {
    final id = sessionId;
    if (id != null) await api.setGrants(id, machine.grants.toList());
  }

  Future<void> end() async {
    final id = sessionId;
    sessionId = null;
    if (id != null) {
      try {
        await api.end(id);
      } catch (_) {}
    }
  }

  static String describe(String op, Map<String, dynamic> args) {
    switch (op) {
      case 'software_version':
        return 'checking whether ${args['name']} is installed';
      case 'serial_ports':
        return 'looking for your board on USB';
      case 'list_files':
        return 'listing your project files';
      case 'read_file':
        return 'reading ${args['path']}';
      case 'diagnostics':
        return 'checking for errors in your code';
      case 'create_file':
        return 'preparing your starter file';
      case 'open_in_editor':
        return 'opening ${args['path']} in your editor';
      case 'run_build':
        return 'building your project';
      case 'run_upload':
        return 'uploading to your board';
      case 'serial_tail':
        return 'reading your board\'s serial output';
      case 'mqtt_messages':
        return 'listening for your data on MQTT';
      default:
        return 'looking at your computer';
    }
  }

  Future<TrainerTurn> _drive(Map<String, dynamic> ev) async {
    final id = sessionId;
    if (id == null) throw StateError('No session');
    while (true) {
      if (ev['state'] is Map) {
        try {
          onState?.call(TrainerState.fromJson(Map<String, dynamic>.from(ev['state'])));
        } catch (_) {}
      }
      switch (ev['status']) {
        case 'done':
          onActivity?.call('');
          return TrainerTurn.fromJson({...ev, 'id': id});
        case 'working':
          ev = await api.poll(id);
          break;
        case 'env_request':
          final requests = (ev['requests'] as List).cast<Map>();
          Map<String, dynamic> next = ev;
          for (final r in requests) {
            final op = '${r['op']}';
            final args = Map<String, dynamic>.from((r['args'] as Map?) ?? {});
            onActivity?.call(describe(op, args));
            final answer = await machine.handle(op, args);
            next = await api.envResult(id, {'id': r['id'], ...answer});
          }
          ev = next;
          break;
        default:
          throw StateError('Unexpected answer from the trainer: ${ev['status']}');
      }
    }
  }
}
