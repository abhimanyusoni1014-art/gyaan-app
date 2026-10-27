import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kBaseUrl = 'https://gyaan-backend-49tu.onrender.com';
// Password GitHub Secret se build ke time aata hai (code me likhna nahi hai)
const kAppSecret = String.fromEnvironment('APP_SECRET');

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Gyaan Saathi',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5), useMaterial3: true),
        home: const ChatPage(),
      );
}

class Msg {
  final String role, text;
  final String question;
  Msg(this.role, this.text, {this.question = ''});
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Msg> _msgs = [
    Msg('model', 'Namaste! Main Gyaan Saathi hoon. Koi bhi sawal poochho 📚')
  ];
  bool _loading = false;
  String _deviceId = 'anon';

  Map<String, String> get _headers =>
      {'Content-Type': 'application/json', 'x-app-secret': kAppSecret};

  @override
  void initState() {
    super.initState();
    _initId();
  }

  Future<void> _initId() async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString('did');
    if (id == null) {
      id = List.generate(16, (_) => Random().nextInt(36).toRadixString(36)).join();
      await p.setString('did', id);
    }
    _deviceId = id;
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    final hist = _msgs.skip(1).map((m) => {'role': m.role, 'text': m.text}).toList();
    setState(() {
      _msgs.add(Msg('user', text));
      _loading = true;
      _ctrl.clear();
    });
    _scrollDown();
    try {
      // Free server soya ho to pehli baar 30-60 second lag sakte hain
      final r = await http
          .post(Uri.parse('$kBaseUrl/chat'),
              headers: _headers,
              body: jsonEncode({'message': text, 'history': hist, 'deviceId': _deviceId}))
          .timeout(const Duration(seconds: 90));
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      final reply = data['reply'] ?? 'Kuch gadbad hui, phir try karo.';
      setState(() => _msgs.add(Msg('model', reply, question: text)));
    } catch (_) {
      setState(() => _msgs.add(Msg('model', 'Internet ya server problem. Thodi der baad phir try karo.')));
    }
    setState(() => _loading = false);
    _scrollDown();
  }

  void _scrollDown() async {
    await Future.delayed(const Duration(milliseconds: 120));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 300,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _report(Msg m) async {
    try {
      await http.post(Uri.parse('$kBaseUrl/report'),
          headers: _headers,
          body: jsonEncode({'message': m.question, 'reply': m.text, 'deviceId': _deviceId}));
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report ho gaya. Shukriya!')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gyaan Saathi')),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length,
            itemBuilder: (_, i) {
              final m = _msgs[i];
              final me = m.role == 'user';
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                  decoration: BoxDecoration(
                    color: me ? Theme.of(context).colorScheme.primaryContainer : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SelectableText(m.text),
                    if (!me && m.question.isNotEmpty)
                      InkWell(
                        onTap: () => _report(m),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 6),
                          child: Text('⚑ Galat jawab report karo',
                              style: TextStyle(fontSize: 11, color: Colors.grey)),
                        ),
                      ),
                  ]),
                ),
              );
            },
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(
                      hintText: 'Apna sawal likho...', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
            ]),
          ),
        ),
      ]),
    );
  }
}
