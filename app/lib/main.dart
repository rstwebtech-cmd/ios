import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:url_launcher/url_launcher.dart';

const base = String.fromEnvironment('API', defaultValue: 'http://10.0.2.2:8080');
const photo = '$base/static/janhavi.png';
const logo = '$base/static/logo.png';
String token = '';
// Google sign-in on iPhone needs extra Apple/Google setup, so it is hidden on iOS unless built with --dart-define=IOS_GOOGLE=true
final bool showGoogle = defaultTargetPlatform != TargetPlatform.iOS || const bool.fromEnvironment('IOS_GOOGLE');
Future buy(BuildContext c, String id, [String coupon = '']) async {
  final r = await api('POST', '/api/pay/order', {'itemId': id, 'coupon': coupon});
  if (r['url'] == null) return snack(c, r['error'] ?? 'Payment error');
  await launchUrl(Uri.parse(r['url']), mode: LaunchMode.externalApplication);
}
Map me = {};
Future api(String m, String p, [Map? b]) async {
  final root = base.replaceAll(RegExp(r'/+$'), '').replaceAll(RegExp(r'/api$'), '');
  try {
    final h = {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};
    final u = Uri.parse(root + p);
    final f = m == 'GET' ? http.get(u, headers: h) : http.post(u, headers: h, body: jsonEncode(b ?? {}));
    final r = await f.timeout(const Duration(seconds: 70));
    try {
      return jsonDecode(r.body);
    } catch (_) {
      final t = r.body.length > 80 ? r.body.substring(0, 80) : r.body;
      return {'error': 'Server sent an invalid response (code ${r.statusCode}): $t | URL: $root'};
    }
  } catch (e) {
    final t = e.toString();
    return {'error': 'Could not connect: ${t.length > 90 ? t.substring(0, 90) : t} | URL: $root'};
  }
}

void main() => runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorSchemeSeed: const Color(0xFF6D28D9), scaffoldBackgroundColor: const Color(0xFFF5F3FF), useMaterial3: true),
    home: const Login()));

void go(BuildContext c, Widget w) => Navigator.push(c, PageRouteBuilder(transitionDuration: const Duration(milliseconds: 350), pageBuilder: (_, __, ___) => w, transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: SlideTransition(position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(CurvedAnimation(parent: a, curve: Curves.easeOut)), child: child))));
void snack(BuildContext c, String s) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(s)));

class Login extends StatefulWidget { const Login({super.key}); @override State<Login> createState() => _L(); }
class _L extends State<Login> {
  final nm = TextEditingController(), ph = TextEditingController(), em = TextEditingController(), pw = TextEditingController(), rf = TextEditingController();
  bool reg = false, busy = false;
  void done(r) {
    setState(() => busy = false);
    if (r['token'] == null) return snack(context, r['error'] ?? 'Failed');
    token = r['token']; me = r['user'];
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Home()));
  }
  Widget f(TextEditingController c, String l, {bool pass = false, TextInputType? t}) => TextField(controller: c, obscureText: pass, keyboardType: t, decoration: InputDecoration(labelText: l));
  @override Widget build(BuildContext c) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF2E1065), Color(0xFF7C3AED)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          child: Center(child: SingleChildScrollView(child: Card(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)), margin: const EdgeInsets.all(24), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            CircleAvatar(radius: 46, backgroundColor: const Color(0xFFEDE9FE), backgroundImage: const NetworkImage(photo), onBackgroundImageError: (_, __) {}), const SizedBox(height: 8),
            const Text('Janhavi Panwar', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const Text('Wonder Girl of India'), const SizedBox(height: 12),
            if (reg) f(nm, 'Full name'),
            f(em, 'Email', t: TextInputType.emailAddress),
            if (reg) f(ph, 'Mobile number', t: TextInputType.phone),
            f(pw, 'Password (6+ characters)', pass: true), if (reg) f(rf, 'Referral code (optional)'), const SizedBox(height: 12),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: busy ? null : () async {
              setState(() => busy = true);
              done(reg ? await api('POST', '/api/auth/register', {'name': nm.text, 'email': em.text, 'phone': ph.text, 'password': pw.text, 'ref': rf.text}) : await api('POST', '/api/auth/login', {'email': em.text, 'password': pw.text}));
            }, child: Text(busy ? 'Please wait...' : reg ? 'Create Account' : 'Login'))),
            TextButton(onPressed: () => setState(() => reg = !reg), child: Text(reg ? 'Already have an account? Login' : 'Create a new account')),
            if (showGoogle) OutlinedButton.icon(icon: const Icon(Icons.g_mobiledata, size: 30), label: const Text('Continue with Google'), onPressed: () async {
              try {
                final a = await (await GoogleSignIn(scopes: ['email']).signIn())?.authentication;
                if (a?.idToken != null) done(await api('POST', '/api/auth/google', {'idToken': a!.idToken}));
              } catch (e) {
                snack(context, 'Google sign-in failed. Please use email and password.');
              }
            }),
          ]))))),
        ),
      );
}

class Home extends StatefulWidget { const Home({super.key}); @override State<Home> createState() => _H(); }
class _H extends State<Home> {
  int i = 0;
  @override Widget build(BuildContext c) {
    void jump(int v) => setState(() => i = v);
    final tabs = [HomeTab(jump), const Courses(), const QuizTab(), const CommunityTab(), Profile(jump)];
    return Scaffold(
      body: SafeArea(top: i != 0, child: AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: KeyedSubtree(key: ValueKey(i), child: tabs[i]))),
      bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: jump, destinations: const [
        NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.play_circle), label: 'Courses'),
        NavigationDestination(icon: Icon(Icons.emoji_events), label: 'Quiz'),
        NavigationDestination(icon: Icon(Icons.groups), label: 'Community'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
      ]));
  }
}
void page(BuildContext c, String t, Widget w) => go(c, Scaffold(appBar: AppBar(title: Text(t)), body: w));

