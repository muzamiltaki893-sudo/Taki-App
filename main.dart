import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // من أجل النسخ للحافظة
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TakiApp());
}

// ==========================================
// 1. نماذج البيانات المتقدمة (Data Models)
// ==========================================
class SuperQAItem {
  String question;
  String correctAnswer;
  List<String> wrongAnswers;

  SuperQAItem({
    required this.question,
    required this.correctAnswer,
    required this.wrongAnswers,
  });

  Map<String, dynamic> toJson() => {
        'q': question,
        'a': correctAnswer,
        'w': wrongAnswers,
      };

  factory SuperQAItem.fromJson(Map<String, dynamic> json) {
    return SuperQAItem(
      question: json['q'] ?? '',
      correctAnswer: json['a'] ?? '',
      wrongAnswers: List<String>.from(json['w'] ?? []),
    );
  }
}

class Subject {
  String name;
  List<SuperQAItem> superQuestionsBank;

  Subject({required this.name, required this.superQuestionsBank});

  Map<String, dynamic> toJson() => {
        'name': name,
        'superQuestionsBank': superQuestionsBank.map((e) => e.toJson()).toList(),
      };

  factory Subject.fromJson(Map<String, dynamic> json) {
    return Subject(
      name: json['name'],
      superQuestionsBank: (json['superQuestionsBank'] as List?)?.map((e) => SuperQAItem.fromJson(e)).toList() ?? [],
    );
  }
}

class UserStats {
  int totalFlashcards;
  int totalQuizQuestions;
  int correctAnswers;
  int wrongAnswers;

  UserStats({
    this.totalFlashcards = 0,
    this.totalQuizQuestions = 0,
    this.correctAnswers = 0,
    this.wrongAnswers = 0,
  });

  Map<String, dynamic> toJson() => {
        'fc': totalFlashcards,
        'qq': totalQuizQuestions,
        'ca': correctAnswers,
        'wa': wrongAnswers,
      };

  factory UserStats.fromJson(Map<String, dynamic> json) => UserStats(
        totalFlashcards: json['fc'] ?? 0,
        totalQuizQuestions: json['qq'] ?? 0,
        correctAnswers: json['ca'] ?? 0,
        wrongAnswers: json['wa'] ?? 0,
      );
}

// ==========================================
// 2. مدير البيانات المحلية السريع (DataManager)
// ==========================================
class DataManager {
  static const String _subjectsKey = 'taki_subjects_v3';
  static const String _userNameKey = 'taki_username_v3';
  static const String _userStatsKey = 'taki_user_stats_v3';

  static Future<String> getUserName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userNameKey) ?? '';
  }

  static Future<void> saveUserName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userNameKey, name);
  }

  static Future<List<Subject>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final String? subjectsJson = prefs.getString(_subjectsKey);
    if (subjectsJson == null) return [];
    try {
      List<dynamic> decoded = jsonDecode(subjectsJson);
      return decoded.map((e) => Subject.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(subjects.map((e) => e.toJson()).toList());
    await prefs.setString(_subjectsKey, encoded);
  }

  static Future<UserStats> getStats() async {
    final prefs = await SharedPreferences.getInstance();
    final String? statsJson = prefs.getString(_userStatsKey);
    if (statsJson == null) return UserStats();
    try {
      return UserStats.fromJson(jsonDecode(statsJson));
    } catch (e) {
      return UserStats();
    }
  }

  static Future<void> recordAnswer({required bool isCorrect, required bool isQuiz}) async {
    final stats = await getStats();
    if (isQuiz) {
      stats.totalQuizQuestions++;
    } else {
      stats.totalFlashcards++;
    }
    if (isCorrect) {
      stats.correctAnswers++;
    } else {
      stats.wrongAnswers++;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userStatsKey, jsonEncode(stats.toJson()));
  }
}

