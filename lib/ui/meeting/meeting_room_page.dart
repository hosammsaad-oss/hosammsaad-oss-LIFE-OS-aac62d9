import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:async';

class MeetingRoom extends StatefulWidget {
  const MeetingRoom({super.key});

  @override
  _MeetingRoomState createState() => _MeetingRoomState();
}

class _MeetingRoomState extends State<MeetingRoom> {
  late AudioRecorder audioRecorder;
  bool isRecording = false;
  Timer? _timer;
  int _recordDuration = 0;

  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
  }

  // دالة بدء التسجيل مع معالجة الأخطاء (UX)
  Future<void> startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        // إعدادات التسجيل للويب
        const config = RecordConfig();

        await audioRecorder.start(
          config,
          path: '',
        ); // في الويب المسار يكون فارغاً مؤقتاً

        setState(() {
          isRecording = true;
          _recordDuration = 0;
        });
        _startTimer();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('نحتاج إذن المايك للبدء في تسجيل الاجتماع 🎙️'),
          ),
        );
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  // توقف التسجيل
  Future<void> stopRecording() async {
    _timer?.cancel();
    final path = await audioRecorder.stop();
    setState(() => isRecording = false);

    // هنا سننتقل للمرحلة 3 لاحقاً (إرسال الملف للـ AI)
    print("تم حفظ الملف في: $path");
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      setState(() => _recordDuration++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Life OS - Meeting Room"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // عداد الزمن والحالة
          Text(
            isRecording ? "جاري تسجيل الاجتماع..." : "مستعد للبدء",
            style: TextStyle(
              color: isRecording ? Colors.red : Colors.grey,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 40),

          // زر التسجيل الذكي
          Center(
            child: GestureDetector(
              onTap: isRecording ? stopRecording : startRecording,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: isRecording ? Colors.red : Colors.blue,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (isRecording ? Colors.red : Colors.blue)
                          .withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),

          // مساحة نص التفريغ (ستستخدم في المرحلة 3)
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: const Text(
                "هنا سيظهر تفريغ الاجتماع (Transcript) فور البدء...",
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    audioRecorder.dispose();
    super.dispose();
  }
}