class Pulse extends StatefulWidget { final Widget child; const Pulse(this.child, {super.key}); @override State<Pulse> createState() => _P(); }
class _P extends State<Pulse> with SingleTickerProviderStateMixin {
  late final a = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override void dispose() { a.dispose(); super.dispose(); }
  @override Widget build(BuildContext c) => ScaleTransition(scale: Tween(begin: 0.92, end: 1.08).animate(a), child: widget.child);
}
Widget cimg(Map k, double h) => ClipRRect(borderRadius: BorderRadius.circular(14), child: (k['Image'] ?? '').toString().isEmpty ? Container(height: h, width: double.infinity, color: const Color(0xFFDDD6FE), child: const Icon(Icons.menu_book, size: 36, color: Color(0xFF6D28D9))) : Image.network(k['Image'].toString().startsWith('http') ? k['Image'] : base + k['Image'], height: h, width: double.infinity, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(height: h, color: const Color(0xFFDDD6FE))));
Widget priceRow(num p, num mrp) => Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
      Text('₹$p', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(width: 8),
      Text('₹$mrp', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)), const SizedBox(width: 8),
      Pulse(Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
          child: Text('${((mrp - p) * 100 / mrp).round()}% OFF', style: const TextStyle(color: Colors.white, fontSize: 12)))),
    ]);

Widget courseCard(BuildContext c, Map k) => InkWell(onTap: () => go(c, CourseScreen(k)), child: Card(clipBehavior: Clip.antiAlias, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Stack(children: [cimg(k, 96), Positioned(top: 6, right: 6, child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(10)), child: Text(k['Category'], style: const TextStyle(color: Colors.white, fontSize: 11)))), const Positioned(bottom: 6, left: 6, child: CircleAvatar(radius: 14, backgroundColor: Colors.black54, child: Icon(Icons.play_arrow, color: Colors.white, size: 18)))]),
      Padding(padding: const EdgeInsets.all(8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k['Title'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        Row(children: [const Icon(Icons.access_time, size: 13), Text(' ${k['Duration']}', style: const TextStyle(fontSize: 12))]),
        priceRow(k['Price'], k['MRP']),
        SizedBox(width: double.infinity, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: _blue), onPressed: () => go(c, CourseScreen(k)), child: const Text('Enroll Now')))]))])));

class Courses extends StatefulWidget { final String q; const Courses({super.key, this.q = ''}); @override State<Courses> createState() => _Cs(); }
class _Cs extends State<Courses> {
  String cat = 'All';
  static const cats = ['All', 'English', 'Accent', 'Languages', 'Career'];
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/courses'), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final l = (s.data as List).where((x) => (cat == 'All' || x['Category'] == cat) && x['Title'].toString().toLowerCase().contains(widget.q.toLowerCase())).toList();
        return Column(children: [
          SizedBox(height: 56, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [for (final t in cats) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(t), selected: cat == t, onSelected: (_) => setState(() => cat = t)))])),
          Expanded(child: GridView.count(crossAxisCount: 2, childAspectRatio: .62, crossAxisSpacing: 10, mainAxisSpacing: 10, padding: const EdgeInsets.all(10), children: [for (var i = 0; i < l.length; i++) Fade(courseCard(c, l[i]), i: i)]))]);
      });
}

class CourseScreen extends StatefulWidget { final Map k; const CourseScreen(this.k, {super.key}); @override State<CourseScreen> createState() => _C(); }
class _C extends State<CourseScreen> {
  final rv = TextEditingController(), cp = TextEditingController();
  @override Widget build(BuildContext c) {
    final k = widget.k;
    return Scaffold(appBar: AppBar(title: Text(k['Title'])), body: ListView(padding: const EdgeInsets.all(16), children: [
      cimg(k, 190), const SizedBox(height: 10), Text('${k['Category']} · ${k['Duration']}'), priceRow(k['Price'], k['MRP']), const SizedBox(height: 12),
      TextField(controller: cp, decoration: const InputDecoration(labelText: 'Coupon code (if you have one)')), FilledButton(onPressed: () => buy(c, k['ID'], cp.text.trim()), child: Text('Buy Now ₹${k['Price']}')),
      OutlinedButton(onPressed: () => go(c, Quiz(k)), child: const Text('Take Final Quiz → Get Certificate')),
      const Divider(), const Text('Lessons', style: TextStyle(fontWeight: FontWeight.bold)),
      FutureBuilder(future: api('GET', '/api/course/${k['ID']}/lessons'), builder: (_, s) { final l = s.data is List ? s.data as List : []; if (l.isEmpty) return const Padding(padding: EdgeInsets.all(8), child: Text('Lessons will be added soon')); return Column(children: [for (final x in l) ListTile(leading: Icon((x['URL'] ?? '').toString().isEmpty ? Icons.lock : Icons.play_circle, color: _blue), title: Text(x['Title']), onTap: () { if ((x['URL'] ?? '').toString().isEmpty) { snack(c, 'Unlocks after you buy the course'); } else { launchUrl(Uri.parse(x['URL']), mode: LaunchMode.externalApplication); } })]); }),
      const Divider(), const Text('Reviews', style: TextStyle(fontWeight: FontWeight.bold)),
      FutureBuilder(future: api('GET', '/api/reviews'), builder: (_, s) => Column(children: [
        for (final r in (s.data as List? ?? [])) ListTile(title: Text(r['Name']), subtitle: Text(r['Text']), trailing: Text('⭐${r['Stars']}'))])),
      TextField(controller: rv, decoration: const InputDecoration(labelText: 'Write a review (shown after approval)')),
      TextButton(onPressed: () async { await api('POST', '/api/reviews', {'courseId': k['ID'], 'text': rv.text, 'stars': 5}); rv.clear(); snack(c, 'Thanks! Review pending approval'); }, child: const Text('Submit review')),
    ]));
  }
}

