import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext c) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'CricScore',
        theme: ThemeData(
            useMaterial3: true,
            colorSchemeSeed: const Color(0xFF0B6B3A),
            brightness: Brightness.dark),
        home: const Home(),
      );
}

// ---------- helpers ----------
Map<String, dynamic> newInn() => {
      'runs': 0, 'wk': 0, 'legal': 0, 'ov': [], 'bt': {}, 'bw': {},
      'st': '', 'ns': '', 'bo': ''
    };
Map<String, dynamic> bt(Map I, String n) => (I['bt'] as Map<String, dynamic>)
    .putIfAbsent(n, () => {'r': 0, 'b': 0, 'f': 0, 's': 0, 'o': 0});
Map<String, dynamic> bw(Map I, String n) => (I['bw'] as Map<String, dynamic>)
    .putIfAbsent(n, () => {'b': 0, 'r': 0, 'w': 0});
String ovs(int b) => '${b ~/ 6}.${b % 6}';

Future<void> saveMatch(Map s) async {
  final p = await SharedPreferences.getInstance();
  await p.setString('cs', jsonEncode(s));
}

Future<String> ask(BuildContext c, String q, String d) async {
  final t = TextEditingController();
  final v = await showDialog<String>(
    context: c,
    barrierDismissible: false,
    builder: (x) => AlertDialog(
      title: Text(q),
      content: TextField(
          controller: t,
          autofocus: true,
          decoration: InputDecoration(hintText: d)),
      actions: [
        FilledButton(
            onPressed: () => Navigator.pop(x, t.text.trim()),
            child: const Text('OK'))
      ],
    ),
  );
  return (v == null || v.isEmpty) ? d : v;
}

// ---------- Home ----------
class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  Map<String, dynamic>? saved;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('cs');
    setState(() => saved = s == null ? null : jsonDecode(s));
  }

  @override
  Widget build(BuildContext c) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('🏏', style: TextStyle(fontSize: 64)),
            const Text('CricScore',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                  onPressed: () async {
                    await Navigator.push(c,
                        MaterialPageRoute(builder: (_) => const Setup()));
                    load();
                  },
                  child: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('Naya Match', style: TextStyle(fontSize: 18)))),
            ),
            if (saved != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.push(
                          c,
                          MaterialPageRoute(
                              builder: (_) => Scoring(s: saved!)));
                      load();
                    },
                    child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                            'Resume: ${saved!['t'][0]} vs ${saved!['t'][1]}',
                            style: const TextStyle(fontSize: 16)))),
              ),
            ]
          ]),
        ),
      ),
    );
  }
}

// ---------- Setup ----------
class Setup extends StatefulWidget {
  const Setup({super.key});
  @override
  State<Setup> createState() => _SetupState();
}

class _SetupState extends State<Setup> {
  final a = TextEditingController(), b = TextEditingController();
  final o = TextEditingController(text: '10');
  int first = 0;

  @override
  Widget build(BuildContext c) {
    final na = a.text.isEmpty ? 'Team A' : a.text;
    final nb = b.text.isEmpty ? 'Team B' : b.text;
    return Scaffold(
      appBar: AppBar(title: const Text('Match Setup')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(
            controller: a,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Team A')),
        TextField(
            controller: b,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(labelText: 'Team B')),
        TextField(
            controller: o,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Overs')),
        const SizedBox(height: 16),
        const Text('Pehle batting kaun karega?'),
        Wrap(spacing: 8, children: [
          ChoiceChip(
              label: Text(na),
              selected: first == 0,
              onSelected: (_) => setState(() => first = 0)),
          ChoiceChip(
              label: Text(nb),
              selected: first == 1,
              onSelected: (_) => setState(() => first = 1)),
        ]),
        const SizedBox(height: 24),
        FilledButton(
            onPressed: () {
              final t = first == 0 ? [na, nb] : [nb, na];
              final s = <String, dynamic>{
                't': t,
                'ov': int.tryParse(o.text) ?? 10,
                'i': 0,
                'in': [newInn()],
                'brk': false,
                'res': ''
              };
              saveMatch(s);
              Navigator.pushReplacement(
                  c, MaterialPageRoute(builder: (_) => Scoring(s: s)));
            },
            child: const Padding(
                padding: EdgeInsets.all(14),
                child: Text('Match Shuru Karo', style: TextStyle(fontSize: 18)))),
      ]),
    );
  }
}

// ---------- Scoring ----------
class Scoring extends StatefulWidget {
  final Map<String, dynamic> s;
  const Scoring({super.key, required this.s});
  @override
  State<Scoring> createState() => _ScoringState();
}

class _ScoringState extends State<Scoring> {
  late Map<String, dynamic> S = widget.s;
  final List<String> h = [];
  Map<String, dynamic> get I => S['in'][S['i']];
  bool get done => S['brk'] == true || S['res'] != '';