// ==========================================
// 3. الإعدادات الأساسية (TakiApp)
// ==========================================
class TakiApp extends StatelessWidget {
  const TakiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Taki',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'AE')],
      locale: const Locale('ar', 'AE'),
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        primaryColor: const Color(0xFF0052D4),
        fontFamily: 'Tajawal',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF8FAFC),
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Color(0xFF1E293B)),
          titleTextStyle: TextStyle(color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.bold),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// 4. الشاشة الرئيسية ولوحة القيادة (HomeScreen)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String userName = '';
  List<Subject> subjects = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    userName = await DataManager.getUserName();
    subjects = await DataManager.getSubjects();
    if (mounted) setState(() => isLoading = false);
  }

  void _showAIPromptHelper() {
    const String promptText = 
        "قم بقراءة هذا الملف واستخراج 40 إلى 60 سؤالاً قوياً وشاملاً تغطي أهم النقاط. "
        "أريد المخرجات حصراً بصيغة مصفوفة JSON متوافقة مع هذا القالب بالضبط ولا تكتب أي نص إضافي خارج الكود:\n\n"
        "[\n"
        "  {\n"
        "    \"q\": \"اكتب السؤال هنا؟\",\n"
        "    \"a\": \"الإجابة الصحيحة فقط\",\n"
        "    \"w\": [\"إجابة خاطئة 1\", \"إجابة خاطئة 2\", \"إجابة خاطئة 3\"]\n"
        "  }\n"
        "]\n\n"
        "تأكد من أن الأسئلة بنفس لغة الملف الأصلي.";

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.amber),
            SizedBox(width: 10),
            Text('كيفية استخراج الأسئلة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('انسخ هذا الأمر (البرومبت) وألصقه في ChatGPT أو أي ذكاء اصطناعي مع ملف المحاضرة ليقوم بتوليد الأسئلة بالتنسيق المطلوب:', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
              child: Text(promptText, style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: Colors.grey.shade800), textDirection: TextDirection.rtl),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق', style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: promptText));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ بنجاح! اذهب إلى الذكاء الاصطناعي الآن.')));
            },
            icon: const Icon(Icons.copy, color: Colors.white, size: 18),
            label: const Text('نسخ الأمر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showProgressDashboard() async {
    UserStats stats = await DataManager.getStats();
    int totalAnswered = stats.correctAnswers + stats.wrongAnswers;
    double successRate = totalAnswered == 0 ? 0 : (stats.correctAnswers / totalAnswered);
    String evaluationMsg = "مبتدئ يحتاج للتدريب 🚀";
    Color evalColor = Colors.orange;

    if (totalAnswered > 50) {
      if (successRate >= 0.90) { evaluationMsg = "أسطورة المذاكرة 🏆"; evalColor = Colors.amber; }
      else if (successRate >= 0.75) { evaluationMsg = "طالب متفوق 🌟"; evalColor = Colors.green; }
      else if (successRate >= 0.50) { evaluationMsg = "مستوى جيد، استمر 👍"; evalColor = Colors.blue; }
      else { evaluationMsg = "تحتاج إلى مراجعة مكثفة 🚨"; evalColor = Colors.red; }
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(25.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('التقرير الشامل لـ $userName', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(evaluationMsg, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: evalColor)),
            const SizedBox(height: 25),
            Row(
              children: [
                _buildStatCard('إجابة صحيحة', '${stats.correctAnswers}', Colors.green),
                const SizedBox(width: 10),
                _buildStatCard('إجابة خاطئة', '${stats.wrongAnswers}', Colors.red),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard('كروت مراجعة', '${stats.totalFlashcards}', Colors.orange),
                const SizedBox(width: 10),
                _buildStatCard('أسئلة اختبار', '${stats.totalQuizQuestions}', Colors.blue),
              ],
            ),
            const SizedBox(height: 25),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: color.withOpacity(0.3))),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 5),
            Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }

  void _showNameForm() {
    TextEditingController controller = TextEditingController(text: userName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('اسم الطالب', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'أدخل اسمك...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () async {
                  if (controller.text.trim().isNotEmpty) {
                    await DataManager.saveUserName(controller.text.trim());
                    setState(() => userName = controller.text.trim());
                    if (mounted) Navigator.pop(context);
                  }
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // دالة الإضافة السفلية الأصلية لاسم المادة
  void _showAddSubjectForm({String? initialName, Function(String)? onSave}) {
    TextEditingController controller = TextEditingController(text: initialName);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('إضافة/تعديل مادة', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'اسم المادة (مثال: رياضيات)...',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    if (onSave != null) onSave(controller.text.trim());
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF0052D4))));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.help_outline, color: Color(0xFF1E293B)),
          onPressed: _showAIPromptHelper,
        ),
        title: const Text('Taki', style: TextStyle(color: Color(0xFF0052D4), fontSize: 26, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const CircleAvatar(backgroundColor: Color(0xFFE2E8F0), child: Icon(Icons.person, color: Color(0xFF0052D4))),
            onPressed: () {
              if (userName.isEmpty) {
                _showNameForm();
              } else {
                _showProgressDashboard();
              }
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Column(
        children: [
          if (userName.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('أهلاً بك، $userName! 🌟', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  GestureDetector(
                    onTap: _showNameForm,
                    child: const Icon(Icons.edit_note, color: Colors.grey),
                  )
                ],
              ),
            ),
          Expanded(
            child: subjects.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_rounded, size: 80, color: Colors.grey.shade400),
                        const SizedBox(height: 15),
                        Text('لا توجد مواد دراسية بعد', style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 5),
                        Text('اضغط على (+) لإضافة أول مادة لك', style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: subjects.length,
                    itemBuilder: (context, index) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF0052D4), Color(0xFF00C6FF)]),
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [BoxShadow(color: const Color(0xFF0052D4).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectScreen(subject: subjects[index], allSubjects: subjects)));
                                  setState(() {}); 
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(subjects[index].name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                                      ),
                                      const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                                      const SizedBox(width: 5),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 22),
                              onPressed: () {
                                _showAddSubjectForm(
                                  initialName: subjects[index].name,
                                  onSave: (val) async {
                                    subjects[index].name = val;
                                    await DataManager.saveSubjects(subjects);
                                    setState(() {});
                                  },
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('حذف المادة'),
                                    content: Text('متأكد من حذف "${subjects[index].name}"؟'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
                                      TextButton(
                                        onPressed: () async {
                                          subjects.removeAt(index);
                                          await DataManager.saveSubjects(subjects);
                                          if(mounted) { Navigator.pop(ctx); setState(() {}); }
                                        },
                                        child: const Text('حذف', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Padding(
            padding: EdgeInsets.all(15.0),
            child: Text('هذا التطبيق من مؤسسة تكي التعليمية', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 75), 
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0052D4),
        onPressed: () => _showAddSubjectForm(
          onSave: (val) async {
            subjects.add(Subject(name: val, superQuestionsBank: []));
            await DataManager.saveSubjects(subjects);
            setState(() {});
          },
        ),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة مادة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ==========================================
// 5. واجهة المادة (الاستيراد الذكي والاختبارات)
// ==========================================
class SubjectScreen extends StatefulWidget {
  final Subject subject;
  final List<Subject> allSubjects;
  const SubjectScreen({super.key, required this.subject, required this.allSubjects});

  @override
  State<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends State<SubjectScreen> {
  
  void _showSmartImportSheet() {
    TextEditingController importController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 20, right: 20, top: 25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text('استيراد الأسئلة الذكي', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 10),
            Text('قم بلصق كود الـ JSON المستخرج من الذكاء الاصطناعي هنا، وسيقوم التطبيق بمعالجته وحفظه فوراً.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 15),
            TextField(
              controller: importController,
              maxLines: 8,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: '[\n  {\n    "q": "...",\n    "a": "...",\n    "w": ["..."]\n  }\n]',
                hintStyle: TextStyle(color: Colors.grey.shade400, fontFamily: 'monospace'),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  String pastedText = importController.text.trim();
                  if (pastedText.isEmpty) return;

                  try {
                    List<dynamic> decoded = jsonDecode(pastedText);
                    int addedCount = 0;

                    for (var item in decoded) {
                      if (item['q'] != null && item['a'] != null) {
                        List<String> wrongs = [];
                        if (item['w'] != null && item['w'] is List) {
                          wrongs = List<String>.from(item['w']);
                        }
                        // حماية تأمينية: إذا نسي الذكاء الاصطناعي إضافة 3 خيارات خاطئة، نكملها نحن
                        while (wrongs.length < 3) {
                          wrongs.add('خيار مستبعد ${wrongs.length + 1}');
                        }

                        widget.subject.superQuestionsBank.add(
                          SuperQAItem(question: item['q'].toString(), correctAnswer: item['a'].toString(), wrongAnswers: wrongs)
                        );
                        addedCount++;
                      }
                    }

                    await DataManager.saveSubjects(widget.allSubjects);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('نجاح! تم استيراد $addedCount سؤال جديد للبَنك.')));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('عذراً، صيغة النص غير صحيحة. تأكد من نسخ قالب JSON بالكامل.')));
                  }
                },
                icon: const Icon(Icons.download, color: Colors.white),
                label: const Text('بدء الاستيراد والمعالجة', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.subject.name)),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                children: [
                  Text('بنك الأسئلة الشامل: ${widget.subject.superQuestionsBank.length} سؤال', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE67E22), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                          icon: const Icon(Icons.style, color: Colors.white),
                          label: const Text('كروت التذكر', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (widget.subject.superQuestionsBank.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('البنك فارغ. قم باستيراد الأسئلة أولاً.')));
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => FlashcardScreen(questions: widget.subject.superQuestionsBank)));
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), padding: const EdgeInsets.symmetric(vertical: 12), elevation: 0),
                          icon: const Icon(Icons.quiz, color: Colors.white),
                          label: const Text('بدء اختبار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            if (widget.subject.superQuestionsBank.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الاختبار يتطلب وجود أسئلة في البنك.')));
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => QuizPlayScreen(questions: widget.subject.superQuestionsBank)));
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            const SizedBox(height: 25),
            const Text('نظرة على الأسئلة:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: widget.subject.superQuestionsBank.isEmpty
                  ? Center(child: Text('لا توجد أسئلة. استخدم الاستيراد الذكي.', style: TextStyle(color: Colors.grey.shade500)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.subject.superQuestionsBank.length,
                      itemBuilder: (context, index) {
                        final item = widget.subject.superQuestionsBank[index];
                        return Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade300)),
                          child: ListTile(
                            title: Text(item.question, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('الجواب: ${item.correctAnswer}', style: const TextStyle(color: Color(0xFF0052D4))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () async {
                                setState(() => widget.subject.superQuestionsBank.removeAt(index));
                                await DataManager.saveSubjects(widget.allSubjects);
                              },
                            ),
                          ),
                        );
                      }
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0052D4),
        onPressed: _showSmartImportSheet,
        icon: const Icon(Icons.auto_awesome_motion, color: Colors.white),
        label: const Text('استيراد أسئلة', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ==========================================
// 6. شاشة الفلاش كاردز (الكتابة اليدوية مع إحصائيات)
// ==========================================
class FlashcardScreen extends StatefulWidget {
  final List<SuperQAItem> questions;
  const FlashcardScreen({super.key, required this.questions});

  @override
  State<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends State<FlashcardScreen> {
  late List<SuperQAItem> shuffledBank;
  int currentIndex = 0;
  bool isChecked = false;
  bool isCorrect = false;
  TextEditingController answerController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // خلط الأسئلة عشوائياً للمراجعة
    shuffledBank = List.from(widget.questions)..shuffle();
  }

  String _normalizeArabic(String text) {
    return text.replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
               .replaceAll('ة', 'ه').trim().toLowerCase();
  }

  void _checkAnswer() async {
    if (answerController.text.trim().isEmpty) return;
    
    String userAnswer = _normalizeArabic(answerController.text);
    String correctAnswer = _normalizeArabic(shuffledBank[currentIndex].correctAnswer);

    bool result = userAnswer == correctAnswer;
    setState(() {
      isChecked = true;
      isCorrect = result;
    });

    // تسجيل الأداء في لوحة القيادة
    await DataManager.recordAnswer(isCorrect: result, isQuiz: false);
  }

  void _nextCard() {
    if (currentIndex < shuffledBank.length - 1) {
      setState(() {
        currentIndex++;
        isChecked = false;
        answerController.clear();
      });
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أحسنت! أنهيت مراجعة كل الكروت لهذه الجلسة.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    SuperQAItem currentQ = shuffledBank[currentIndex];
    
    return Scaffold(
      appBar: AppBar(title: Text('كارت ${currentIndex + 1} من ${shuffledBank.length}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 15, offset: Offset(0, 5))]),
              child: Text(currentQ.question, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.5), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 40),
            if (!isChecked) ...[
              TextField(
                controller: answerController,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  hintText: 'اكتب إجابتك هنا...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  contentPadding: const EdgeInsets.symmetric(vertical: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide(color: Colors.grey.shade300)),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _checkAnswer,
                child: const Text('تأكيد الإجابة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: isCorrect ? const Color(0xFF2ECC71).withOpacity(0.1) : const Color(0xFFE74C3C).withOpacity(0.1), borderRadius: BorderRadius.circular(15), border: Border.all(color: isCorrect ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C))),
                child: Column(
                  children: [
                    Icon(isCorrect ? Icons.check_circle : Icons.cancel, color: isCorrect ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C), size: 60),
                    const SizedBox(height: 10),
                    Text(isCorrect ? 'إجابة صحيحة ممتاز!' : 'إجابة خاطئة!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isCorrect ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C))),
                    if (!isCorrect) ...[
                      const Divider(),
                      const Text('الإجابة الصحيحة هي:', style: TextStyle(fontSize: 16, color: Colors.grey)),
                      Text(currentQ.correctAnswer, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    ]
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _nextCard,
                child: const Text('متابعة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ]
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 7. شاشة الاختبار الخارق (اختيار من متعدد الدقيق)
// ==========================================
class QuizPlayScreen extends StatefulWidget {
  final List<SuperQAItem> questions;
  const QuizPlayScreen({super.key, required this.questions});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  int currentIndex = 0;
  int score = 0;
  bool isAnswered = false;
  int selectedOptionIndex = -1;
  late List<SuperQAItem> quizSession;
  late List<String> currentOptions;

  @override
  void initState() {
    super.initState();
    // بناء اختبار من 20 سؤال عشوائي كحد أقصى
    quizSession = List.from(widget.questions)..shuffle();
    if (quizSession.length > 20) quizSession = quizSession.take(20).toList();
    _loadCurrentQuestionOptions();
  }

  void _loadCurrentQuestionOptions() {
    SuperQAItem q = quizSession[currentIndex];
    // دمج الإجابة الصحيحة مع الخاطئة ثم خلطها
    List<String> options = [q.correctAnswer, ...q.wrongAnswers];
    options.shuffle();
    currentOptions = options;
  }

  void _submitAnswer(int index) async {
    if (isAnswered) return;
    
    bool isCorrectOpt = currentOptions[index] == quizSession[currentIndex].correctAnswer;
    
    setState(() {
      selectedOptionIndex = index;
      isAnswered = true;
      if (isCorrectOpt) score++;
    });

    // تسجيل الأداء في لوحة القيادة
    await DataManager.recordAnswer(isCorrect: isCorrectOpt, isQuiz: true);
  }

  void _nextQuestion() {
    if (currentIndex < quizSession.length - 1) {
      setState(() {
        currentIndex++;
        isAnswered = false;
        selectedOptionIndex = -1;
        _loadCurrentQuestionOptions();
      });
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ScoreScreen(score: score, total: quizSession.length)));
    }
  }

  @override
  Widget build(BuildContext context) {
    SuperQAItem currentQ = quizSession[currentIndex];
    double progress = (currentIndex + 1) / quizSession.length;

    return Scaffold(
      appBar: AppBar(title: Text('سؤال ${currentIndex + 1} / ${quizSession.length}')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            LinearProgressIndicator(value: progress, backgroundColor: Colors.grey.shade300, valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0052D4)), minHeight: 6, borderRadius: BorderRadius.circular(5)),
            const SizedBox(height: 30),
            Text(currentQ.question, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, height: 1.5), textAlign: TextAlign.center),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: currentOptions.length,
                itemBuilder: (context, index) {
                  bool isCorrectOpt = currentOptions[index] == currentQ.correctAnswer;
                  Color bgColor = Colors.white;
                  Color borderColor = Colors.grey.shade300;
                  Color textColor = Colors.black87;
                  
                  if (isAnswered) {
                    if (isCorrectOpt) {
                      bgColor = const Color(0xFF2ECC71); borderColor = const Color(0xFF2ECC71); textColor = Colors.white;
                    } else if (index == selectedOptionIndex) {
                      bgColor = const Color(0xFFE74C3C).withOpacity(0.8); borderColor = Colors.transparent; textColor = Colors.white;
                    }
                  } else if (index == selectedOptionIndex) {
                    bgColor = const Color(0xFF0052D4).withOpacity(0.1); borderColor = const Color(0xFF0052D4);
                  }

                  return GestureDetector(
                    onTap: () => setState(() => selectedOptionIndex = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(15), border: Border.all(color: borderColor, width: 2)),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 12, backgroundColor: isAnswered ? Colors.white : Colors.grey.shade200, child: Text(String.fromCharCode(65 + index), style: TextStyle(color: isAnswered ? bgColor : Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold))),
                          const SizedBox(width: 15),
                          Expanded(child: Text(currentOptions[index], style: TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            if (isAnswered)
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0052D4), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: _nextQuestion,
                child: const Text('التالي', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              )
            else
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1E293B), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: selectedOptionIndex == -1 ? null : () => _submitAnswer(selectedOptionIndex),
                child: const Text('تأكيد الإجابة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 8. شاشة النتيجة النهائية (Duolingo Style)
// ==========================================
class ScoreScreen extends StatelessWidget {
  final int score;
  final int total;
  const ScoreScreen({super.key, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    double percentage = score / total;
    
    String message = '';
    Color themeColor = Colors.grey;
    IconData resultIcon = Icons.sentiment_neutral;

    if (percentage == 1.0) {
      message = "أسطورة! علامة كاملة 🏆"; themeColor = Colors.amber; resultIcon = Icons.military_tech;
    } else if (percentage >= 0.8) {
      message = "رائع! أنت بطل 🌟"; themeColor = const Color(0xFF2ECC71); resultIcon = Icons.emoji_events;
    } else if (percentage >= 0.5) {
      message = "عمل جيد! استمر 👏"; themeColor = const Color(0xFF0052D4); resultIcon = Icons.thumb_up_alt;
    } else {
      message = "حاول مرة أخرى! 💪"; themeColor = const Color(0xFFE74C3C); resultIcon = Icons.sentiment_dissatisfied;
    }

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(resultIcon, size: 130, color: themeColor),
              const SizedBox(height: 25),
              Text(message, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: themeColor)),
              const SizedBox(height: 15),
              Text('لقد أجبت بشكل صحيح على', style: TextStyle(fontSize: 18, color: Colors.grey.shade600)),
              Text('$score / $total', style: TextStyle(fontSize: 55, fontWeight: FontWeight.w900, color: themeColor)),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: themeColor, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('العودة للمادة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