class Combos extends StatelessWidget {
  const Combos({super.key});
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/combos'), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        return ListView(children: [for (final b in s.data as List) Card(color: Colors.amber.shade50, margin: const EdgeInsets.all(12), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('🔥 SPECIAL COMBO OFFER'), Text(b['Title'], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), priceRow(b['Price'], b['MRP']),
          FilledButton(onPressed: () => buy(c, b['ID']), child: const Text('Get Offer'))])))]);
      });
}

class Community extends StatelessWidget {
  const Community({super.key});
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/groups'), builder: (_, s) => Scaffold(
        body: (s.data is List && (s.data as List).isEmpty) ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('You have not been added to any community group yet. Admin will add you after you buy a course.', textAlign: TextAlign.center))) : ListView(children: [for (final g in (s.data as List? ?? [])) ListTile(leading: const Icon(Icons.groups), title: Text(g['Name']), onTap: () => go(c, Chat(room: g['ID'], title: g['Name'])))])));
}

class Chat extends StatefulWidget { final String room, title; final String? first; const Chat({super.key, required this.room, required this.title, this.first}); @override State<Chat> createState() => _Ch(); }
class _Ch extends State<Chat> {
  final t = TextEditingController(); List m = []; Timer? tm;
  Future poll() async { final r = await api('GET', '/api/chat?room=${widget.room}&after=0'); if (mounted) setState(() => m = r); }
  @override void initState() { super.initState(); if (widget.first != null) { api('POST', '/api/chat', {'room': widget.room, 'text': widget.first}).then((_) => poll()); } else { poll(); } tm = Timer.periodic(const Duration(seconds: 3), (_) => poll()); }
  @override void dispose() { tm?.cancel(); super.dispose(); }
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: Text(widget.title)), body: Column(children: [
        Expanded(child: ListView(children: [for (final x in m) ListTile(dense: true, title: Text(x['Name'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(x['Text']))])),
        Row(children: [Expanded(child: Padding(padding: const EdgeInsets.all(8), child: TextField(controller: t))), IconButton(icon: const Icon(Icons.send), onPressed: () async { await api('POST', '/api/chat', {'room': widget.room, 'text': t.text}); t.clear(); poll(); })])]));
}

class Quiz extends StatefulWidget { final Map k; const Quiz(this.k, {super.key}); @override State<Quiz> createState() => _Q(); }
class _Q extends State<Quiz> {
  final sw = Stopwatch()..start();
  List qs = []; Map<int, int> a = {};
  @override void initState() { super.initState(); api('GET', '/api/quiz/${widget.k['ID']}').then((v) => setState(() => qs = v)); }
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Final Quiz')), body: ListView(padding: const EdgeInsets.all(12), children: [
        for (var i = 0; i < qs.length; i++) Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(padding: const EdgeInsets.all(12), child: Text('${i + 1}. ${qs[i]['Q']}', style: const TextStyle(fontWeight: FontWeight.bold))),
          for (var j = 0; j < qs[i]['Options'].length; j++) RadioListTile<int>(value: j, groupValue: a[i], title: Text(qs[i]['Options'][j]), onChanged: (v) => setState(() => a[i] = v!))])),
        FilledButton(onPressed: () async {
          final r = await api('POST', '/api/quiz/${widget.k['ID']}', {'answers': [for (var i = 0; i < qs.length; i++) a[i] ?? -1]});
          if (!mounted) return;
          Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => QuizResult(widget.k, qs, [for (var i = 0; i < qs.length; i++) a[i] ?? -1], r is Map ? r : {}, sw.elapsed.inSeconds)));
        }, child: const Text('Submit')),
      ]));
}

const _blue = Color(0xFF6D28D9);
const _dark = Color(0xFF2E1065);
const _gold = Color(0xFFFBBF24);

