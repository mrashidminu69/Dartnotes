import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

const bg = Color(0xFF070B11), cd = Color(0xFF111923), gold = Color(0xFFE8B84A);
const em = Color(0xFF1FD18B), rd = Color(0xFFFF4D5E);
late SharedPreferences P;
Map<String, dynamic> DB = {'teams': [], 'matches': []};
void save() => P.setString('db2', jsonEncode(DB));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  P = await SharedPreferences.getInstance();
  final s = P.getString('db2');
  if (s != null) DB = jsonDecode(s);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'CricScorer',
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bg,
      colorScheme: const ColorScheme.dark(primary: em, secondary: gold, surface: cd),
      appBarTheme: const AppBarTheme(backgroundColor: bg, elevation: 0),
      navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cd, indicatorColor: em.withOpacity(.2)),
    ),
    home: const Shell(),
  ));
}

// ---------- helpers ----------
Map<String, dynamic> newInn(int bat) => {
      'bat': bat, 'runs': 0, 'wk': 0, 'legal': 0, 'ev': [], 'ov': [],
      'st': '', 'ns': '', 'bo': '', 'fh': false
    };
Map team(String n) {
  final l = DB['teams'] as List;
  for (final t in l) {
    if (t['name'] == n) return t;
  }
  final t = {'name': n, 'players': []};
  l.add(t);
  return t;
}

String ovs(int b) => '${b ~/ 6}.${b % 6}';
Color tc(String n) => HSLColor.fromAHSL(1, (n.hashCode % 360).toDouble(), .6, .45).toColor();
Future go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Widget glass(Widget child, {double pad = 16, Gradient? g, VoidCallback? onTap}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
                color: cd,
                gradient: g,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white10)),
            child: child)));

Widget logo(String n, [double s = 44]) => Container(
    width: s,
    height: s,
    alignment: Alignment.center,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [tc(n), tc(n).withOpacity(.5)])),
    child: Text(n.isEmpty ? '?' : n[0].toUpperCase(),
        style: TextStyle(fontSize: s * .45, fontWeight: FontWeight.w800)));

Future<String?> pick(BuildContext c, String t, List<String> o,
        {bool nw = true, bool dis = true}) =>
    showModalBottomSheet<String>(
        context: c,
        isScrollControlled: true,
        isDismissible: dis,
        enableDrag: dis,
        backgroundColor: cd,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (x) {
          final t0 = TextEditingController();
          return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(x).viewInsets.bottom),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(t,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                Flexible(
                    child: ListView(shrinkWrap: true, children: [
                  for (final s in o)
                    ListTile(leading: logo(s, 34), title: Text(s), onTap: () => Navigator.pop(x, s))
                ])),
                if (nw)
                  Padding(
                      padding: const EdgeInsets.all(14),
                      child: TextField(
                          controller: t0,
                          decoration: InputDecoration(
                              hintText: 'Naya naam likho',
                              filled: true,
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                              suffixIcon: IconButton(
                                  icon: const Icon(Icons.check_circle, color: em),
                                  onPressed: () {
                                    if (t0.text.trim().isNotEmpty) Navigator.pop(x, t0.text.trim());
                                  })))),
              ]));
        });

Future<int?> numPick(BuildContext c, String t, {int min = 0, int max = 6}) =>
    showModalBottomSheet<int>(
        context: c,
        backgroundColor: cd,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
        builder: (x) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (var k = min; k <= max; k++)
                  SizedBox(
                      width: 70,
                      height: 56,
                      child: FilledButton(
                          onPressed: () => Navigator.pop(x, k),
                          child: Text('$k', style: const TextStyle(fontSize: 20))))
              ])
            ])));

Future<Map<String, dynamic>?> wagon(BuildContext c) =>
    showModalBottomSheet<Map<String, dynamic>>(
        context: c,
        backgroundColor: cd,
        builder: (x) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('Shot kahan gaya? (field pe tap karo)',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              GestureDetector(
                  onTapDown: (d) {
                    final o = d.localPosition - const Offset(150, 150);
                    Navigator.pop(x, <String, dynamic>{'a': atan2(o.dy, o.dx), 'd': min(1.0, o.distance / 146)});
                  },
                  child: CustomPaint(size: const Size(300, 300), painter: Wag([]))),
              TextButton(onPressed: () => Navigator.pop(x), child: const Text('Skip'))
            ])));

