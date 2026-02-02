import 'package:flutter/material.dart';
import 'summary_screen.dart';
import '../services/audio_recorder_service.dart';
import '../services/fake_ai_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  final AudioRecorderService _recorder = AudioRecorderService();
  bool isRecording = false;

  void toggleRecording() async {
    if (!isRecording) {
      await _recorder.startRecording();
    } else {
      final path = await _recorder.stopRecording();
      final result = await FakeAIService.processMeeting(audioPath: path);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => SummaryScreen(result: result),
        ),
      );
    }

    setState(() => isRecording = !isRecording);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recording')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mic,
              size: 100,
              color: isRecording ? Colors.red : Colors.grey,
            ),
            const SizedBox(height: 20),
            Text(isRecording ? 'Recording...' : 'Tap to start'),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: toggleRecording,
              child: Text(isRecording ? 'Stop & Analyze' : 'Start Recording'),
            ),
          ],
        ),
      ),
    );
  }
}