class HomeTab extends StatelessWidget {
  final void Function(int) jump;
  const HomeTab(this.jump, {super.key});
  Widget head(String t, [VoidCallback? f]) => Padding(padding: const EdgeInsets.fromLTRB(16, 18, 16, 8), child: Row(children: [Container(width: 4, height: 22, color: _blue), const SizedBox(width: 8), Expanded(child: Text(t, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold))), if (f != null) TextButton(onPressed: f, child: const Text('View All →'))]));
  Widget ico(IconData i, String t, Color col, VoidCallback f) => InkWell(onTap: f, child: Container(width: 76, margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(i, color: col, size: 28), const SizedBox(height: 4), Text(t, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)])));
  Widget qc(IconData i, String t, String s, Color col, VoidCallback f) => Expanded(child: InkWell(onTap: f, child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4), decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(16)), child: Column(children: [Icon(i, color: col), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), textAlign: TextAlign.center), Text(s, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)]))));
  @override Widget build(BuildContext c) => FutureBuilder(future: Future.wait([api('GET', '/api/me'), api('GET', '/api/courses'), api('GET', '/api/live'), api('GET', '/api/reviews')]), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data as List; final u = d[0]['user']; final courses = d[1] as List; final live = (d[2] as List? ?? []); final revs = (d[3] as List? ?? []);
        final nm = (u['Name'] ?? '').toString().isEmpty ? 'Student' : u['Name'];
        return ListView(padding: EdgeInsets.zero, children: [
          Container(height: 270, decoration: const BoxDecoration(gradient: LinearGradient(colors: [_dark, Color(0xFF7C3AED)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.vertical(bottom: Radius.circular(28))), child: Stack(children: [
            Positioned(right: 0, bottom: 0, child: Image.network(photo, height: 240, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox())),
            SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(16, 8, 140, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Image.network(logo, height: 34, errorBuilder: (_, __, ___) => const Text('Janhavi Panwar', style: TextStyle(color: Colors.white, fontSize: 20))),
              const Spacer(),
              const Text('Dream Big...', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const Text('Learn Beyond Limits!', style: TextStyle(color: _gold, fontSize: 22, fontWeight: FontWeight.bold)),
              Text('Hello, $nm 👋 · v8', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 8),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black), onPressed: () => jump(1), child: const Text('Explore Courses →'))])))])),
          Padding(padding: const EdgeInsets.all(14), child: TextField(decoration: InputDecoration(hintText: 'Search courses, quizzes, or topics...', prefixIcon: const Icon(Icons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none)), onSubmitted: (v) => page(c, 'Search: $v', Courses(q: v)))),
          SingleChildScrollView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), child: Row(children: [
            ico(Icons.school, 'Courses', _blue, () => jump(1)), ico(Icons.star, 'Reviews', Colors.orange, () => page(c, 'Reviews', const ReviewsPage())),
            ico(Icons.chat, 'Live Chat', Colors.teal, () => go(c, const LiveChatHome())), ico(Icons.groups, 'Community', Colors.purple, () => jump(3)),
            ico(Icons.quiz, 'Quiz', Colors.indigo, () => jump(2)), ico(Icons.bar_chart, 'Level Check', Colors.green, () => go(c, Quiz({'ID': 'level', 'Title': 'Level Check'})))])),
          head('Featured Courses', () => jump(1)),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: .62, crossAxisSpacing: 10, mainAxisSpacing: 10, padding: const EdgeInsets.symmetric(horizontal: 12), children: [for (var i = 0; i < (courses.length < 4 ? courses.length : 4); i++) Fade(courseCard(c, courses[i]), i: i)]),
          Container(margin: const EdgeInsets.fromLTRB(14, 18, 14, 4), padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(22)), child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)), child: Text(live.isEmpty ? 'Coming Soon' : 'Live', style: const TextStyle(color: Colors.white, fontSize: 12))),
              Text(live.isEmpty ? 'Live Classes' : live[0]['Title'], style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              Text(live.isEmpty ? 'Will be scheduled soon' : live[0]['At'], style: const TextStyle(color: Colors.white70)), const SizedBox(height: 8),
              FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _blue), onPressed: () => live.isEmpty ? page(c, 'Live Classes', const LiveTab()) : launchUrl(Uri.parse(live[0]['Link']), mode: LaunchMode.externalApplication), child: const Text('Join Live →'))])),
            const Icon(Icons.podcasts, color: _gold, size: 60)])),
          Padding(padding: const EdgeInsets.fromLTRB(10, 12, 10, 0), child: Row(children: [
            qc(Icons.local_offer, 'Combo Offers', 'Save more', Colors.deepOrange, () => page(c, 'Combo Offers', const Combos())), qc(Icons.card_giftcard, 'Refer & Earn', '10% Commission', Colors.orange, () => go(c, const ReferPage())),
            qc(Icons.workspace_premium, 'Certificates', 'Get Certified', Colors.amber, () => jump(4)), qc(Icons.quiz, 'Take Quiz', 'Test Skills', Colors.indigo, () => jump(2))])),
          head('What Our Learners Say', () => page(c, 'Reviews', const ReviewsPage())),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [
            Expanded(flex: 2, child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)), child: revs.isEmpty ? const Text('Be the first to write a review! ⭐') : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('⭐' * (revs[0]['Stars'] as int)), Text('"${revs[0]['Text']}"', maxLines: 3, overflow: TextOverflow.ellipsis), Text('— ${revs[0]['Name']}', style: const TextStyle(fontSize: 12, color: Colors.grey))]))),
            const SizedBox(width: 10),
            Expanded(child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(16)), child: const Column(children: [Icon(Icons.groups, color: _blue), Text('2.27M+', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text('YouTube Family', style: TextStyle(fontSize: 11), textAlign: TextAlign.center)])))])),
          const SizedBox(height: 24)]);
      });
}

class ReviewsPage extends StatefulWidget { const ReviewsPage({super.key}); @override State<ReviewsPage> createState() => _Rv(); }
class _Rv extends State<ReviewsPage> {
  final t = TextEditingController();
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/reviews'), builder: (_, s) => ListView(padding: const EdgeInsets.all(12), children: [
        TextField(controller: t, decoration: const InputDecoration(labelText: 'Write your review (shown after approval)')),
        TextButton(onPressed: () async { await api('POST', '/api/reviews', {'text': t.text, 'stars': 5}); t.clear(); snack(c, 'Thanks! Review pending approval'); }, child: const Text('Submit review')),
        for (final r in (s.data as List? ?? [])) Card(child: ListTile(title: Text(r['Name']), subtitle: Text(r['Text']), trailing: Text('⭐${r['Stars']}')))]));
}

class LiveTab extends StatelessWidget {
  const LiveTab({super.key});
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/live'), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final l = s.data as List;
        if (l.isEmpty) return const Center(child: Text('No live class scheduled'));
        return ListView(children: [for (final x in l) Card(margin: const EdgeInsets.all(10), child: ListTile(leading: const Icon(Icons.videocam, color: _blue), title: Text(x['Title']), subtitle: Text(x['At']), trailing: FilledButton(onPressed: () => launchUrl(Uri.parse(x['Link']), mode: LaunchMode.externalApplication), child: const Text('Join Now'))))]);
      });
}