// ---------- replay engine ----------
Map<String, dynamic> replay(List ev) {
  final bt = <String, Map<String, dynamic>>{}, bw = <String, Map<String, dynamic>>{};
  final hat = <String, int>{}, st = <String, int>{}, fow = <String>[];
  int tot = 0, wk = 0, ex = 0;
  Map<String, dynamic> B(String n) =>
      bt.putIfAbsent(n, () => {'r': 0, 'b': 0, 'f': 0, 's': 0, 'out': false, 'how': ''});
  Map<String, dynamic> W(String n) => bw.putIfAbsent(n, () => {'b': 0, 'r': 0, 'w': 0});
  for (final e in ev) {
    final x = e['x'] as String, br = e['br'] as int, xr = e['xr'] as int;
    final b = B(e['b']), w = W(e['w']);
    B(e['n']);
    tot += br + xr;
    ex += xr;
    if (x != 'wd') b['b']++;
    b['r'] += br;
    if (br == 4) b['f']++;
    if (br == 6) b['s']++;
    for (final m in [30, 50, 100]) {
      if (b['r'] >= m && b['m$m'] == null) b['m$m'] = b['b'];
    }
    w['r'] += br + ((x == 'wd' || x == 'nb') ? xr : 0);
    final lg = e['lg'] == 1;
    if (lg) w['b']++;
    bool cr = false;
    if (e['wk'] == true) {
      wk++;
      final o = B(e['out']);
      o['out'] = true;
      cr = e['how'] != 'Run out';
      o['how'] = cr ? '${e['how']} b ${e['w']}' : 'Run out';
      if (cr) w['w']++;
      fow.add('$tot-$wk ${e['out']}');
    }
    if (lg) {
      final n = cr ? (st[e['w']] ?? 0) + 1 : 0;
      st[e['w']] = n;
      if (n == 3) {
        hat[e['w']] = (hat[e['w']] ?? 0) + 1;
        st[e['w']] = 0;
      }
    }
  }
  return {'bt': bt, 'bw': bw, 'fow': fow, 'ex': ex, 'hat': hat};
}

List<int> worm(List ev) {
  int t = 0;
  final r = <int>[0];
  for (final e in ev) {
    t += (e['br'] as int) + (e['xr'] as int);
    if (e['lg'] == 1) r.add(t);
  }
  return r;
}

List<int> overRuns(List ev) {
  final r = <int>[];
  int l = 0;
  for (final e in ev) {
    final o = l ~/ 6;
    while (r.length <= o) {
      r.add(0);
    }
    r[o] += (e['br'] as int) + (e['xr'] as int);
    if (e['lg'] == 1) l++;
  }
  return r;
}

// ---------- painters ----------
class Wag extends CustomPainter {
  final List sh;
  Wag(this.sh);
  @override
  void paint(Canvas c, Size z) {
    final c0 = Offset(z.width / 2, z.height / 2), R = z.width / 2 - 4;
    c.drawCircle(
        c0,
        R,
        Paint()
          ..shader = const RadialGradient(colors: [Color(0xFF1B6B45), Color(0xFF0B3524)])
              .createShader(Rect.fromCircle(center: c0, radius: R)));
    c.drawCircle(c0, R * .55, Paint()..color = Colors.white24..style = PaintingStyle.stroke);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: c0, width: R * .09, height: R * .3), const Radius.circular(3)),
        Paint()..color = const Color(0xFFD9C79A));
    for (final s in sh) {
      final a = (s['a'] as num).toDouble(), d = (s['d'] as num).toDouble();
      final col = s['br'] == 6 ? gold : (s['br'] == 4 ? em : Colors.white70);
      c.drawLine(c0, c0 + Offset(cos(a), sin(a)) * R * d, Paint()..color = col..strokeWidth = 2.4);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class Worm extends CustomPainter {
  final List<List<int>> s;
  final int bl;
  Worm(this.s, this.bl);
  @override
  void paint(Canvas c, Size z) {
    int mx = 10;
    for (final l in s) {
      for (final v in l) {
        if (v > mx) mx = v;
      }
    }
    final g = Paint()..color = Colors.white12;
    for (var k = 0; k <= 4; k++) {
      c.drawLine(Offset(0, z.height * k / 4), Offset(z.width, z.height * k / 4), g);
    }
    final cols = [em, gold];
    for (var k = 0; k < s.length; k++) {
      final p = Path();
      for (var j = 0; j < s[k].length; j++) {
        final o = Offset(z.width * j / bl, z.height * (1 - s[k][j] / mx));
        if (j == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      c.drawPath(p, Paint()..color = cols[k]..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class Bars extends CustomPainter {
  final List<int> r;
  Bars(this.r);
  @override
  void paint(Canvas c, Size z) {
    int mx = 6;
    for (final v in r) {
      if (v > mx) mx = v;
    }
    final w = z.width / max(r.length, 1);
    for (var k = 0; k < r.length; k++) {
      final h = z.height * r[k] / mx;
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(k * w + 3, z.height - h, w - 6, h), const Radius.circular(5)),
          Paint()..color = r[k] >= 12 ? gold : em);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

// ---------- shell ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _Shell();
}

class _Shell extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(child: [const HomeTab(), const TeamsTab(), const StatsTab()][i]),
        bottomNavigationBar: NavigationBar(
            selectedIndex: i,
            onDestinationSelected: (v) => setState(() => i = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.sports_cricket), label: 'Matches'),
              NavigationDestination(icon: Icon(Icons.groups), label: 'Teams'),
              NavigationDestination(icon: Icon(Icons.insights), label: 'Stats'),
            ]),
      );
}

// ---------- home ----------
String scoreTxt(Map m) {
  final l = <String>[];
  for (var k = 0; k < (m['in'] as List).length; k++) {
    final n = m['in'][k];
    l.add('${m['t'][k]} ${n['runs']}/${n['wk']} (${ovs(n['legal'])})');
  }
  return l.join('\n');
}

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _Home();
}

class _Home extends State<HomeTab> {
  Widget mc(Map m) => glass(
      onTap: () async {
        await go(context, m['done'] == true ? ScoreView(m: m) : Scoring(s: m as Map<String, dynamic>));
        setState(() {});
      },
      Row(children: [
        logo(m['t'][0]),
        const SizedBox(width: 12),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${m['t'][0]} vs ${m['t'][1]}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(scoreTxt(m), style: const TextStyle(color: Colors.white60, fontSize: 13)),
          Text(m['done'] == true ? '🏆 ${m['res']}' : '● LIVE',
              style: TextStyle(color: m['done'] == true ? gold : rd, fontSize: 12, fontWeight: FontWeight.w700)),
        ])),
        const Icon(Icons.chevron_right)
      ]));

  @override
  Widget build(BuildContext c) {
    final ms = (DB['matches'] as List).reversed.toList();
    return ListView(padding: const EdgeInsets.all(18), children: [
      const Text('CRICSCORER',
          style: TextStyle(color: gold, letterSpacing: 5, fontSize: 12, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      const Text('Aaj ka match\nshuru karein 🏏',
          style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.15)),
      const SizedBox(height: 18),
      glass(
          onTap: () async {
            await go(c, const Setup());
            setState(() {});
          },
          pad: 22,
          g: const LinearGradient(colors: [Color(0xFF0F5A3E), Color(0xFF0A2A33)]),
          Row(children: const [
            Icon(Icons.add_circle, color: em, size: 34),
            SizedBox(width: 14),
            Expanded(
                child: Text('Naya Match',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
            Icon(Icons.arrow_forward_rounded)
          ])),
      if (ms.isEmpty)
        const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('Abhi koi match nahi. Pehla match shuru karo!', style: TextStyle(color: Colors.white54)))),
      for (final m in ms) mc(m),
    ]);
  }
}

