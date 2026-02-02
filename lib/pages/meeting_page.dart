
import 'package:flutter/material.dart';
import '../services/audio_recorder_service.dart';
import '../services/openai_service.dart';
import '../models/meeting_result.dart';

class MeetingPage extends StatefulWidget {
  const MeetingPage({super.key});

  @override
  State<MeetingPage> createState() => _MeetingPageState();
}

class _MeetingPageState extends State<MeetingPage> {
  final AudioRecorderService _recorderService = AudioRecorderService();
  bool _isRecording = false;
  final List<MeetingResult> _meetings = [];

  void _startRecording() async {
    try {
      await _recorderService.startRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      debugPrint('Error starting recording: $e');
    }
  }

  void _stopAndAnalyze() async {
    try {
      final path = await _recorderService.stopRecording();
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        final resultJson = await OpenAIService.analyzeAudio(path);
        final meeting = MeetingResult.fromJson(resultJson);

        setState(() {
          _meetings.insert(0, meeting);
        });
      }
    } catch (e) {
      debugPrint('Error analyzing audio: $e');
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Life OS - Meetings'),
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Stop & Analyze' : 'Start Recording'),
              onPressed: _isRecording ? _stopAndAnalyze : _startRecording,
              style: ElevatedButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.builder(
              itemCount: _meetings.length,
              itemBuilder: (context, index) {
                final meeting = _meetings[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary: ${meeting.summary}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text('Tasks: ${meeting.tasks.join(', ')}'),
                        const SizedBox(height: 6),
                        Text('Decisions: ${meeting.decisions.join(', ')}'),
                        const SizedBox(height: 6),
                        Text('Date: ${meeting.timestamp}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