class Fade extends StatelessWidget {
  final Widget child; final int i;
  const Fade(this.child, {super.key, this.i = 0});
  @override Widget build(BuildContext c) => TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: 1), duration: Duration(milliseconds: 350 + i * 90), curve: Curves.easeOut, builder: (_, v, ch) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, 24 * (1 - v)), child: ch)), child: child);
}

class CommunityTab extends StatefulWidget { const CommunityTab({super.key}); @override State<CommunityTab> createState() => _CT(); }
class _CT extends State<CommunityTab> {
  bool feed = true;
  @override Widget build(BuildContext c) => Column(children: [
        Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(18, 18, 18, 14), decoration: const BoxDecoration(gradient: LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))), child: const Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Join Our', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text('Community', style: TextStyle(color: _gold, fontSize: 28, fontWeight: FontWeight.bold)), Text('Learn Together, Grow Together!', style: TextStyle(color: Colors.white70))])),
          Icon(Icons.groups, color: Colors.white, size: 64)])),
        Padding(padding: const EdgeInsets.all(10), child: Row(children: [for (final t in ['Feed', 'My Groups']) Expanded(child: Padding(padding: const EdgeInsets.all(3), child: ChoiceChip(label: SizedBox(width: double.infinity, child: Text(t, textAlign: TextAlign.center)), selected: (t == 'Feed') == feed, onSelected: (_) => setState(() => feed = t == 'Feed'))))])),
        Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: feed ? const FeedView(key: ValueKey(1)) : const Community(key: ValueKey(2))))]);
}

class FeedView extends StatefulWidget { const FeedView({super.key}); @override State<FeedView> createState() => _FV(); }
class _FV extends State<FeedView> {
  final t = TextEditingController(); String kind = 'all'; late Future f = api('GET', '/api/posts');
  void reload() => setState(() => f = api('GET', '/api/posts'));
  @override Widget build(BuildContext c) => Column(children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Row(children: [Expanded(child: TextField(controller: t, decoration: InputDecoration(hintText: 'Share your thoughts...', filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none)))), const SizedBox(width: 6), FilledButton(onPressed: () async { if (t.text.trim().isEmpty) return; await api('POST', '/api/posts', {'text': t.text, 'kind': t.text.trim().endsWith('?') ? 'question' : 'post'}); t.clear(); reload(); }, child: const Text('Post'))])),
        SizedBox(height: 50, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.all(8), children: [for (final k in ['all', 'mine', 'question', 'announcement']) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text({'all': 'All Posts', 'mine': 'My Posts', 'question': 'Questions', 'announcement': 'Announcements'}[k]!), selected: kind == k, onSelected: (_) => setState(() => kind = k)))])),
        Expanded(child: FutureBuilder(future: f, builder: (_, s) {
          if (!s.hasData) return const Center(child: CircularProgressIndicator());
          final l = (s.data is List ? s.data as List : []).where((p) => kind == 'all' || (kind == 'mine' ? p['Mine'] == true : p['Kind'] == kind)).toList();
          if (l.isEmpty) return const Center(child: Text('No posts yet. Be the first to post!'));
          return ListView(children: [for (var i = 0; i < l.length; i++) Fade(i: i, Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [CircleAvatar(backgroundColor: const Color(0xFFEDE9FE), child: Text(l[i]['Name'].toString().isEmpty ? '?' : l[i]['Name'][0])), const SizedBox(width: 8), Text(l[i]['Name'], style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 6), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1), decoration: BoxDecoration(color: l[i]['Role'] == 'Admin' ? Colors.red : _blue, borderRadius: BorderRadius.circular(10)), child: Text(l[i]['Role'], style: const TextStyle(color: Colors.white, fontSize: 11)))]),
            const SizedBox(height: 8), Text(l[i]['Text']),
            Row(children: [TextButton.icon(onPressed: () async { await api('POST', '/api/posts/${l[i]['ID']}/like'); reload(); }, icon: Icon(l[i]['Liked'] == true ? Icons.thumb_up : Icons.thumb_up_outlined, size: 18), label: Text('${l[i]['Likes']}')), if (l[i]['Kind'] != 'post') Text(l[i]['Kind'] == 'question' ? '❓ Question' : '📢 Announcement', style: const TextStyle(fontSize: 12))])]))))]);
        }))]);
}