// ---------- setup ----------
class Setup extends StatefulWidget {
  const Setup({super.key});
  @override
  State<Setup> createState() => _Setup();
}

class _Setup extends State<Setup> {
  final a = TextEditingController(), b = TextEditingController(), gr = TextEditingController();
  final ov = TextEditingController(text: '10'), mw = TextEditingController(text: '10');
  int first = 0;
  String fmt = 'Tape Ball';
  static const F = {'T20': 20, 'ODI': 50, 'Tape Ball': 10, 'Gully': 5, 'Hundred': 0, 'Custom': 0};

  Widget f(TextEditingController t, String l, {bool n = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
          controller: t,
          onChanged: (_) => setState(() {}),
          keyboardType: n ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
              labelText: l,
              filled: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))));

  void start() {
    final na = a.text.trim().isEmpty ? 'Team A' : a.text.trim();
    final nb = b.text.trim().isEmpty ? 'Team B' : b.text.trim();
    final t = first == 0 ? [na, nb] : [nb, na];
    final Map<String, dynamic> s = {
      'id': DateTime.now().millisecondsSinceEpoch,
      't': t,
      'fmt': fmt,
      'bl': fmt == 'Hundred' ? 100 : (int.tryParse(ov.text) ?? 10) * 6,
      'mw': int.tryParse(mw.text) ?? 10,
      'g': gr.text.trim(),
      'i': 0,
      'in': [newInn(0)],
      'brk': false,
      'res': '',
      'done': false,
      'sq': [List<String>.from(team(t[0])['players']), List<String>.from(team(t[1])['players'])]
    };
    (DB['matches'] as List).add(s);
    save();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => Scoring(s: s)));
  }

  @override
  Widget build(BuildContext c) {
    final na = a.text.isEmpty ? 'Team A' : a.text, nb = b.text.isEmpty ? 'Team B' : b.text;
    return Scaffold(
        appBar: AppBar(title: const Text('Match Setup')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          f(a, 'Team A'),
          f(b, 'Team B'),
          if ((DB['teams'] as List).isNotEmpty)
            Wrap(spacing: 8, children: [
              for (final t in DB['teams'])
                ActionChip(
                    label: Text(t['name']),
                    onPressed: () => setState(() {
                          if (a.text.isEmpty) {
                            a.text = t['name'];
                          } else {
                            b.text = t['name'];
                          }
                        }))
            ]),
          const SizedBox(height: 16),
          const Text('Format', style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            for (final k in F.keys)
              ChoiceChip(
                  label: Text(k),
                  selected: fmt == k,
                  onSelected: (_) => setState(() {
                        fmt = k;
                        if (F[k]! > 0) ov.text = '${F[k]}';
                      }))
          ]),
          const SizedBox(height: 12),
          Row(children: [
            if (fmt != 'Hundred') Expanded(child: f(ov, 'Overs', n: true)),
            if (fmt != 'Hundred') const SizedBox(width: 12),
            Expanded(child: f(mw, 'Wickets (all out)', n: true)),
          ]),
          f(gr, 'Ground (optional)'),
          const Text('Pehle batting', style: TextStyle(color: gold, fontWeight: FontWeight.w700)),
          Wrap(spacing: 8, children: [
            ChoiceChip(label: Text(na), selected: first == 0, onSelected: (_) => setState(() => first = 0)),
            ChoiceChip(label: Text(nb), selected: first == 1, onSelected: (_) => setState(() => first = 1)),
          ]),
          const SizedBox(height: 24),
          SizedBox(
              height: 56,
              child: FilledButton(onPressed: start, child: const Text('Match Shuru Karo', style: TextStyle(fontSize: 18)))),
        ]));
  }
}

