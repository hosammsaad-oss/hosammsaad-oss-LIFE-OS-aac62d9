import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecorderService {
  // 1. تغيير الكلاس إلى AudioRecorder
  final AudioRecorder _record = AudioRecorder(); 
  String? _filePath;

  // بدء التسجيل
  Future<void> startRecording() async {
    // 2. التحقق من الصلاحيات باستخدام الكائن الجديد
    if (!await _record.hasPermission()) {
      throw Exception('Microphone permission not granted');
    }

    final dir = await getApplicationDocumentsDirectory();
    _filePath = '${dir.path}/meeting_${DateTime.now().millisecondsSinceEpoch}.m4a';

    // 3. إعدادات التسجيل (RecordConfig)
    const config = RecordConfig(
      encoder: AudioEncoder.aacLc,
      bitRate: 128000,
      sampleRate: 44100,
    );

    // 4. تمرير الإعدادات والمسار
    await _record.start(config, path: _filePath!);
  }

  // إيقاف التسجيل
  Future<String?> stopRecording() async {
    // stop الآن تعيد المسار المسجل تلقائياً
    final path = await _record.stop();
    return path;
  }

  // ممارسة جيدة: إغلاق المسجل عند الانتهاء من الكلاس
  void dispose() {
    _record.dispose();
  }
}