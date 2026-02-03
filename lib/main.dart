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
import 'package:flutter_dotenv/flutter_dotenv.dart'; // تأكد من الاستيراد





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
StreamSubscription<Amplitude>? _amplitudeSub;
double _currentAmplitude = 0.0;
Amplitude? _amplitude;
  @override
  void initState() {
    super.initState();
    audioRecorder = AudioRecorder();
  }

  //كود بناء الشريط الجانبي (Sidebar)

Widget _buildSidebar(BuildContext context) {
  return Drawer(
    child: Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A), // لون داكن متناسق مع الخلفية
      ),
      child: Column(
        children: [

          //زر التنقل للارشيف 
          
          IconButton(
  icon: const Icon(Icons.history, color: Colors.white70, size: 30),
  onPressed: () => Navigator.push(
    context, 
    MaterialPageRoute(builder: (context) => const MeetingHistory())
  ),
),
          // رأس القائمة الجانبية
          DrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1E1B4B), Color(0xFF581C87)],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.purpleAccent, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "LIFE OS MENU",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // زر السجل
        ListTile(
  leading: const Icon(Icons.history, color: Colors.purpleAccent),
  title: const Text("سجل الاجتماعات", style: TextStyle(color: Colors.white)),
  onTap: () {
    Navigator.pop(context); // يغلق السايد بار أولاً
    // نستخدم Navigator.push للانتقال للصفحة
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MeetingHistory()),
    );
  },
),
          const Divider(color: Colors.white10),

          // مساحة للإضافات المستقبلية
          ListTile(
            leading: const Icon(Icons.settings, color: Colors.white38),
            title: const Text("الإعدادات (قريباً)", style: TextStyle(color: Colors.white38)),
            onTap: null,
          ),

          const Spacer(), // يدفع العناصر التالية للأسفل
          
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text("Version 1.0.0", style: TextStyle(color: Colors.white24, fontSize: 12)),
          ),
        ],
      ),
    ),
  );
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
      // 1. بدء التسجيل أولاً
      await audioRecorder.start(const RecordConfig(), path: '');

      // 2. بدء الاستماع للذبذبات وتحديث الحالة
      _amplitudeSub = audioRecorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
        setState(() {
          // قيم الـ dB تكون من -160 إلى 0. نحولها لنسبة مئوية من 0 إلى 1
          _currentAmplitude = (amp.current + 160) / 160; 
        });
      });

      setState(() {
        isRecording = true;
        _recordDuration = 0;
      });
      _startTimer();
    }
  } catch (e) {
    debugPrint("Start Error: $e");
  }
}
  Future<void> stopRecording() async {
    _timer?.cancel();
    _amplitudeSub?.cancel();
    final path = await audioRecorder.stop();
    setState(() {
      isRecording = false;
      isProcessing = true;
      _currentAmplitude = 0;
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
      var decoded = json.decode(data);
      setState(() {
        transcript = decoded['text'] ?? "";
        isProcessing = false;
      });
    } catch (e) {
      print("Error: $e");
      setState(() {
        setState(() => isProcessing = false);
      });
    }
  }

  Future<void> analyzeMeeting() async {
  if (transcript.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('عذراً، لا يوجد نص لتحليله!')),
    );
    return;
  }

  setState(() => isAnalyzing = true);
  
  try {
    // استخدم المفتاح مباشرة للتجربة لضمان عدم وجود مشكلة في .env
    const apiKey = "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";
    
    var response = await http.post(
      Uri.parse("https://api.groq.com/openai/v1/chat/completions"),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "llama-3.3-70b-versatile",
        "messages": [
          {
            "role": "user",
            "content": "حلل النص التالي واستخرج المهام والقرارات بالعربية بنقاط واضحة: $transcript",
          },
        ],
      }),
    );

    if (response.statusCode == 200) {
      var decodedData = json.decode(utf8.decode(response.bodyBytes));
      setState(() {
        analysisResult = decodedData['choices'][0]['message']['content'];
        isAnalyzing = false;
      });
      await saveToCloud(); // حفظ في السحاب بعد النجاح
    } else {
      throw Exception("Failed to analyze");
    }
  } catch (e) {
    setState(() => isAnalyzing = false);
    debugPrint("Analysis Error: $e");
  }
}

 void _startTimer() {
  _timer?.cancel(); // نوقف أي عداد قديم شغال قبل ما نبدأ الجديد
  _timer = Timer.periodic(
    const Duration(seconds: 1),
    (t) => setState(() => _recordDuration++),
  );
}

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: _buildSidebar(context),
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




          // زر يدوي لفتح القائمة الجانبية
Positioned(
  top: 40,
  left: 20,
  child: Builder(
    builder: (context) => IconButton(
      icon: const Icon(Icons.menu, color: Colors.white70, size: 30),
      onPressed: () => Scaffold.of(context).openDrawer(),
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
                        _buildVisualizer(), // <-- الاضافه الجديد 
                        const SizedBox(height: 20),
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
Widget _buildVisualizer() {
  return SizedBox(
    height: 60,
    width: double.infinity,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(15, (index) {
        // حساب ارتفاع العمود بناءً على قوة الصوت مع لمسة عشوائية
        double height = 5 + (_currentAmplitude * 50 * (0.5 + (index % 5) * 0.2));
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 4,
          height: isRecording ? height.clamp(5.0, 60.0) : 5.0,
          decoration: BoxDecoration(
            color: isRecording ? Colors.purpleAccent : Colors.white24,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isRecording ? [
              BoxShadow(color: Colors.purpleAccent.withOpacity(0.3), blurRadius: 5)
            ] : [],
          ),
        );
      }),
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


class MeetingHistory extends StatelessWidget {
  const MeetingHistory({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text("أرشيف الذكاء الاصطناعي", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E1B4B), Color(0xFF581C87)],
          ),
        ),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance
              .collection('meetings')
              .orderBy('date', descending: true)
              .snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(color: Colors.purpleAccent));
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 100, left: 20, right: 20),
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                var doc = snapshot.data!.docs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 15),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (doc['date'] as Timestamp).toDate().toString().substring(0, 16),
                              style: const TextStyle(color: Colors.purpleAccent, fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              doc['analysis'],
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}