// ---------- scoring ----------
class Scoring extends StatefulWidget {
  final Map<String, dynamic> s;
  const Scoring({super.key, required this.s});
  @override
  State<Scoring> createState() => _Sc();
}

class _Sc extends State<Scoring> {
  late final Map<String, dynamic> S = widget.s;
  final h = <String>[];
  bool wag = true;
  Map<String, dynamic> get I => S['in'][S['i']];
  bool get done => S['brk'] == true || S['done'] == true;

  @override
  void initState() {
    super.initState();
    if (I['st'] == '') WidgetsBinding.instance.addPostFrameCallback((_) => openers());
  }

  Future<String> pp(String t, int tm, List ex) async {
    final sq = S['sq'][tm] as List;
    String? r;
    while (r == null) {
      r = await pick(context, t, [for (final p in sq) if (!ex.contains(p)) p as String], dis: false);
    }
    if (!sq.contains(r)) {
      sq.add(r);
      final pl = team(S['t'][tm])['players'] as List;
      if (!pl.contains(r)) pl.add(r);
    }
    return r;
  }

  Future<void> openers() async {
    final i = I, b = i['bat'] as int;
    i['st'] = await pp('Striker chuno', b, []);
    i['ns'] = await pp('Non-striker chuno', b, [i['st']]);
    i['bo'] = await pp('Bowler chuno', 1 - b, []);
    save();
    if (mounted) setState(() {});
  }

  void swap() {
    final i = I, t = i['st'];
    i['st'] = i['ns'];
    i['ns'] = t;
  }

  String result() {
    final A = S['in'][0], B = S['in'][1], t = S['t'];
    if (B['runs'] > A['runs']) return '${t[1]} won by ${S['mw'] - B['wk']} wickets';
    if (B['runs'] < A['runs']) return '${t[0]} won by ${A['runs'] - B['runs']} runs';
    return 'Match tied';
  }

  Future<void> ball({int br = 0, String x = '', int xr = 0, bool wk = false, String how = '', String out = '', Map<String, dynamic>? sh}) async {
    h.add(jsonEncode(S));
    final i = I, lg = (x == 'wd' || x == 'nb') ? 0 : 1, bat = i['bat'] as int;
    (i['ev'] as List).add({
      'b': i['st'], 'n': i['ns'], 'w': i['bo'], 'br': br, 'x': x, 'xr': xr,
      'wk': wk, 'how': how, 'out': out, 'lg': lg, 'fh': i['fh'], 'sh': sh
    });
    i['runs'] += br + xr;
    if (lg == 1) i['legal']++;
    if (wk) i['wk']++;
    final lab = wk
        ? 'W'
        : x == 'wd'
            ? 'Wd${xr > 1 ? '+${xr - 1}' : ''}'
            : x == 'nb'
                ? 'Nb${br > 0 ? '+$br' : ''}'
                : x == 'b'
                    ? 'B$xr'
                    : x == 'lb'
                        ? 'LB$xr'
                        : '$br';
    (i['ov'] as List).add(lab);
    if (x == 'nb') {
      i['fh'] = true;
    } else if (lg == 1) {
      i['fh'] = false;
    }
    final rr = wk ? 0 : (x == 'wd' ? xr - 1 : ((x == 'b' || x == 'lb') ? xr : br));
    final oe = lg == 1 && i['legal'] % 6 == 0;
    final end = i['legal'] >= S['bl'] || i['wk'] >= S['mw'] || (S['i'] == 1 && i['runs'] > S['in'][0]['runs']);
    if (end) {
      if (S['i'] == 0) {
        S['brk'] = true;
      } else {
        S['res'] = result();
        S['done'] = true;
      }
    } else {
      if (wk) {
        final outs = (replay(i['ev'])['bt'] as Map<String, Map<String, dynamic>>)
            .entries.where((e) => e.value['out'] == true).map((e) => e.key).toList();
        final nbm = await pp('Naya batsman', bat, [...outs, i['st'], i['ns']]);
        if (out == i['st']) {
          i['st'] = nbm;
        } else {
          i['ns'] = nbm;
        }
      }
      if (rr % 2 == 1) swap();
      if (oe) {
        swap();
        i['ov'] = [];
        i['bo'] = await pp('Naya bowler', 1 - bat, [i['bo']]);
      }
    }
    save();
    if (mounted) setState(() {});
  }

  Future<void> run(int r) async {
    Map<String, dynamic>? sh;
    if (wag && r > 0) {
      sh = await wagon(context);
      sh?['br'] = r;
    }
    await ball(br: r, sh: sh);
  }

  Future<void> wd() async {
    final r = await numPick(context, 'Wide + extra runs', max: 4);
    if (r != null) await ball(x: 'wd', xr: 1 + r);
  }

  Future<void> nb() async {
    final r = await numPick(context, 'No Ball: bat se runs');
    if (r == null) return;
    Map<String, dynamic>? sh;
    if (wag && r > 0) {
      sh = await wagon(context);
      sh?['br'] = r;
    }
    await ball(x: 'nb', br: r, xr: 1, sh: sh);
  }