class QuizTab extends StatefulWidget { const QuizTab({super.key}); @override State<QuizTab> createState() => _QT(); }
class _QT extends State<QuizTab> {
  bool hist = false;
  @override Widget build(BuildContext c) => FutureBuilder(future: Future.wait([api('GET', '/api/quizzes'), api('GET', '/api/attempts'), api('GET', '/api/me')]), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data as List; final qz = d[0] is List ? d[0] as List : []; final at = d[1] is List ? d[1] as List : []; final m2 = d[2] is Map ? d[2] as Map : {};
        Widget st(IconData i, num v, String t, String suf) => Expanded(child: Column(children: [Icon(i, color: _blue), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: v.toDouble()), duration: const Duration(milliseconds: 900), builder: (_, x, __) => Text('${x.round()}$suf', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))), Text(t, style: const TextStyle(fontSize: 11))]));
        return ListView(padding: EdgeInsets.zero, children: [
          Container(padding: const EdgeInsets.all(20), decoration: const BoxDecoration(gradient: LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(26))), child: const Row(children: [Expanded(child: Text('Test Your Knowledge\n& Track Your Progress', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold))), Icon(Icons.emoji_events, color: _gold, size: 70)])),
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [st(Icons.quiz, at.length, 'Attempts', ''), st(Icons.star, (m2['avgScore'] ?? 0) as num, 'Avg Score', '%'), st(Icons.workspace_premium, (m2['certs'] as List? ?? []).length, 'Certificates', '')])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Row(children: [Expanded(child: ChoiceChip(label: const SizedBox(width: double.infinity, child: Text('Available Quizzes', textAlign: TextAlign.center)), selected: !hist, onSelected: (_) => setState(() => hist = false))), const SizedBox(width: 8), Expanded(child: ChoiceChip(label: const SizedBox(width: double.infinity, child: Text('My History', textAlign: TextAlign.center)), selected: hist, onSelected: (_) => setState(() => hist = true)))])),
          if (!hist) ...[
            Fade(Card(color: Colors.green.shade50, margin: const EdgeInsets.fromLTRB(14, 10, 14, 4), child: ListTile(leading: const Icon(Icons.bar_chart, color: Colors.green, size: 34), title: const Text('Level Check (A1 → C1)', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('Find out your English level'), trailing: FilledButton(onPressed: () => go(c, Quiz({'ID': 'level', 'Title': 'Level Check'})), child: const Text('Start →'))))),
            for (var i = 0; i < qz.length; i++) Fade(i: i + 1, Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: ListTile(leading: const Icon(Icons.assignment, color: _blue, size: 34), title: Text(qz[i]['Title'], style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${qz[i]['Questions']} Questions'), trailing: FilledButton(onPressed: () => go(c, Quiz({'ID': qz[i]['ID'], 'Title': qz[i]['Title']})), child: const Text('Start →')))))
          ] else ...[
            if (at.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('You have not attempted any quiz yet'))),
            for (var i = 0; i < at.length; i++) Fade(i: i, Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), child: ListTile(leading: const Icon(Icons.history, color: _blue), title: Text(at[i]['Title']), subtitle: Text(DateTime.fromMillisecondsSinceEpoch((at[i]['At'] as int) * 1000).toString().substring(0, 16)), trailing: Text('${at[i]['Score']}/${at[i]['Total']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))))
          ],
          const SizedBox(height: 20)]);
      });
}

class QuizResult extends StatelessWidget {
  final Map k; final List qs; final List ans; final Map r; final int secs;
  const QuizResult(this.k, this.qs, this.ans, this.r, this.secs, {super.key});
  @override Widget build(BuildContext c) {
    if (r['score'] == null) return Scaffold(appBar: AppBar(), body: Center(child: Text('${r['error'] ?? 'Something went wrong'}')));
    final total = r['total'] as int, sc = r['score'] as int; final pct = total == 0 ? 0.0 : sc / total; final lvl = r['level'];
    final key = (r['answers'] as List? ?? []);
    return Scaffold(appBar: AppBar(title: const Text('Quiz Result')), body: ListView(padding: const EdgeInsets.all(16), children: [
      const Icon(Icons.emoji_events, color: _gold, size: 90),
      Center(child: Text(lvl != null ? 'Your Level: $lvl 🎯' : pct >= .6 ? 'Great Attempt! 🎉' : 'Keep Practicing 💪', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _dark))),
      Center(child: Text('You scored $sc out of $total', style: const TextStyle(color: Colors.red, fontSize: 16))), const SizedBox(height: 16),
      Row(children: [
        SizedBox(width: 130, height: 130, child: TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: pct), duration: const Duration(milliseconds: 1200), curve: Curves.easeOut, builder: (_, v, __) => Stack(alignment: Alignment.center, children: [SizedBox(width: 130, height: 130, child: CircularProgressIndicator(value: v, strokeWidth: 12, color: Colors.green, backgroundColor: Colors.grey.shade300)), Text('${(v * 100).round()}%', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold))]))),
        const SizedBox(width: 20),
        Expanded(child: Column(children: [ListTile(dense: true, leading: const Icon(Icons.check_circle, color: Colors.green), title: const Text('Correct'), trailing: Text('$sc')), ListTile(dense: true, leading: const Icon(Icons.cancel, color: Colors.red), title: const Text('Wrong'), trailing: Text('${total - sc}')), ListTile(dense: true, leading: const Icon(Icons.timer, color: _blue), title: const Text('Time'), trailing: Text('${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}'))]))]),
      const SizedBox(height: 12),
      FilledButton(onPressed: () => page(c, 'Answer Sheet', ListView(children: [for (var i = 0; i < qs.length && i < key.length; i++) Card(margin: const EdgeInsets.all(8), child: ListTile(isThreeLine: true, title: Text('${i + 1}. ${qs[i]['Q']}'), subtitle: Text('Your answer: ${ans[i] >= 0 ? qs[i]['Options'][ans[i]] : '-'}\nCorrect answer: ${qs[i]['Options'][key[i]]}', style: TextStyle(color: ans[i] == key[i] ? Colors.green : Colors.red))))])), child: const Text('View Answer Sheet')),
      OutlinedButton(onPressed: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => Quiz(k))), child: const Text('Try Again')),
      if (r['certificate'] != null) FilledButton(style: FilledButton.styleFrom(backgroundColor: _gold, foregroundColor: Colors.black), onPressed: () => launchUrl(Uri.parse('$base/certificate/${r['certificate']}'), mode: LaunchMode.externalApplication), child: const Text('🏆 Download Certificate')),
      Container(margin: const EdgeInsets.only(top: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(16)), child: Row(children: [const Icon(Icons.emoji_events, color: _gold, size: 40), const SizedBox(width: 10), const Expanded(child: Text('Your Rank on Leaderboard')), Text('#${r['rank']}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), Text(' / ${r['players']}')]))]));
  }
}

class LiveChatHome extends StatelessWidget {
  const LiveChatHome({super.key});
  @override Widget build(BuildContext c) {
    final room = 'support-${me['ID']}';
    Widget top(IconData i, Color col, String t, String s, String b, VoidCallback f) => Expanded(child: Container(margin: const EdgeInsets.all(6), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: col.withOpacity(.12), borderRadius: BorderRadius.circular(18)), child: Column(children: [Icon(i, color: col, size: 54), Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), Text(s, style: const TextStyle(fontSize: 12), textAlign: TextAlign.center), const SizedBox(height: 8), FilledButton(style: FilledButton.styleFrom(backgroundColor: col), onPressed: f, child: Text(b))])));
    return Scaffold(appBar: AppBar(title: const Text('Live Chat')), body: ListView(children: [
      Fade(Row(children: [top(Icons.chat_bubble, _blue, 'Chat on App', 'Ask your query inside the app', 'Start Chat →', () => go(c, Chat(room: room, title: 'Live Support'))), top(Icons.phone_in_talk, Colors.green, 'Chat on WhatsApp', 'Talk directly on WhatsApp', 'Chat Now →', () async { final cfg = await api('GET', '/api/config'); final n = (cfg['whatsapp'] ?? '').toString(); if (n.isEmpty) { if (c.mounted) snack(c, 'WhatsApp number is not set yet'); } else { launchUrl(Uri.parse('https://wa.me/$n'), mode: LaunchMode.externalApplication); } })])),
      const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 4), child: Text('Quick Help Topics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17))),
      for (var i = 0; i < 5; i++) Fade(i: i, Card(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 3), child: ListTile(leading: Icon([Icons.how_to_reg, Icons.payment, Icons.quiz, Icons.card_giftcard, Icons.help][i], color: _blue), title: Text(['Course Enrollment', 'Payment Issues', 'Quiz Related Queries', 'Referral & Commission', 'Other Help'][i]), trailing: const Icon(Icons.chevron_right), onTap: () => go(c, Chat(room: room, title: 'Live Support', first: ['I want to ask about course enrollment', 'I have a problem with my payment', 'I have a question about the quiz', 'How do I get referral commission?', 'I want to talk to the team'][i]))))),
      Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(20)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('We are here to help!', style: TextStyle(color: _gold, fontSize: 20, fontWeight: FontWeight.bold)), Text('Have a question? Just start a chat.', style: TextStyle(color: Colors.white70))])), Image.network(photo, height: 90, errorBuilder: (_, __, ___) => const SizedBox())]))]));
  }
}

