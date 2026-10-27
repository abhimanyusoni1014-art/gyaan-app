import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const kBaseUrl = 'https://gyaan-backend-49tu.onrender.com';
// Ye dono GitHub Secrets se build ke time aate hain
const kSbUrl = String.fromEnvironment('SUPABASE_URL');
const kSbKey = String.fromEnvironment('SUPABASE_ANON_KEY');

const kBg = Color(0xFF08080C);
const kAccent = Color(0xFF818CF8);

void main() => runApp(const SimuneApp());

class SimuneApp extends StatelessWidget {
  const SimuneApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Simune',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF6366F1), brightness: Brightness.dark),
          scaffoldBackgroundColor: kBg,
          appBarTheme: const AppBarTheme(backgroundColor: kBg, elevation: 0),
        ),
        home: const SplashPage(),
      );
}

// ---------------- LOGIN / SESSION (Supabase) ----------------
class Auth {
  static String? access, refresh, email;
  static int expiresAt = 0;
  static bool get loggedIn => refresh != null && refresh!.isNotEmpty;

  static Map<String, String> get _h =>
      {'apikey': kSbKey, 'Content-Type': 'application/json'};

  static Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    access = p.getString('at');
    refresh = p.getString('rt');
    email = p.getString('em');
    expiresAt = p.getInt('ex') ?? 0;
  }

  static Future<void> _store(Map<String, dynamic> d) async {
    final p = await SharedPreferences.getInstance();
    access = d['access_token'] as String?;
    refresh = d['refresh_token'] as String?;
    final u = d['user'];
    if (u is Map && u['email'] != null) email = u['email'].toString();
    final exp = (d['expires_in'] as num?)?.toInt() ?? 3600;
    expiresAt = DateTime.now().millisecondsSinceEpoch ~/ 1000 + exp;
    await p.setString('at', access ?? '');
    await p.setString('rt', refresh ?? '');
    await p.setString('em', email ?? '');
    await p.setInt('ex', expiresAt);
  }

  static String _err(dynamic body) {
    if (body is Map) {
      final m = (body['msg'] ?? body['error_description'] ?? body['message'] ?? '').toString();
      if (m.contains('Invalid login')) return 'Email ya password galat hai.';
      if (m.contains('already')) return 'Ye email pehle se registered hai. Login karo.';
      if (m.contains('at least')) return 'Password kam se kam 6 akshar ka rakho.';
      if (m.isNotEmpty) return m;
    }
    return 'Kuch gadbad hui. Phir try karo.';
  }

  /// Error message return karta hai, success par null.
  static Future<String?> submit(String e, String p, {required bool signUp}) async {
    if (kSbUrl.isEmpty || kSbKey.isEmpty) return 'App ka setup adhura hai (Supabase).';
    try {
      final url = signUp
          ? '$kSbUrl/auth/v1/signup'
          : '$kSbUrl/auth/v1/token?grant_type=password';
      final r = await http
          .post(Uri.parse(url), headers: _h, body: jsonEncode({'email': e, 'password': p}))
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(utf8.decode(r.bodyBytes));
      if (r.statusCode >= 400) return _err(body);
      if (body is Map<String, dynamic> && body['access_token'] != null) {
        await _store(body);
        return null;
      }
      return 'Email confirm karo: inbox me link bheja gaya hai, phir login karo.';
    } catch (_) {
      return 'Internet problem. Phir try karo.';
    }
  }

  static Future<String?> token() async {
    if (!loggedIn) return null;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (access != null && access!.isNotEmpty && now < expiresAt - 60) return access;
    try {
      final r = await http
          .post(Uri.parse('$kSbUrl/auth/v1/token?grant_type=refresh_token'),
              headers: _h, body: jsonEncode({'refresh_token': refresh}))
          .timeout(const Duration(seconds: 30));
      if (r.statusCode == 200) {
        await _store(jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>);
        return access;
      }
      if (r.statusCode >= 400 && r.statusCode < 500) await logout();
    } catch (_) {}
    return null;
  }

  static Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.remove('at');
    await p.remove('rt');
    await p.remove('em');
    await p.remove('ex');
    access = null;
    refresh = null;
    email = null;
    expiresAt = 0;
  }
}

// ---------------- LOGO + ANIMATIONS ----------------
class SimuneLogo extends StatefulWidget {
  final double size;
  final bool spin;
  const SimuneLogo({super.key, this.size = 100, this.spin = false});
  @override
  State<SimuneLogo> createState() => _SimuneLogoState();
}

class _SimuneLogoState extends State<SimuneLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _r =
      AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.spin) _r.repeat();
  }

  @override
  void dispose() {
    _r.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(alignment: Alignment.center, children: [
        RotationTransition(
            turns: _r, child: CustomPaint(size: Size(s, s), painter: _RingPainter())),
        Text('S',
            style: TextStyle(
                fontSize: s * 0.46,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                height: 1)),
      ]),
    );
  }
}