  Future<void> bye(String k) async {
    final r = await numPick(context, k == 'b' ? 'Byes' : 'Leg Byes', min: 1, max: 4);
    if (r != null) await ball(x: k, xr: r);
  }

  Future<void> wicket() async {
    final fh = I['fh'] == true;
    final how = await pick(context, fh ? 'Free Hit: sirf Run out' : 'Out kaise?',
        fh ? ['Run out'] : ['Bowled', 'Caught', 'LBW', 'Run out', 'Stumped', 'Hit wicket'], nw: false);
    if (how == null) return;
    String out = I['st'];
    int r = 0;
    if (how == 'Run out') {
      r = await numPick(context, 'Run out se pehle runs', max: 3) ?? 0;
      final o = await pick(context, 'Kaun out?', [I['st'], I['ns']], nw: false);
      if (o == null) return;
      out = o;
    }
    await ball(br: r, wk: true, how: how, out: out);
  }
void undo() {
    if (h.isEmpty) return;
    final s = jsonDecode(h.removeLast()) as Map<String, dynamic>;
    S.clear();
    S.addAll(s);
    save();
    setState(() {});
  }

  Future<void> second() async {
    S['i'] = 1;
    (S['in'] as List).add(newInn(1));
    S['brk'] = false;
    h.clear();
    await openers();
  }

  Widget key(String l, Color col, VoidCallback f, {Color fg = Colors.white}) => Material(
      color: col,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: done ? null : f,
          child: Center(child: Text(l, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: fg)))));

  Widget row(String a, String b, {bool bold = false, Color? col}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: col)),
        Text(b, style: TextStyle(fontWeight: FontWeight.w700, color: col))
      ]));

  @override
  Widget build(BuildContext c) {
    final i = I, t = S['t'], left = (S['bl'] as int) - (i['legal'] as int);
    final crr = i['legal'] > 0 ? (i['runs'] * 6 / i['legal']).toStringAsFixed(2) : '0.00';
    final rp = i['st'] == '' ? null : replay(i['ev']);
    final bt = rp?['bt'] as Map<String, Map<String, dynamic>>?, bw = rp?['bw'] as Map<String, Map<String, dynamic>>?;
    Map<String, dynamic> g(Map<String, Map<String, dynamic>>? m, String n, Map<String, dynamic> d) => m?[n] ?? d;
    final z = {'r': 0, 'b': 0, 'w': 0};
    final target = S['i'] == 1 ? (S['in'][0]['runs'] as int) + 1 : 0;
    return Scaffold(
        appBar: AppBar(
            title: Text('${t[0]} vs ${t[1]}', style: const TextStyle(fontSize: 16)),
            actions: [
              IconButton(
                  tooltip: 'Wagon wheel',
                  icon: Icon(Icons.radar, color: wag ? gold : Colors.white38),
                  onPressed: () => setState(() => wag = !wag)),
              IconButton(icon: const Icon(Icons.undo), onPressed: undo),
              IconButton(icon: const Icon(Icons.leaderboard), onPressed: () => go(c, ScoreView(m: S))),
            ]),
        body: ListView(padding: const EdgeInsets.all(14), children: [
          if (S['brk'] == true)
            glass(
                g: const LinearGradient(colors: [Color(0xFF7A5A12), Color(0xFF3D2D08)]),
                Column(children: [
                  Text('Innings khatam: ${t[0]} ${S['in'][0]['runs']}/${S['in'][0]['wk']}  •  Target ${S['in'][0]['runs'] + 1}',
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  FilledButton(onPressed: second, child: const Text('2nd Innings Shuru'))
                ])),
          if (S['done'] == true)
            glass(
                g: const LinearGradient(colors: [Color(0xFF7A5A12), Color(0xFF3D2D08)]),
                Row(children: [
                  const Text('🏆 ', style: TextStyle(fontSize: 26)),
                  Expanded(child: Text(S['res'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))
                ])),
          glass(
              pad: 20,
              g: const LinearGradient(colors: [Color(0xFF0F4A35), Color(0xFF0A1B26)]),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  logo(t[S['i']], 30),
                  const SizedBox(width: 10),
                  Text('${t[S['i']]} batting', style: const TextStyle(color: Colors.white70)),
                  const Spacer(),
                  if (i['fh'] == true)
                    Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: rd, borderRadius: BorderRadius.circular(20)),
                        child: const Text('FREE HIT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)))
                ]),
                Text('${i['runs']}/${i['wk']}',
                    style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w900, height: 1.1)),
                Text('${ovs(i['legal'])} / ${ovs(S['bl'])} ov   •   CRR $crr',
                    style: const TextStyle(color: gold, fontWeight: FontWeight.w700)),
                if (S['i'] == 1)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                          'Chahiye ${max(0, target - (i['runs'] as int))} runs, $left balls mein'
                          '${left > 0 ? '  •  RRR ${(max(0, target - (i['runs'] as int)) * 6 / left).toStringAsFixed(2)}' : ''}',
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final x in i['ov'])
                    CircleAvatar(
                        radius: 15,
                        backgroundColor: x == 'W' ? rd : (x == '4' || x == '6' ? gold : Colors.white12),
                        child: Text(x,
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: (x == '4' || x == '6') ? Colors.black : Colors.white)))
                ]),
              ])),
          if (rp != null && !done)
            glass(Column(children: [
              row('🏏 ${i['st']}*', '${g(bt, i['st'], z)['r']} (${g(bt, i['st'], z)['b']})', bold: true, col: em),
              row('   ${i['ns']}', '${g(bt, i['ns'], z)['r']} (${g(bt, i['ns'], z)['b']})'),
              const Divider(color: Colors.white12),
              row('🎯 ${i['bo']}',
                  '${ovs(g(bw, i['bo'], z)['b'])} - ${g(bw, i['bo'], z)['r']} - ${g(bw, i['bo'], z)['w']}',
                  bold: true),
            ])),
          SizedBox(
              height: 190,
              child: GridView.count(
                  crossAxisCount: 4,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (var r = 0; r <= 6; r++)
                      key('$r', r == 4 ? em : (r == 6 ? gold : const Color(0xFF1C2733)), () => run(r),
                          fg: (r == 4 || r == 6) ? Colors.black : Colors.white),
                    key('OUT', rd, wicket),
                  ])),
          const SizedBox(height: 8),
          SizedBox(
              height: 56,
              child: Row(children: [
                for (final e in [
                  ['Wide', wd],
                  ['No Ball', nb],
                  ['Bye', () => bye('b')],
                  ['Leg Bye', () => bye('lb')]
                ]) ...[
                  Expanded(child: key(e[0] as String, const Color(0xFF26364A), e[1] as VoidCallback)),
                  const SizedBox(width: 8)
                ]
              ])),
          TextButton.icon(
              onPressed: done
                  ? null
                  : () {
                      swap();
                      save();
                      setState(() {});
                    },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Strike badlo')),
        ]));
  }
}

