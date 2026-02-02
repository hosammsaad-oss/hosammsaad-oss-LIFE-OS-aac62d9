import 'package:flutter/material.dart';
import '../models/meeting_result.dart';

class SummaryScreen extends StatelessWidget {
  final MeetingResult result;

  const SummaryScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Memory')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const Text('Summary', style: TextStyle(fontSize: 18)),
            const SizedBox(height: 8),
            Text(result.summary),
            const SizedBox(height: 20),

            const Text('Tasks', style: TextStyle(fontSize: 18)),
            ...result.tasks.map((t) => ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: Text(t),
                )),

            const SizedBox(height: 20),
            const Text('Decisions', style: TextStyle(fontSize: 18)),
            ...result.decisions.map((d) => ListTile(
                  leading: const Icon(Icons.flash_on),
                  title: Text(d),
                )),
          ],
        ),
      ),
    );
  }
}
