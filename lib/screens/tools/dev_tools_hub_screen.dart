import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import 'ble_tester_screen.dart';
import 'http_tester_screen.dart';
import 'mqtt_tester_screen.dart';
import 'websocket_tester_screen.dart';

/// Hub for the free, no-login dev tools (protocol testers) — previously
/// only reachable via a horizontal row buried in the home feed; now also a
/// proper nav destination from the sidebar.
class DevToolsHubScreen extends StatelessWidget {
  const DevToolsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tools = <(String, String, IconData, Color, WidgetBuilder)>[
      ('MQTT Tester', 'Publish and subscribe to any broker', Icons.developer_board_rounded,
          AppColors.primary, (_) => const MqttTesterScreen()),
      ('HTTP Tester', 'Send requests, inspect responses', Icons.http_rounded,
          AppColors.accent, (_) => const HttpTesterScreen()),
      ('WebSocket Tester', 'Connect and exchange messages live', Icons.cable_rounded,
          AppColors.primary, (_) => const WebSocketTesterScreen()),
      ('BLE Tester', 'Scan and connect to nearby BLE devices', Icons.bluetooth_rounded,
          AppColors.accent, (_) => const BleTesterScreen()),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text('Dev Tools', style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Test brokers and endpoints right in the browser — free, no login.',
              style: GoogleFonts.inter(fontSize: 12.5, color: AppColors.textSecondary)),
          const SizedBox(height: 16),
          ...tools.map((t) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: t.$4.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                    child: Icon(t.$3, color: t.$4, size: 22),
                  ),
                  title: Text(t.$1, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14.5)),
                  subtitle: Text(t.$2, style: GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: t.$5)),
                ),
              )),
          // Classic Bluetooth (SPP/RFCOMM) isn't reachable from any browser —
          // no Web API exposes it, on any browser vendor. Only a real native
          // app (Play Store, planned) can support it. Shown here disabled
          // so it's on the radar without implying it works today.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.bluetooth_connected_rounded, color: Colors.grey.shade500, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Classic Bluetooth Tester',
                      style: GoogleFonts.poppins(color: Colors.grey.shade600, fontWeight: FontWeight.w700, fontSize: 14.5)),
                  const SizedBox(height: 2),
                  Text('For SPP/RFCOMM modules (e.g. HC-05) — needs our upcoming Play Store app',
                      style: GoogleFonts.inter(color: Colors.grey.shade500, fontSize: 11.5)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
                child: Text('SOON',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.grey.shade700, letterSpacing: 0.4)),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