// ---------- scorecard ----------
Widget tr(List<String> c, {bool b = false, List<int>? f}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      for (var k = 0; k < c.length; k++)
        Expanded(
            flex: k == 0 ? 4 : 1,
            child: Text(c[k],
                textAlign: k == 0 ? TextAlign.left : TextAlign.right,
                style: TextStyle(fontSize: 13, fontWeight: b ? FontWeight.w800 : FontWeight.w500, color: b ? gold : null)))
    ]));

class ScoreView extends StatefulWidget {
  final Map m;
  const ScoreView({super.key, required this.m});
  @override
  State<ScoreView> createState() => _SV();
}

class _SV extends State<ScoreView> {
  String? who;
  Map get m => widget.m;

  Future<void> pdf() async {
    final d = pw.Document();
    pw.Widget tb(List<List<String>> rows) => pw.Table(
        border: pw.TableBorder.all(),
        children: [
          for (final r in rows)
            pw.TableRow(children: [
              for (final x in r) pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(x, style: const pw.TextStyle(fontSize: 10)))
            ])
        ]);
    final w = <pw.Widget>[
      pw.Text('${m['t'][0]} vs ${m['t'][1]}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.Text('${m['res'] == '' ? 'In progress' : m['res']}   ${m['g'] ?? ''}'),
      pw.SizedBox(height: 10)
    ];
    for (var k = 0; k < (m['in'] as List).length; k++) {
      final n = m['in'][k], r = replay(n['ev']);
      w.add(pw.Text('${m['t'][k]}  ${n['runs']}/${n['wk']} (${ovs(n['legal'])})',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)));
      w.add(tb([
        ['Batsman', 'Out', 'R', 'B', '4s', '6s'],
        for (final e in (r['bt'] as Map<String, Map<String, dynamic>>).entries)
          [e.key, e.value['out'] == true ? e.value['how'] : 'not out', '${e.value['r']}', '${e.value['b']}', '${e.value['f']}', '${e.value['s']}']
      ]));
      w.add(pw.Text('Extras: ${r['ex']}   FOW: ${(r['fow'] as List).join(', ')}'));
      w.add(tb([
        ['Bowler', 'O', 'R', 'W'],
        for (final e in (r['bw'] as Map<String, Map<String, dynamic>>).entries)
          [e.key, ovs(e.value['b']), '${e.value['r']}', '${e.value['w']}']
      ]));
      w.add(pw.SizedBox(height: 14));
    }
    d.addPage(pw.MultiPage(build: (_) => w));
    await Printing.sharePdf(bytes: await d.save(), filename: 'scorecard.pdf');
  }

  @override
  Widget build(BuildContext c) {
    final ins = m['in'] as List;
    final names = <String>{};
    for (final n in ins) {
      for (final e in n['ev']) {
        names.add(e['b']);
      }
    }
    final shots = [
      for (final n in ins)
        for (final e in n['ev'])
          if (e['sh'] != null && (who == null || e['b'] == who)) e['sh']
    ];
    return DefaultTabController(
        length: 3,
        child: Scaffold(
            appBar: AppBar(
                title: Text('${m['t'][0]} vs ${m['t'][1]}', style: const TextStyle(fontSize: 16)),
                actions: [IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: pdf)],
                bottom: const TabBar(tabs: [Tab(text: 'Scorecard'), Tab(text: 'Graphs'), Tab(text: 'Wagon')])),
            body: TabBarView(children: [
              ListView(padding: const EdgeInsets.all(14), children: [
                if (m['res'] != '')
                  glass(Text('🏆 ${m['res']}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: gold))),
                for (var k = 0; k < ins.length; k++) ...[
                  () {
                    final n = ins[k], r = replay(n['ev']);
                    return glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        logo(m['t'][k], 34),
                        const SizedBox(width: 10),
                        Expanded(child: Text('${m['t'][k]}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        Text('${n['runs']}/${n['wk']}  (${ovs(n['legal'])})',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: em))
                      ]),
                      const Divider(color: Colors.white12),
                      tr(['Batsman', 'R', 'B', '4s', '6s'], b: true),
                      for (final e in (r['bt'] as Map<String, Map<String, dynamic>>).entries) ...[
                        tr([e.key, '${e.value['r']}', '${e.value['b']}', '${e.value['f']}', '${e.value['s']}']),
                        Text(e.value['out'] == true ? e.value['how'] : 'not out',
                            style: const TextStyle(fontSize: 11, color: Colors.white54)),
                      ],
                      const SizedBox(height: 6),
                      Text('Extras: ${r['ex']}', style: const TextStyle(color: Colors.white70)),
                      if ((r['fow'] as List).isNotEmpty)
                        Text('FOW: ${(r['fow'] as List).join(', ')}',
                            style: const TextStyle(fontSize: 12, color: Colors.white54)),
                      const Divider(color: Colors.white12),
                      tr(['Bowler', 'O', 'R', 'W'], b: true),
                      for (final e in (r['bw'] as Map<String, Map<String, dynamic>>).entries)
                        tr([e.key, ovs(e.value['b']), '${e.value['r']}', '${e.value['w']}']),
                    ]));
                  }()
                ]
              ]),
              ListView(padding: const EdgeInsets.all(14), children: [
                glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Worm (run progression)', style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  SizedBox(
                      height: 200,
                      width: double.infinity,
                      child: CustomPaint(
                          painter: Worm([for (final n in ins) worm(n['ev'])], max(1, m['bl'] as int)))),
                  Text('${m['t'][0]} ● ${ins.length > 1 ? m['t'][1] : ''}',
                      style: const TextStyle(color: Colors.white54, fontSize: 12))
                ])),
                for (var k = 0; k < ins.length; k++)
                  glass(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${m['t'][k]} • Over by over', style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    SizedBox(
                        height: 130,
                        width: double.infinity,
                        child: CustomPaint(painter: Bars(overRuns(ins[k]['ev']))))
                  ])),
              ]),
              ListView(padding: const EdgeInsets.all(14), children: [
                DropdownButtonFormField<String?>(
                    value: who,
                    decoration: const InputDecoration(labelText: 'Batsman', filled: true),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('Sab')),
                      for (final n in names) DropdownMenuItem(value: n, child: Text(n))
                    ],
                    onChanged: (v) => setState(() => who = v)),
                const SizedBox(height: 14),
                Center(child: CustomPaint(size: const Size(300, 300), painter: Wag(shots))),
                const SizedBox(height: 8),
                const Text('Gold = 6 • Green = 4 • Safed = baaki runs',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
              ]),
            ])));
  }
}

