import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const CampusChatApp());
}

/// 🧩 Get backend URL depending on platform
String getBackendUrl() {
  if (kIsWeb) return "http://127.0.0.1:8000";
  if (Platform.isAndroid) return "http://10.0.2.2:8000";
  return "http://127.0.0.1:8000";
}

/// 🏫 Root app
class CampusChatApp extends StatefulWidget {
  const CampusChatApp({super.key});

  @override
  State<CampusChatApp> createState() => _CampusChatAppState();
}

class _CampusChatAppState extends State<CampusChatApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void _toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Campus Chatbot",
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(primary: Colors.redAccent),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => LoginScreen(onThemeChanged: _toggleTheme),
        '/admin_dashboard': (_) => AdminDashboard(onThemeChanged: _toggleTheme),
      },
    );
  }
}

// ==================== SERVICES ====================

class ChatService {
  static String get baseUrl => getBackendUrl();

  static Future<Map<String, dynamic>> sendMessage({
    required String message,
    required String sessionId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"message": message, "session_id": sessionId}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/status'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      throw Exception('Failed to get status');
    } catch (e) {
      throw Exception('Status check failed: $e');
    }
  }
}

// ==================== ADMIN SERVICES ====================

class AdminAuthService {
  static String get baseUrl => getBackendUrl();

  static Future<bool> login(String username, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/admin/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<void> logout() async {
    try {
      await http.post(Uri.parse('$baseUrl/admin/logout'));
    } catch (e) {
      // Ignore logout errors
    }
  }
}

class AdminService {
  static String get baseUrl => getBackendUrl();

  static Future<Map<String, dynamic>> getAnalytics() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/analytics'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'total_users': 0,
        'messages_today': 0,
        'active_sessions': 0,
        'top_questions': [],
      };
    } catch (e) {
      return {
        'total_users': 0,
        'messages_today': 0,
        'active_sessions': 0,
        'top_questions': [],
      };
    }
  }

  static Future<List<dynamic>> getFAQs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/faqs'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<void> addFAQ(String question, String answer) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/admin/faqs'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question, 'answer': answer}),
      );
    } catch (e) {
      // Ignore errors for demo
    }
  }

  static Future<void> deleteFAQ(String id) async {
    try {
      await http.delete(Uri.parse('$baseUrl/admin/faqs/$id'));
    } catch (e) {
      // Ignore errors for demo
    }
  }

  static Future<List<dynamic>> getFlaggedMessages() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/flagged-messages'),
      );
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getSystemHealth() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/health'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {
        'api_status': 'unknown',
        'database_status': 'unknown',
        'avg_response_time': 0,
        'memory_usage': 0,
        'uptime': 'Unknown',
      };
    } catch (e) {
      return {
        'api_status': 'unknown',
        'database_status': 'unknown',
        'avg_response_time': 0,
        'memory_usage': 0,
        'uptime': 'Unknown',
      };
    }
  }

  // === ADDED: Chat Logs Service Method ===
  static Future<List<dynamic>> getChatLogs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/admin/chat-logs'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}

class SessionManager {
  static const String _sessionKey = 'chat_session_id';

  static Future<String> getSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    String? sessionId = prefs.getString(_sessionKey);

    if (sessionId == null) {
      sessionId = 'session_${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString(_sessionKey, sessionId);
    }

    return sessionId;
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_sessionKey);
  }
}

// ==================== MODELS ====================

class Message {
  final String sender;
  final String text;
  final DateTime timestamp;
  final double? confidence;
  final String? source;

  Message({
    required this.sender,
    required this.text,
    required this.timestamp,
    this.confidence,
    this.source,
  });

  String get formattedTime => DateFormat('hh:mm a').format(timestamp);
}

// ==================== LOGIN SCREENS ====================