  @override
  void initState() {
    super.initState();
    if (I['st'] == '') {
      WidgetsBinding.instance.addPostFrameCallback((_) => openers());
    }
  }

  Future<void> openers() async {
    final i = I;
    i['st'] = await ask(context, 'Striker ka naam', 'Batsman 1');
    i['ns'] = await ask(context, 'Non-striker ka naam', 'Batsman 2');
    i['bo'] = await ask(context, 'Bowler ka naam', 'Bowler 1');
    bt(i, i['st']);
    bt(i, i['ns']);
    bw(i, i['bo']);
    await saveMatch(S);
    if (mounted) setState(() {});
  }

  void swap() {
    final i = I;
    final t = i['st'];
    i['st'] = i['ns'];
    i['ns'] = t;
  }

  String result() {
    final A = S['in'][0], B = S['in'][1], t = S['t'];
    if (B['runs'] > A['runs']) return '${t[1]} won by ${10 - B['wk']} wickets';
    if (B['runs'] < A['runs']) return '${t[0]} won by ${A['runs'] - B['runs']} runs';
    return 'Match tied';
  }

  Future<int> num_(String q, String d) async =>
      int.tryParse(await ask(context, q, d)) ?? 0;

  Future<void> ball(String type, [int r = 0]) async {
    if (done) return;
    h.add(jsonEncode(S));
    final i = I;
    final b = bt(i, i['st']), w = bw(i, i['bo']);
    int lg = 0, sw = 0;
    bool wk = false;
    String lab = '';
    if (type == 'run') {
      i['runs'] += r; b['r'] += r; b['b']++; w['r'] += r;
      lg = 1; lab = '$r'; sw = r % 2;
      if (r == 4) b['f']++;
      if (r == 6) b['s']++;
    } else if (type == 'wd') {
      r = await num_('Wide ke ilawa extra runs?', '0');
      i['runs'] += 1 + r; w['r'] += 1 + r;
      lab = 'Wd${r > 0 ? '+$r' : ''}'; sw = r % 2;
    } else if (type == 'nb') {
      r = await num_('Bat se runs?', '0');
      i['runs'] += 1 + r; b['r'] += r; b['b']++; w['r'] += 1 + r;
      lab = 'Nb${r > 0 ? '+$r' : ''}'; sw = r % 2;
      if (r == 4) b['f']++;
      if (r == 6) b['s']++;
    } else if (type == 'bye' || type == 'lb') {
      r = await num_('Kitne runs?', '1');
      i['runs'] += r; b['b']++; lg = 1;
      lab = '${type == 'bye' ? 'B' : 'LB'}$r'; sw = r % 2;
    } else if (type == 'w') {
      i['wk']++; b['b']++; b['o'] = 1; w['w']++; lg = 1; lab = 'W'; wk = true;
    }
    if (lg == 1) {
      i['legal']++;
      w['b']++;
    }
    (i['ov'] as List).add(lab);
    final overEnd = lg == 1 && i['legal'] % 6 == 0;
    final end = i['legal'] >= S['ov'] * 6 ||
        i['wk'] >= 10 ||
        (S['i'] == 1 && i['runs'] > S['in'][0]['runs']);
    if (end) {
      if (S['i'] == 0) {
        S['brk'] = true;
      } else {
        S['res'] = result();
      }
    } else {
      if (wk) {
        i['st'] = await ask(context, 'Naya batsman ka naam', 'Batsman');
        bt(i, i['st']);
      }
      if (sw == 1) swap();
      if (overEnd) {
        swap();
        i['ov'] = [];
        i['bo'] = await ask(context, 'Naya bowler ka naam', 'Bowler');
        bw(i, i['bo']);
      }
    }
    await saveMatch(S);
    if (mounted) setState(() {});
  }

  void undo() {
    if (h.isEmpty) return;
    S = jsonDecode(h.removeLast());
    saveMatch(S);
    setState(() {});
  }

  Future<void> second() async {
    S['i'] = 1;
    (S['in'] as List).add(newInn());
    S['brk'] = false;
    h.clear();
    await openers();
  }

  Widget btn(String l, VoidCallback f, [Color? col]) => FilledButton(
      style: FilledButton.styleFrom(
          backgroundColor: col,
          foregroundColor: col == Colors.amber ? Colors.black : null,
          padding: EdgeInsets.zero),
      onPressed: done ? null : f,
      child: Text(l,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)));