// ---------- teams ----------
class TeamsTab extends StatefulWidget {
  const TeamsTab({super.key});
  @override
  State<TeamsTab> createState() => _Teams();
}

class _Teams extends State<TeamsTab> {
  Future<void> add() async {
    final n = await pick(context, 'Nayi team ka naam', [], nw: true);
    if (n != null) {
      team(n);
      save();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext c) {
    final ts = DB['teams'] as List;
    return Scaffold(
        backgroundColor: Colors.transparent,
        floatingActionButton: FloatingActionButton.extended(
            onPressed: add, icon: const Icon(Icons.add), label: const Text('Nayi Team')),
        body: ListView(padding: const EdgeInsets.all(18), children: [
          const Text('Teams', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          if (ts.isEmpty)
            const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('Koi team nahi', style: TextStyle(color: Colors.white54)))),
          for (final t in ts)
            glass(
                onTap: () async {
                  await go(c, TeamPage(t: t));
                  setState(() {});
                },
                Row(children: [
                  logo(t['name'], 50),
                  const SizedBox(width: 14),
                  Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(t['name'], style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    Text('${(t['players'] as List).length} players', style: const TextStyle(color: Colors.white54))
                  ])),
                  const Icon(Icons.chevron_right)
                ])),
          const SizedBox(height: 70),
        ]));
  }
}

class TeamPage extends StatefulWidget {
  final Map t;
  const TeamPage({super.key, required this.t});
  @override
  State<TeamPage> createState() => _TP();
}

class _TP extends State<TeamPage> {
  final tc0 = TextEditingController();
  List get pl => widget.t['players'];
  @override
  Widget build(BuildContext c) => Scaffold(
      appBar: AppBar(title: Text(widget.t['name'])),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        TextField(
            controller: tc0,
            decoration: InputDecoration(
                hintText: 'Player ka naam',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                    icon: const Icon(Icons.add_circle, color: em),
                    onPressed: () {
                      final n = tc0.text.trim();
                      if (n.isNotEmpty && !pl.contains(n)) {
                        pl.add(n);
                        save();
                        tc0.clear();
                        setState(() {});
                      }
                    }))),
        const SizedBox(height: 14),
        for (final p in List.from(pl))
          glass(
              pad: 10,
              Row(children: [
                logo(p, 38),
                const SizedBox(width: 12),
                Expanded(child: Text(p, style: const TextStyle(fontWeight: FontWeight.w700))),
                IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white38),
                    onPressed: () {
                      pl.remove(p);
                      save();
                      setState(() {});
                    })
              ])),
      ]));
}