class _RingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * 0.42;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFFEDEDF5);
    const start = -math.pi / 3;
    const sweep = 295 * math.pi / 180;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), start, sweep, false, ring);
    final dot = Offset(c.dx + r * math.cos(start), c.dy + r * math.sin(start));
    canvas.drawCircle(dot, size.width * 0.045, Paint()..color = kAccent);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class TypingDots extends StatefulWidget {
  const TypingDots({super.key});
  @override
  State<TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (_c.value - i * 0.18) % 1.0;
          final y = -6 * math.sin(t * math.pi);
          return Transform.translate(
            offset: Offset(0, y),
            child: Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: const BoxDecoration(color: kAccent, shape: BoxShape.circle),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------- SPLASH ----------------
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
        ..forward();

  @override
  void initState() {
    super.initState();
    _go();
  }

  Future<void> _go() async {
    await Auth.load();
    await Future.delayed(const Duration(milliseconds: 2500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, __, ___) => Auth.loggedIn ? const ChatPage() : const LoginPage(),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _c, curve: const Interval(0.5, 1.0));
    return Scaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ScaleTransition(
            scale: CurvedAnimation(parent: _c, curve: Curves.elasticOut),
            child: const SimuneLogo(size: 150, spin: true),
          ),
          const SizedBox(height: 28),
          FadeTransition(
            opacity: fade,
            child: const Text('Simune',
                style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ),
          const SizedBox(height: 6),
          FadeTransition(
            opacity: fade,
            child: const Text('Aapka AI Saathi', style: TextStyle(color: kAccent, fontSize: 16)),
          ),
          const SizedBox(height: 44),
          FadeTransition(opacity: fade, child: const TypingDots()),
        ]),
      ),
    );
  }
}

// ---------------- LOGIN ----------------
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _signUp = false, _loading = false, _hide = true;
  String? _error;

  Future<void> _submit() async {
    final e = _email.text.trim();
    final p = _pass.text;
    if (!e.contains('@') || p.length < 6) {
      setState(() => _error = 'Sahi email aur kam se kam 6 akshar ka password daalo.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final err = await Auth.submit(e, p, signUp: _signUp);
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const ChatPage()));
    } else {
      setState(() {
        _loading = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const SimuneLogo(size: 96, spin: true),
                const SizedBox(height: 16),
                const Text('Simune',
                    style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(_signUp ? 'Naya account banao' : 'Wapas aaye? Login karo',
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 28),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.mail_outline),
                      border: OutlineInputBorder()),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _pass,
                  obscureText: _hide,
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_hide ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5))
                        : Text(_signUp ? 'Sign up' : 'Login',
                            style: const TextStyle(fontSize: 16)),
                  ),
                ),
                TextButton(
                  onPressed: _loading
                      ? null
                      : () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                  child: Text(_signUp
                      ? 'Pehle se account hai? Login'
                      : 'Naye ho? Account banao'),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- CHAT ----------------
class Msg {
  final String role, text, question;
  Msg(this.role, this.text, {this.question = ''});
}

String clean(String s) =>
    s.replaceAll('**', '').replaceAll(r'$$', '').replaceAll(RegExp(r'^#{1,6} ', multiLine: true), '');

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Msg> _msgs = [];
  bool _loading = false;

  static const _hello = 'Namaste! Main Simune hoon. Koi bhi sawal poochho 👋';

  @override
  void initState() {
    super.initState();
    _msgs.add(Msg('model', _hello));
  }

  void _toLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _loading) return;
    final hist = _msgs
        .where((m) => m.text != _hello)
        .map((m) => {'role': m.role, 'text': m.text})
        .toList();
    setState(() {
      _msgs.add(Msg('user', text));
      _loading = true;
      _ctrl.clear();
    });
    _scrollDown();
    try {
      final t = await Auth.token();
      if (t == null) {
        _toLogin();
        return;
      }
      // Free server soya ho to pehli baar 30-60 second lag sakte hain
      final r = await http
          .post(Uri.parse('$kBaseUrl/chat'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
              body: jsonEncode({'message': text, 'history': hist}))
          .timeout(const Duration(seconds: 90));
      if (r.statusCode == 401) {
        await Auth.logout();
        _toLogin();
        return;
      }
      final data = jsonDecode(utf8.decode(r.bodyBytes));
      final reply = (data is Map ? data['reply'] : null) ?? 'Kuch gadbad hui, phir try karo.';
      setState(() => _msgs.add(Msg('model', reply.toString(), question: text)));
    } catch (_) {
      setState(() => _msgs.add(Msg('model', 'Internet ya server problem. Thodi der baad phir try karo.')));
    }
    if (!mounted) return;
    setState(() => _loading = false);
    _scrollDown();
  }

  void _scrollDown() async {
    await Future.delayed(const Duration(milliseconds: 150));
    if (_scroll.hasClients) {
      _scroll.animateTo(_scroll.position.maxScrollExtent + 400,
          duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  Future<void> _report(Msg m) async {
    try {
      final t = await Auth.token();
      if (t != null) {
        await http.post(Uri.parse('$kBaseUrl/report'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $t'},
            body: jsonEncode({'message': m.question, 'reply': m.text}));
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Report ho gaya. Shukriya!')));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          SimuneLogo(size: 30),
          SizedBox(width: 10),
          Text('Simune', style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Nayi chat',
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () => setState(() {
              _msgs
                ..clear()
                ..add(Msg('model', _hello));
            }),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'logout') {
                await Auth.logout();
                _toLogin();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(Auth.email ?? '')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.all(12),
            itemCount: _msgs.length + (_loading ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _msgs.length) {
                return Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                        color: const Color(0xFF1C1C24), borderRadius: BorderRadius.circular(16)),
                    child: const TypingDots(),
                  ),
                );
              }
              final m = _msgs[i];
              final me = m.role == 'user';
              return Align(
                alignment: me ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: w * 0.85),
                  decoration: BoxDecoration(
                    color: me ? const Color(0xFF3730A3) : const Color(0xFF1C1C24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    SelectableText(clean(m.text), style: const TextStyle(fontSize: 15.5, height: 1.4)),
                    if (!me && m.question.isNotEmpty)
                      InkWell(
                        onTap: () => _report(m),
                        child: const Padding(
                          padding: EdgeInsets.only(top: 8),
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
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  decoration: InputDecoration(
                    hintText: 'Apna sawal likho...',
                    filled: true,
                    fillColor: const Color(0xFF1C1C24),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(26), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(onPressed: _send, icon: const Icon(Icons.arrow_upward)),
            ]),
          ),
        ),
      ]),
    );
  }
}
