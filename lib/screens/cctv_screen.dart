import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/websocket_service.dart';

class CctvScreen extends StatefulWidget {
  const CctvScreen({super.key});

  @override
  State<CctvScreen> createState() => _CctvScreenState();
}

class _CctvScreenState extends State<CctvScreen> {
  List<dynamic> _cameras = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCameras();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WebSocketService>().connect();
    });
  }

  Future<void> _loadCameras() async {
    try {
      final cameras = await context.read<ApiService>().getCameraList();
      if (mounted) setState(() { _cameras = cameras; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WebSocketService>();
    final event = ws.latestEvent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('CCTV Live View'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: _WsChip(status: ws.status),
          ),
        ],
      ),
      body: Column(
        children: [
          if (event != null)
            MaterialBanner(
              content: Text(
                '[${event.cameraId}] ${event.message}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              leading: const Icon(Icons.warning_amber_rounded,
                  color: Colors.orange),
              actions: [
                TextButton(
                  onPressed: () => setState(() {}),
                  child: const Text('DISMISS'),
                ),
              ],
            ),

          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _loadCameras)
                    : _cameras.isEmpty
                        ? const Center(child: Text('No cameras found'))
                        : GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 16 / 9,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: _cameras.length,
                            itemBuilder: (_, i) =>
                                _CameraCard(camera: _cameras[i]),
                          ),
          ),

          if (ws.eventHistory.isNotEmpty) ...[
            const Divider(height: 1),
            SizedBox(
              height: 180,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                    child: Text('Recent Alerts',
                        style: Theme.of(context).textTheme.labelLarge),
                  ),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: ws.eventHistory.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final e = ws.eventHistory[i];
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.videocam, size: 18),
                          title: Text(e.message),
                          subtitle: Text(e.cameraId),
                          trailing: Text(
                            '${e.timestamp.hour.toString().padLeft(2, '0')}'
                            ':${e.timestamp.minute.toString().padLeft(2, '0')}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await context.read<ApiService>().sendAlert(
                  cameraId: 'manual',
                  message: 'Manual alert triggered from app',
                  severity: 'high',
                );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Alert sent ✅')),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('Failed: $e')));
            }
          }
        },
        icon: const Icon(Icons.warning_rounded),
        label: const Text('Send Alert'),
      ),
    );
  }
}

class _WsChip extends StatelessWidget {
  final WsStatus status;
  const _WsChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      WsStatus.connected    => ('LIVE', Colors.green),
      WsStatus.connecting   => ('Connecting…', Colors.orange),
      WsStatus.error        => ('Error', Colors.red),
      WsStatus.disconnected => ('Offline', Colors.grey),
    };
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      backgroundColor: color.withOpacity(0.15),
      side: BorderSide(color: color),
    );
  }
}

class _CameraCard extends StatelessWidget {
  final Map<String, dynamic> camera;
  const _CameraCard({required this.camera});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black87),
          const Center(
            child: Icon(Icons.videocam, color: Colors.white38, size: 40),
          ),
          Positioned(
            bottom: 6, left: 6, right: 6,
            child: Text(
              camera['name'] as String? ?? camera['id'] as String? ?? 'Camera',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(blurRadius: 4)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
}