// ---------- stats ----------
class StatsTab extends StatelessWidget {
  const StatsTab({super.key});
  @override
  Widget build(BuildContext c) {
    final bt = <String, Map<String, dynamic>>{}, bw = <String, Map<String, dynamic>>{}, hat = <String, int>{};
    final fast = {'m30': <String, int>{}, 'm50': <String, int>{}, 'm100': <String, int>{}};
    for (final m in DB['matches']) {
      for (final n in m['in']) {
        final r = replay(n['ev']);
        (r['bt'] as Map<String, Map<String, dynamic>>).forEach((p, s) {
          if (s['b'] == 0 && s['out'] != true) return;
          final a = bt.putIfAbsent(p, () => {'inn': 0, 'r': 0, 'b': 0, 'f': 0, 's': 0, 'hs': 0});
          a['inn']++;
          a['r'] += s['r'];
          a['b'] += s['b'];
          a['f'] += s['f'];
          a['s'] += s['s'];
          if (s['r'] > a['hs']) a['hs'] = s['r'];
          for (final k in fast.keys) {
            if (s[k] != null && (fast[k]![p] == null || s[k] < fast[k]![p]!)) fast[k]![p] = s[k];
          }
        });
        (r['bw'] as Map<String, Map<String, dynamic>>).forEach((p, s) {
          final a = bw.putIfAbsent(p, () => {'b': 0, 'r': 0, 'w': 0});
          a['b'] += s['b'];
          a['r'] += s['r'];
          a['w'] += s['w'];
        });
        (r['hat'] as Map<String, int>).forEach((p, v) => hat[p] = (hat[p] ?? 0) + v);
      }
    }
    final runs = bt.entries.toList()..sort((a, b) => b.value['r'].compareTo(a.value['r']));
    final wk = bw.entries.where((e) => e.value['b'] > 0).toList()
      ..sort((a, b) => b.value['w'] != a.value['w'] ? b.value['w'].compareTo(a.value['w']) : a.value['r'].compareTo(b.value['r']));
    Widget item(int k, String n, String big, String sub) => glass(
        pad: 12,
        Row(children: [
          SizedBox(width: 26, child: Text('${k + 1}', style: const TextStyle(color: gold, fontWeight: FontWeight.w900))),
          logo(n, 36),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: const TextStyle(fontWeight: FontWeight.w700)),
            Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 12))
          ])),
          Text(big, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: em))
        ]));
    Widget empty() => const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('Match khelo, stats yahan aayengi', style: TextStyle(color: Colors.white54))));
    List<Widget> fl(String k, String t) {
      final l = fast[k]!.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      return [
        Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(t, style: const TextStyle(color: gold, fontWeight: FontWeight.w800))),
        if (l.isEmpty) const Text('—', style: TextStyle(color: Colors.white38)),
        for (var i = 0; i < min(3, l.length); i++) item(i, l[i].key, '${l[i].value}', 'balls mein')
      ];
    }

    return DefaultTabController(
        length: 3,
        child: Column(children: [
          const Padding(
              padding: EdgeInsets.fromLTRB(18, 18, 18, 0),
              child: Align(alignment: Alignment.centerLeft, child: Text('Stats', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)))),
          const TabBar(tabs: [Tab(text: 'Batting'), Tab(text: 'Bowling'), Tab(text: 'Records')]),
          Expanded(
              child: TabBarView(children: [
            runs.isEmpty
                ? empty()
                : ListView(padding: const EdgeInsets.all(14), children: [
                    for (var k = 0; k < runs.length; k++)
                      item(k, runs[k].key, '${runs[k].value['r']}',
                          '${runs[k].value['inn']} inn • HS ${runs[k].value['hs']} • SR ${runs[k].value['b'] == 0 ? 0 : (runs[k].value['r'] * 100 / runs[k].value['b']).toStringAsFixed(1)} • 4s ${runs[k].value['f']} • 6s ${runs[k].value['s']}')
                  ]),
            wk.isEmpty
                ? empty()
                : ListView(padding: const EdgeInsets.all(14), children: [
                    for (var k = 0; k < wk.length; k++)
                      item(k, wk[k].key, '${wk[k].value['w']}',
                          '${ovs(wk[k].value['b'])} ov • ${wk[k].value['r']} runs • Econ ${(wk[k].value['r'] * 6 / wk[k].value['b']).toStringAsFixed(2)}')
                  ]),
            ListView(padding: const EdgeInsets.all(14), children: [
              ...fl('m30', '⚡ Fastest 30'),
              ...fl('m50', '🔥 Fastest 50'),
              ...fl('m100', '👑 Fastest 100'),
              const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('🎩 Hat-tricks', style: TextStyle(color: gold, fontWeight: FontWeight.w800))),
              if (hat.isEmpty) const Text('—', style: TextStyle(color: Colors.white38)),
              for (final e in hat.entries) item(0, e.key, '${e.value}', 'hat-trick'),
            ]),
          ])),
        ]));
  }
}
