import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart'; // هذا الملف يتم توليده عند ربط المشروع بـ Firebase CLI

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const LifeOSApp());
}

class LifeOSApp extends StatelessWidget {
  const LifeOSApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.dark),
      home: const MeetingRoom(),
    );
  }
}

class MeetingRoom extends StatefulWidget {
  const MeetingRoom({super.key});
  @override
  State<MeetingRoom> createState() => _MeetingRoomState();
}

class _MeetingRoomState extends State<MeetingRoom> {
  late AudioRecorder audioRecorder;
  bool isRecording = false;
  bool isProcessing = false;
  bool isAnalyzing = false;
  Timer? _timer;
  int _recordDuration = 0;
  String transcript = "";
  String analysisResult = "";

  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
  }

  Future<void> saveToCloud() async {
    try {
      await FirebaseFirestore.instance.collection('meetings').add({
        'date': DateTime.now(),
        'transcript': transcript,
        'analysis': analysisResult,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✨ تم حفظ الاجتماع في سحابة Life OS')),
      );
    } catch (e) {
      debugPrint("Cloud Save Error: $e");
    }
  }

  // --- المنطق البرمجي الأساسي ---
  Future<void> startRecording() async {
    try {
      if (await audioRecorder.hasPermission()) {
        await audioRecorder.start(const RecordConfig(), path: '');
        setState(() {
          isRecording = true;
          isProcessing = false;
          isAnalyzing = false;
          _recordDuration = 0;
          transcript = "";
          analysisResult = "";
        });
        _startTimer();
      }
    } catch (e) {
      debugPrint("$e");
    }
  }

  Future<void> stopRecording() async {
    _timer?.cancel();
    final path = await audioRecorder.stop();
    setState(() {
      isRecording = false;
      isProcessing = true;
    });
    if (path != null) await sendToGroqWhisper(path);
  }

  Future<void> sendToGroqWhisper(String path) async {
    const apiKey = "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";
    try {
      final audioBytes = await http.readBytes(Uri.parse(path));
      var request =
          http.MultipartRequest(
              'POST',
              Uri.parse("https://api.groq.com/openai/v1/audio/transcriptions"),
            )
            ..headers['Authorization'] = 'Bearer $apiKey'
            ..files.add(
              http.MultipartFile.fromBytes(
                'file',
                audioBytes,
                filename: 'audio.m4a',
                contentType: MediaType('audio', 'm4a'),
              ),
            )
            ..fields['model'] = 'whisper-large-v3'
            ..fields['language'] = 'ar';
      var res = await request.send();
      var data = await res.stream.bytesToString();
      setState(() {
        transcript = json.decode(data)['text'] ?? "";
        isProcessing = false;
      });
    } catch (e) {
      setState(() {
        isProcessing = false;
      });
    }
  }

  Future<void> analyzeMeeting() async {
    setState(() => isAnalyzing = true);
    try {
      var response = await http.post(
        Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
        headers: {
          'Authorization':
              'Bearer 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',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "user",
              "content":
                  "حلل النص التالي واستخرج المهام والقرارات بالعربية بنقاط واضحة: $transcript",
            },
          ],
        }),
      );
      var decodedData = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        analysisResult = decodedData['choices'][0]['message']['content'];
        isAnalyzing = false;
      });
      await saveToCloud();
    } catch (e) {
      setState(() {
        isAnalyzing = false;
      });
    }
  }

  void _startTimer() => _timer = Timer.periodic(
    const Duration(seconds: 1),
    (t) => setState(() => _recordDuration++),
  );

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // الخلفية المتدرجة
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF1E1B4B),
                  Color(0xFF581C87),
                ],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  const Text(
                    "LIFE OS",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // بطاقة العداد
                  _buildGlassWrapper(
                    child: Column(
                      children: [
                        Text(
                          _formatDuration(_recordDuration),
                          style: const TextStyle(
                            fontSize: 65,
                            fontWeight: FontWeight.w100,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildRecordButton(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  if (isProcessing || transcript.isNotEmpty)
                    _buildSectionCard(
                      title: "التفريغ النصي",
                      content: transcript,
                      isLoading: isProcessing,
                      icon: Icons.short_text,
                    ),

                  const SizedBox(height: 20),
                  if (transcript.isNotEmpty && !isRecording && !isProcessing)
                    _buildMagicButton(),

                  const SizedBox(height: 20),
                  if (isAnalyzing || analysisResult.isNotEmpty)
                    _buildSectionCard(
                      title: "التحليل الذكي",
                      content: analysisResult,
                      isLoading: isAnalyzing,
                      icon: Icons.auto_awesome,
                      isHighlight: true,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // وحدة البناء الأساسية للتأثير الزجاجي
  Widget _buildGlassWrapper({required Widget child, bool isHighlight = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: isHighlight
                  ? Colors.purpleAccent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // بطاقة الأقسام (تفريغ / تحليل)
  Widget _buildSectionCard({
    required String title,
    required String content,
    bool isLoading = false,
    required IconData icon,
    bool isHighlight = false,
  }) {
    return _buildGlassWrapper(
      isHighlight: isHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: isHighlight ? Colors.purpleAccent : Colors.white70,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isHighlight ? Colors.purpleAccent : Colors.white70,
                ),
              ),
            ],
          ),
          const Divider(height: 25, color: Colors.white10),
          isLoading
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      color: Colors.purpleAccent,
                    ),
                  ),
                )
              : Text(
                  content,
                  style: const TextStyle(
                    color: Colors.white,
                    height: 1.6,
                    fontSize: 16,
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: isRecording ? stopRecording : startRecording,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.redAccent : Colors.white.withOpacity(0.1),
          boxShadow: [
            BoxShadow(
              color: isRecording
                  ? Colors.redAccent.withOpacity(0.5)
                  : Colors.purpleAccent.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Icon(
          isRecording ? Icons.stop : Icons.mic,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildMagicButton() {
    return ElevatedButton(
      onPressed: isAnalyzing ? null : analyzeMeeting,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.purpleAccent,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 60),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 10,
        shadowColor: Colors.purpleAccent.withOpacity(0.5),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_fix_high),
          SizedBox(width: 15),
          Text(
            "تحليل الاجتماع بالذكاء الاصطناعي",
            style: TextStyle(fontWeight: FontWeight.bold),
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