class ReferPage extends StatelessWidget {
  const ReferPage({super.key});
  @override Widget build(BuildContext c) => Scaffold(appBar: AppBar(title: const Text('Refer & Earn')), body: FutureBuilder(future: api('GET', '/api/me'), builder: (_, s) {
        if (!s.hasData || s.data is! Map || (s.data as Map)['user'] == null) return const Center(child: CircularProgressIndicator());
        final d = s.data as Map; final u = d['user']; final code = '${u['Roll']}'; final earned = (u['Earned'] ?? 0) as int, paid = (u['Paid'] ?? 0) as int;
        Widget st(IconData i, num v, String t, {bool rs = false}) => Expanded(child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(i, color: _blue), TweenAnimationBuilder<double>(tween: Tween(begin: 0, end: v.toDouble()), duration: const Duration(milliseconds: 900), builder: (_, x, __) => Text('${rs ? '₹' : ''}${x.round()}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold))), Text(t, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)])));
        return ListView(children: [
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(22)), child: Row(children: [const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Refer & Earn', style: TextStyle(color: _gold, fontSize: 30, fontWeight: FontWeight.bold)), Text('Refer courses to your friends and earn 10% commission!', style: TextStyle(color: Colors.white))])), Pulse(Container(padding: const EdgeInsets.all(14), decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle), child: const Text('10%', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))))])),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Your Referral Code', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.only(left: 16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Row(children: [Expanded(child: Text(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 2))), FilledButton(onPressed: () { Clipboard.setData(ClipboardData(text: code)); snack(c, 'Code copied'); }, child: const Text('Copy'))])),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: FilledButton.icon(icon: const Icon(Icons.share), label: const Text('Share on WhatsApp'), onPressed: () => launchUrl(Uri.parse('https://wa.me/?text=${Uri.encodeComponent('Join Janhavi Panwar courses! Enter my referral code during registration: $code')}'), mode: LaunchMode.externalApplication))),
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('Your Referral Stats', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [st(Icons.people, (d['refCount'] ?? 0) as num, 'Total Referrals'), st(Icons.shopping_cart, (d['refSales'] ?? 0) as num, 'Successful Sales'), st(Icons.schedule, earned - paid, 'Pending', rs: true), st(Icons.emoji_events, earned, 'Total Earnings', rs: true)])),
          const Padding(padding: EdgeInsets.fromLTRB(16, 16, 16, 4), child: Text('How It Works', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
          Padding(padding: const EdgeInsets.all(10), child: Row(children: [for (final t in [[Icons.link, 'Share Your Code'], [Icons.shopping_cart, 'Friend Buys a Course'], [Icons.card_giftcard, 'Earn 10% Commission']]) Expanded(child: Container(margin: const EdgeInsets.all(4), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Column(children: [Icon(t[0] as IconData, color: _blue), Text(t[1] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11))])))]))]);
      }));
}

class Profile extends StatelessWidget {
  final void Function(int) jump;
  const Profile(this.jump, {super.key});
  @override Widget build(BuildContext c) => FutureBuilder(future: api('GET', '/api/me'), builder: (_, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final d = s.data as Map; final u = d['user']; final certs = (d['certs'] as List? ?? []);
        final nm = (u['Name'] ?? '').toString(); final ini = nm.isEmpty ? 'S' : nm[0].toUpperCase();
        final enr = ((u['Courses'] as List? ?? [])).toSet().length;
        final pts = enr * 100 + certs.length * 500; final lvl = 1 + pts ~/ 500; final pct = (pts % 500) / 500;
        final lname = lvl < 3 ? 'Beginner' : lvl < 5 ? 'Intermediate' : 'Advanced Learner';
        Widget stat(IconData i, String v, String t) => Expanded(child: Column(children: [Icon(i, color: _blue), Text(v, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text(t, style: const TextStyle(fontSize: 11), textAlign: TextAlign.center)]));
        Widget item(IconData i, String t, String sub, VoidCallback f, [Color? col]) => Container(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFDDD6FE))), child: ListTile(leading: Icon(i, color: col ?? _blue, size: 30), title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(sub), trailing: Icon(Icons.chevron_right, color: col ?? _blue), onTap: f));
        Widget badge(IconData i, String t, bool on) => Expanded(child: Container(margin: const EdgeInsets.all(3), padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Column(children: [Icon(i, size: 30, color: on ? _gold : Colors.grey.shade400), Text(t, style: const TextStyle(fontSize: 10), textAlign: TextAlign.center)])));
        return ListView(padding: EdgeInsets.zero, children: [
          Container(padding: const EdgeInsets.fromLTRB(16, 40, 16, 40), decoration: const BoxDecoration(gradient: LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.vertical(bottom: Radius.circular(32))), child: Row(children: [
            CircleAvatar(radius: 46, backgroundColor: _gold, child: CircleAvatar(radius: 42, backgroundColor: Colors.white, child: Text(ini, style: const TextStyle(fontSize: 36, color: _blue)))), const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nm.isEmpty ? 'Student' : nm, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('${u['Email'] ?? ''}${u['Phone'] ?? ''}', style: const TextStyle(color: Colors.white70)), const SizedBox(height: 6),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _blue, borderRadius: BorderRadius.circular(20), border: Border.all(color: _gold)), child: Text(enr > 0 ? '💎 Premium Member' : 'Free Member', style: const TextStyle(color: Colors.white, fontSize: 12)))]))])),
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)), child: Row(children: [stat(Icons.play_circle, '$enr', 'Courses Enrolled'), stat(Icons.military_tech, '$lvl', 'Level'), stat(Icons.star, '$pts', 'Points'), stat(Icons.workspace_premium, '${certs.length}', 'Certificates')])),
          Container(margin: const EdgeInsets.symmetric(horizontal: 14), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: const LinearGradient(colors: [_dark, Color(0xFF7C3AED)]), borderRadius: BorderRadius.circular(20)), child: Row(children: [
            SizedBox(width: 90, height: 90, child: Stack(alignment: Alignment.center, children: [SizedBox(width: 90, height: 90, child: CircularProgressIndicator(value: pct == 0 ? 0.02 : pct, strokeWidth: 9, color: _gold, backgroundColor: Colors.white24)), Text('${(pct * 100).round()}%', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))])), const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Your Learning Progress', style: TextStyle(color: Colors.white70, fontSize: 12)), Text('👑 Level $lvl', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), Text(lname, style: const TextStyle(color: Colors.white70)), const SizedBox(height: 6), LinearProgressIndicator(value: pct, color: _gold, backgroundColor: Colors.white24), const SizedBox(height: 4), Text('⭐ $pts Points', style: const TextStyle(color: Colors.white))])),
            const Icon(Icons.emoji_events, color: _gold, size: 54)])),
          const SizedBox(height: 10),
          item(Icons.play_circle, 'My Courses', 'Continue your learning journey', () => jump(1)),
          item(Icons.quiz, 'My Quizzes', 'Check your quiz performance', () => jump(2)),
          item(Icons.workspace_premium, 'My Certificates', 'Download your certificates', () => page(c, 'My Certificates', ListView(children: [for (final x in certs) ListTile(leading: const Icon(Icons.workspace_premium, color: _gold), title: Text(x['CourseTitle']), subtitle: Text(x['Date']), onTap: () => launchUrl(Uri.parse('$base/certificate/${x['ID']}'), mode: LaunchMode.externalApplication))]))),
          item(Icons.star, 'My Reviews', 'Share your feedback', () => page(c, 'Reviews', const ReviewsPage())),
          item(Icons.groups, 'My Community', 'Connect with learners', () => jump(3)),
          item(Icons.chat, 'Live Chat', 'Chat with our support team', () => go(c, const LiveChatHome())),
          InkWell(onTap: () => go(c, const ReferPage()), child: Container(margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: const Color(0xFFFEF3C7), borderRadius: BorderRadius.circular(14)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('🎁 Refer & Earn 10%', style: TextStyle(fontWeight: FontWeight.bold)), Text('Your code: ${u['Roll']}  (tap to copy)'), Text('Earned: ₹${u['Earned'] ?? 0}  |  Paid: ₹${u['Paid'] ?? 0}')]))),
          item(Icons.logout, 'Logout', 'Sign out from your account', () { token = ''; Navigator.pushAndRemoveUntil(c, MaterialPageRoute(builder: (_) => const Login()), (_) => false); }, Colors.red),
          Container(margin: const EdgeInsets.all(14), padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(18)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('⭐ Your Achievements', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 8),
            Row(children: [badge(Icons.school, 'First Course', enr >= 1), badge(Icons.verified, 'Quiz Master', certs.isNotEmpty), badge(Icons.emoji_events, 'Course Champion', certs.length >= 3), badge(Icons.military_tech, 'Level 3+', lvl >= 3)])]))]);
      });
}
