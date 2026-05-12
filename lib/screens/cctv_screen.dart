class CctvScreen extends StatefulWidget { ... }

class _CctvScreenState extends State<CctvScreen> {
  @override
  void initState() {
    super.initState();
    // Connect when screen opens
    context.read<WebSocketService>().connect();
  }

  @override
  Widget build(BuildContext context) {
    final ws = context.watch<WebSocketService>();

    return Scaffold(
      body: Column(
        children: [
          // Connection status badge
          Text('Status: ${ws.status.name}'),
          // Latest event (e.g. motion detected)
          Text('Event: ${ws.latestEvent['camera_id'] ?? 'none'}'),
        ],
      ),
    );
  }
}