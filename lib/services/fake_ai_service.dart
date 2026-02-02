import '../models/meeting_result.dart';
import 'openai_service.dart';

class FakeAIService {
  static Future<MeetingResult> processMeeting({String? audioPath}) async {
    final data = await OpenAIService.analyzeAudio(audioPath!);

    return MeetingResult(
      summary: data['summary'],
      tasks: List<String>.from(data['tasks']),
      decisions: List<String>.from(data['decisions']),
    );
  }
}