  Widget row(String a, String b, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(a,
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
        Text(b)
      ]));

  @override
  Widget build(BuildContext c) {
    final i = I;
    final t = S['t'];
    final left = S['ov'] * 6 - i['legal'];
    final crr =
        i['legal'] > 0 ? (i['runs'] * 6 / i['legal']).toStringAsFixed(2) : '0.00';
    final hasP = i['st'] != '';
    return Scaffold(
      appBar: AppBar(
        title: Text('${t[0]} vs ${t[1]}', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.undo), onPressed: undo),
          IconButton(
              icon: const Icon(Icons.list_alt),
              onPressed: () => Navigator.push(c,
                  MaterialPageRoute(builder: (_) => ScoreView(s: S)))),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        if (S['brk'] == true)
          Card(
              color: Colors.amber,
              child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(children: [
                    Text(
                        'Innings khatam: ${t[0]} ${S['in'][0]['runs']}/${S['in'][0]['wk']}. Target ${S['in'][0]['runs'] + 1}',
                        style: const TextStyle(
                            color: Colors.black, fontWeight: FontWeight.bold)),
                    FilledButton(
                        onPressed: second,
                        child: const Text('2nd Innings Shuru'))
                  ]))),
        if (S['res'] != '')
          Card(
              color: Colors.amber,
              child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text('🏆 ${S['res']}',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 17,
                          fontWeight: FontWeight.bold)))),
        Card(
            child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${t[S['i']]} batting • ${S['ov']} overs',
                style: const TextStyle(color: Colors.white60)),
            Text('${i['runs']}/${i['wk']}  (${ovs(i['legal'])})',
                style:
                    const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
            Text('CRR $crr'),
            if (S['i'] == 1)
              Text(
                  'Target ${S['in'][0]['runs'] + 1} • ${(S['in'][0]['runs'] + 1 - i['runs']).clamp(0, 9999)} runs, $left balls baqi'
                  '${left > 0 ? ' • RRR ${((S['in'][0]['runs'] + 1 - i['runs']) * 6 / left).toStringAsFixed(2)}' : ''}'),
            if (hasP && !done) ...[
              const Divider(),
              row('🏏 ${i['st']}*',
                  '${bt(i, i['st'])['r']} (${bt(i, i['st'])['b']})',
                  bold: true),
              row(i['ns'],
                  '${bt(i, i['ns'])['r']} (${bt(i, i['ns'])['b']})'),
              row('🎯 ${i['bo']}',
                  '${ovs(bw(i, i['bo'])['b'])}-${bw(i, i['bo'])['r']}-${bw(i, i['bo'])['w']}'),
              Wrap(spacing: 6, children: [
                for (final x in i['ov'])
                  CircleAvatar(
                      radius: 16,
                      backgroundColor: x == 'W'
                          ? Colors.red
                          : (x == '4' || x == '6')
                              ? Colors.amber
                              : Colors.white24,
                      child: Text(x,
                          style: TextStyle(
                              fontSize: 11,
                              color: (x == '4' || x == '6')
                                  ? Colors.black
                                  : Colors.white)))
              ])
            ]
          ]),
        )),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.3,
          children: [
            for (final r in [0, 1, 2, 3]) btn('$r', () => ball('run', r)),
            btn('4', () => ball('run', 4), Colors.amber),
            btn('6', () => ball('run', 6), Colors.purple),
            btn('OUT', () => ball('w'), Colors.red),
            btn('Wide', () => ball('wd'), Colors.blueGrey),
            btn('No Ball', () => ball('nb'), Colors.blueGrey),
            btn('Bye', () => ball('bye'), Colors.blueGrey),
            btn('Leg Bye', () => ball('lb'), Colors.blueGrey),
            btn('Swap ⇄', () {
              swap();
              saveMatch(S);
              setState(() {});
            }, Colors.blueGrey),
          ],
        ),
      ]),
    );
  }
}

// ---------- Scorecard ----------
class ScoreView extends StatelessWidget {
  final Map<String, dynamic> s;
  const ScoreView({super.key, required this.s});

  Widget line(List<String> c, {bool bold = false}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(
            flex: 3,
            child: Text(c[0],
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal))),
        for (final x in c.sublist(1))
          Expanded(
              child: Text(x,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal)))
      ]));

  @override
  Widget build(BuildContext c) {
    final ins = s['in'] as List;
    return Scaffold(
      appBar: AppBar(title: const Text('Scorecard')),
      body: ListView(padding: const EdgeInsets.all(12), children: [
        for (var k = 0; k < ins.length; k++)
          Card(
              child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [
              Text(
                  '${s['t'][k]}  ${ins[k]['runs']}/${ins[k]['wk']} (${ovs(ins[k]['legal'])})',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Divider(),
              line(['Batsman', 'R', 'B', '4s', '6s'], bold: true),
              for (final e in (ins[k]['bt'] as Map).entries)
                line([
                  '${e.key}${e.value['o'] == 1 ? '' : '*'}',
                  '${e.value['r']}',
                  '${e.value['b']}',
                  '${e.value['f']}',
                  '${e.value['s']}'
                ]),
              const Divider(),
              line(['Bowler', 'O', 'R', 'W'], bold: true),
              for (final e in (ins[k]['bw'] as Map).entries)
                line([
                  '${e.key}',
                  ovs(e.value['b']),
                  '${e.value['r']}',
                  '${e.value['w']}'
                ]),
            ]),
          ))
      ]),
    );
  }
}