class LoginScreen extends StatelessWidget {
  final Function(bool) onThemeChanged;
  const LoginScreen({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("🎓 Campus Chat Login"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              GestureDetector(
                onLongPress: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          AdminLoginScreen(onThemeChanged: onThemeChanged),
                    ),
                  );
                },
                child: const Icon(
                  Icons.school,
                  size: 80,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Welcome to Campus Chatbot",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                "Your AI assistant for campus information",
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.person),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8A2020),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                ),
                label: const Text("Continue as Student"),
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatScreen(onThemeChanged: onThemeChanged),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminLoginScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const AdminLoginScreen({super.key, required this.onThemeChanged});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _loading = false;

  void _loginAdmin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill in all fields")),
      );
      return;
    }

    setState(() => _loading = true);

    // Try real authentication first, fallback to hardcoded for demo
    bool authenticated = await AdminAuthService.login(username, password);

    if (!authenticated) {
      // Fallback to hardcoded credentials for demo
      if (username == "admin" && password == "admin123") {
        authenticated = true;
      }
    }

    if (authenticated) {
      Navigator.pushReplacementNamed(context, '/admin_dashboard');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Invalid admin credentials"),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Login"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock, size: 80, color: Colors.redAccent),
              const SizedBox(height: 30),
              TextField(
                controller: _usernameController,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              _loading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.login),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8A2020),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      label: const Text("Login as Admin"),
                      onPressed: _loginAdmin,
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LoginScreen(onThemeChanged: widget.onThemeChanged),
                    ),
                  );
                },
                child: const Text("Back to Main Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== ADMIN SCREENS ====================

class AdminDashboard extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const AdminDashboard({super.key, required this.onThemeChanged});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isDark = false;

  void _logout() async {
    await AdminAuthService.logout();
    Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(_isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              setState(() => _isDark = !_isDark);
              widget.onThemeChanged(_isDark);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            "📊 CampusBot Admin Panel",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          _AdminCard(
            icon: Icons.analytics,
            title: "Analytics Dashboard",
            subtitle: "View usage statistics and metrics",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
            ),
          ),

          _AdminCard(
            icon: Icons.school,
            title: "Knowledge Base",
            subtitle: "Manage FAQs and bot responses",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const KnowledgeBaseScreen()),
            ),
          ),

          _AdminCard(
            icon: Icons.security,
            title: "Content Moderation",
            subtitle: "Review flagged messages",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ModerationScreen()),
            ),
          ),

          _AdminCard(
            icon: Icons.health_and_safety,
            title: "System Health",
            subtitle: "Monitor system performance",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SystemHealthScreen()),
            ),
          ),

          _AdminCard(
            icon: Icons.chat,
            title: "Chat Logs",
            subtitle: "View conversation history",
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ViewChatLogsScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AdminCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, size: 32, color: const Color(0xFF8A2020)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: onTap,
      ),
    );
  }
}

// ==================== ANALYTICS SCREEN ====================

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _stats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  void _loadAnalytics() async {
    setState(() => _loading = true);
    final stats = await AdminService.getAnalytics();
    setState(() {
      _stats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Analytics Dashboard"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAnalytics,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _StatCard(
                  title: "Total Users",
                  value: _stats['total_users']?.toString() ?? '0',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
                _StatCard(
                  title: "Messages Today",
                  value: _stats['messages_today']?.toString() ?? '0',
                  icon: Icons.chat,
                  color: Colors.green,
                ),
                _StatCard(
                  title: "Active Sessions",
                  value: _stats['active_sessions']?.toString() ?? '0',
                  icon: Icons.computer,
                  color: Colors.orange,
                ),
                _StatCard(
                  title: "Common Questions",
                  value: _stats['top_questions']?.length.toString() ?? '0',
                  icon: Icons.trending_up,
                  color: Colors.purple,
                ),
                const SizedBox(height: 20),
                if (_stats['top_questions'] != null &&
                    (_stats['top_questions'] as List).isNotEmpty)
                  ..._buildTopQuestions(),
              ],
            ),
    );
  }

  List<Widget> _buildTopQuestions() {
    final questions = _stats['top_questions'] as List;
    return [
      const Text(
        "Top Questions:",
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 10),
      ...questions
          .map(
            (q) => Card(
              child: ListTile(
                leading: const Icon(Icons.question_answer),
                title: Text(q.toString()),
              ),
            ),
          )
          .toList(),
    ];
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== KNOWLEDGE BASE SCREEN ====================

class KnowledgeBaseScreen extends StatefulWidget {
  const KnowledgeBaseScreen({super.key});

  @override
  State<KnowledgeBaseScreen> createState() => _KnowledgeBaseScreenState();
}

class _KnowledgeBaseScreenState extends State<KnowledgeBaseScreen> {
  List<dynamic> _faqs = [];
  final TextEditingController _questionController = TextEditingController();
  final TextEditingController _answerController = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFAQs();
  }

  void _loadFAQs() async {
    setState(() => _loading = true);
    final faqs = await AdminService.getFAQs();
    setState(() {
      _faqs = faqs;
      _loading = false;
    });
  }

  void _addFAQ() async {
    if (_questionController.text.isEmpty || _answerController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in both question and answer"),
        ),
      );
      return;
    }

    await AdminService.addFAQ(_questionController.text, _answerController.text);
    _loadFAQs(); // Refresh list
    _questionController.clear();
    _answerController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("FAQ added successfully")));
  }

  void _deleteFAQ(String id) async {
    await AdminService.deleteFAQ(id);
    _loadFAQs();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("FAQ deleted")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Knowledge Base"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadFAQs),
        ],
      ),
      body: Column(
        children: [
          // Add new FAQ form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _questionController,
                  decoration: const InputDecoration(
                    labelText: "Question",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _answerController,
                  decoration: const InputDecoration(
                    labelText: "Answer",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _addFAQ,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8A2020),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text("Add FAQ"),
                ),
              ],
            ),
          ),
          const Divider(),
          // FAQs list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _faqs.isEmpty
                ? const Center(child: Text("No FAQs found"))
                : ListView.builder(
                    itemCount: _faqs.length,
                    itemBuilder: (context, index) {
                      final faq = _faqs[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(faq['question']?.toString() ?? 'Unknown'),
                          subtitle: Text(
                            faq['answer']?.toString() ?? 'No answer',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteFAQ(faq['id']?.toString() ?? ''),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==================== MODERATION SCREEN ====================

class ModerationScreen extends StatefulWidget {
  const ModerationScreen({super.key});

  @override
  State<ModerationScreen> createState() => _ModerationScreenState();
}

class _ModerationScreenState extends State<ModerationScreen> {
  List<dynamic> _flaggedMessages = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFlaggedMessages();
  }

  void _loadFlaggedMessages() async {
    setState(() => _loading = true);
    final messages = await AdminService.getFlaggedMessages();
    setState(() {
      _flaggedMessages = messages;
      _loading = false;
    });
  }

  void _approveMessage(String messageId) async {
    // Implement approve logic
    _loadFlaggedMessages();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Message approved")));
  }

  void _rejectMessage(String messageId) async {
    // Implement reject logic
    _loadFlaggedMessages();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Message rejected")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Content Moderation"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFlaggedMessages,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _flaggedMessages.isEmpty
          ? const Center(child: Text("No flagged messages"))
          : ListView.builder(
              itemCount: _flaggedMessages.length,
              itemBuilder: (context, index) {
                final message = _flaggedMessages[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(
                      "User: ${message['user_id']?.toString() ?? 'Unknown'}",
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Message: ${message['content']?.toString() ?? 'No content'}",
                        ),
                        Text(
                          "Flagged: ${message['reason']?.toString() ?? 'Unknown reason'}",
                        ),
                        Text(
                          "Time: ${message['timestamp']?.toString() ?? 'Unknown'}",
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check, color: Colors.green),
                          onPressed: () =>
                              _approveMessage(message['id']?.toString() ?? ''),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () =>
                              _rejectMessage(message['id']?.toString() ?? ''),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==================== SYSTEM HEALTH SCREEN ====================

class SystemHealthScreen extends StatefulWidget {
  const SystemHealthScreen({super.key});

  @override
  State<SystemHealthScreen> createState() => _SystemHealthScreenState();
}

class _SystemHealthScreenState extends State<SystemHealthScreen> {
  Map<String, dynamic> _healthStats = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHealthStats();
  }

  void _loadHealthStats() async {
    setState(() => _loading = true);
    final stats = await AdminService.getSystemHealth();
    setState(() {
      _healthStats = stats;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("System Health"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadHealthStats,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _HealthCard(
                  title: "API Status",
                  value: _healthStats['api_status']?.toString() ?? 'Unknown',
                  isGood: _healthStats['api_status'] == 'healthy',
                ),
                _HealthCard(
                  title: "Database",
                  value:
                      _healthStats['database_status']?.toString() ?? 'Unknown',
                  isGood: _healthStats['database_status'] == 'connected',
                ),
                _HealthCard(
                  title: "Response Time",
                  value:
                      "${_healthStats['avg_response_time']?.toString() ?? '0'}ms",
                  isGood: (_healthStats['avg_response_time'] ?? 1000) < 500,
                ),
                _HealthCard(
                  title: "Memory Usage",
                  value: "${_healthStats['memory_usage']?.toString() ?? '0'}%",
                  isGood: (_healthStats['memory_usage'] ?? 100) < 80,
                ),
                _HealthCard(
                  title: "Uptime",
                  value: _healthStats['uptime']?.toString() ?? 'Unknown',
                  isGood: true,
                ),
              ],
            ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  final String title;
  final String value;
  final bool isGood;

  const _HealthCard({
    required this.title,
    required this.value,
    required this.isGood,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              isGood ? Icons.check_circle : Icons.error,
              color: isGood ? Colors.green : Colors.red,
              size: 40,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18,
                      color: isGood ? Colors.green : Colors.red,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== FIXED CHAT LOGS SCREEN ====================

class ViewChatLogsScreen extends StatefulWidget {
  const ViewChatLogsScreen({super.key});

  @override
  State<ViewChatLogsScreen> createState() => _ViewChatLogsScreenState();
}

class _ViewChatLogsScreenState extends State<ViewChatLogsScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadChatLogs();
  }

  void _loadChatLogs() async {
    try {
      final response = await http.get(
        Uri.parse('${getBackendUrl()}/admin/chat-logs'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _logs = jsonDecode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _logs = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat Logs"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadChatLogs),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
          ? const Center(child: Text("No chat logs available"))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _logs.length,
              itemBuilder: (context, index) {
                final log = _logs[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text("User: ${log['user_message'] ?? 'Unknown'}"),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Bot: ${log['bot_reply'] ?? 'No response'}"),
                        Text("Time: ${log['timestamp'] ?? 'Unknown'}"),
                        Text("Source: ${log['source'] ?? 'Unknown'}"),
                      ],
                    ),
                    trailing: Chip(
                      label: Text(
                        "${((log['score'] ?? 0) * 100).toStringAsFixed(0)}%",
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ==================== CHAT SCREEN (UNCHANGED) ====================

class ChatScreen extends StatefulWidget {
  final Function(bool) onThemeChanged;
  const ChatScreen({super.key, required this.onThemeChanged});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  final List<Message> _messages = [];
  bool _isSending = false;
  bool _isDarkMode = false;
  bool _showTypingIndicator = false;
  String _sessionId = '';
  bool _isConnected = false;

  final List<String> _quickReplies = [
    "What time does class start?",
    "Library hours?",
    "When is lunch?",
    "Tell me about campus history",
    "Cafeteria schedule?",
    "Flag ceremony time?",
  ];

  @override
  void initState() {
    super.initState();
    _loadSessionId();
    _checkConnection();
  }

  void _loadSessionId() async {
    _sessionId = await SessionManager.getSessionId();
    setState(() {});
  }

  void _checkConnection() async {
    try {
      await ChatService.getStatus();
      setState(() => _isConnected = true);
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _sendMessage() async {
    final msg = _controller.text.trim();
    if (msg.isEmpty || _isSending) return;

    final now = DateTime.now();
    setState(() {
      _messages.add(Message(sender: "user", text: msg, timestamp: now));
      _controller.clear();
      _isSending = true;
      _showTypingIndicator = true;
    });

    _focusNode.unfocus();

    try {
      final response = await ChatService.sendMessage(
        message: msg,
        sessionId: _sessionId,
      );

      setState(() => _showTypingIndicator = false);

      _sessionId = response["session_id"] ?? _sessionId;

      setState(() {
        _messages.add(
          Message(
            sender: "bot",
            text: response["answer"] ?? "I'm not sure how to respond to that.",
            timestamp: DateTime.now(),
            confidence: response["confidence"]?.toDouble(),
            source: response["source"],
          ),
        );
      });
    } catch (e) {
      setState(() {
        _showTypingIndicator = false;
        _messages.add(
          Message(
            sender: "bot",
            text:
                "❌ Cannot connect to backend. Please check if the server is running.",
            timestamp: DateTime.now(),
          ),
        );
      });
    } finally {
      setState(() => _isSending = false);
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _logout() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(onThemeChanged: widget.onThemeChanged),
      ),
    );
  }

  void _showMessageOptions(Message msg) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: const Text('Copy message'),
            onTap: () {
              Clipboard.setData(ClipboardData(text: msg.text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Message copied to clipboard')),
              );
            },
          ),
          if (msg.confidence != null)
            ListTile(
              leading: const Icon(Icons.analytics),
              title: Text(
                'Confidence: ${(msg.confidence! * 100).toStringAsFixed(1)}%',
              ),
            ),
          if (msg.source != null)
            ListTile(
              leading: const Icon(Icons.source),
              title: Text('Source: ${msg.source}'),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: Icon(
        Icons.circle,
        color: _isConnected ? Colors.green : Colors.red,
        size: 12,
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey.shade800
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 30,
              height: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDot(context),
                  _buildDot(context),
                  _buildDot(context),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              "YXA is typing...",
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.grey.shade400
                    : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDot(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.grey.shade400
            : Colors.grey.shade600,
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildQuickReplies() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      height: 60,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _quickReplies.map((reply) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.grey.shade800
                        : Colors.grey.shade200,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    _controller.text = reply;
                    _sendMessage();
                  },
                  child: Text(
                    reply,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.school, size: 80, color: Colors.grey),
        const SizedBox(height: 16),
        const Text(
          "Ask me about campus life!",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
        const Text(
          "Classes, library, cafeteria, history...",
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 20),
        _buildQuickReplies(),
      ],
    );
  }

  Widget _buildMessage(Message msg, bool isDark) {
    final isUser = msg.sender == "user";

    return GestureDetector(
      onLongPress: () => _showMessageOptions(msg),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            if (!isUser && msg.confidence != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Confidence: ${(msg.confidence! * 100).toStringAsFixed(0)}%",
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
            ],
            Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 12),
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? (isDark
                            ? Colors.redAccent.shade200
                            : const Color(0xFF8A2020))
                      : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: isUser
                        ? const Radius.circular(16)
                        : Radius.zero,
                    bottomRight: isUser
                        ? Radius.zero
                        : const Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: isUser
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      msg.text,
                      style: TextStyle(
                        color: isUser
                            ? Colors.white
                            : (isDark ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.formattedTime,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUser
                            ? Colors.white70
                            : (isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
      child: Column(
        children: [
          if (_messages.isNotEmpty) _buildQuickReplies(),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: "Ask me something about campus...",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onSubmitted: (_) => _sendMessage(),
                ),
              ),
              const SizedBox(width: 8),
              _isSending
                  ? const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.send_rounded,
                        color: isDark
                            ? Colors.redAccent.shade200
                            : const Color(0xFF8A2020),
                        size: 28,
                      ),
                      onPressed: _sendMessage,
                    ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("🎓 Campus Chatbot"),
        backgroundColor: const Color(0xFF8A2020),
        foregroundColor: Colors.white,
        actions: [
          _buildConnectionStatus(),
          IconButton(
            icon: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            onPressed: () {
              setState(() => _isDarkMode = !_isDarkMode);
              widget.onThemeChanged(_isDarkMode);
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: "Logout",
            onPressed: _logout,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount:
                        _messages.length + (_showTypingIndicator ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length && _showTypingIndicator) {
                        return _buildTypingIndicator();
                      }
                      return _buildMessage(_messages[index], isDark);
                    },
                  ),
          ),
          _buildInputBar(isDark),
        ],
      ),
    );
  }
}
