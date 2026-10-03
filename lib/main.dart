import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

const Color kBg = Color(0xFF0B1426);
const Color kGold = Color(0xFFC9A24B);
const Color kText = Color(0xFFFFFFFF);
const Color kMuted = Color(0xFF9AA3B8);

const List<Color> kNoteColors = [
  Color(0xFF1A2A4D),
  Color(0xFF2D1B3D),
  Color(0xFF1B3D2F),
  Color(0xFF3D2B1B),
  Color(0xFF3D1B24),
  Color(0xFF1B3A3D),
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: kBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const NotesApp());
}

class NotesApp extends StatelessWidget {
  const NotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Notes',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(primary: kGold, surface: kBg),
      ),
      home: const HomePage(),
    );
  }
}

class Note {
  String id;
  String title;
  String body;
  int color;
  bool pinned;
  int updated;

  Note({
    required this.id,
    this.title = '',
    this.body = '',
    this.color = 0,
    this.pinned = false,
    required this.updated,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'color': color,
        'pinned': pinned,
        'updated': updated,
      };

  factory Note.fromJson(Map<String, dynamic> j) => Note(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        body: (j['body'] ?? '') as String,
        color: (j['color'] ?? 0) as int,
        pinned: (j['pinned'] ?? false) as bool,
        updated: (j['updated'] ?? 0) as int,
      );
}

String formatDate(int ms) {
  const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${m[d.month - 1]}';
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const _key = 'notes_v1';
  List<Note> _notes = [];
  String _query = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw != null) {
      final list = jsonDecode(raw) as List;
      _notes = list.map((e) => Note.fromJson(e as Map<String, dynamic>)).toList();
    }
    setState(() => _loading = false);
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(_notes.map((n) => n.toJson()).toList()));
  }

  void _upsert(Note note) {
    final i = _notes.indexWhere((n) => n.id == note.id);
    setState(() {
      if (i >= 0) {
        _notes[i] = note;
      } else {
        _notes.add(note);
      }
    });
    _persist();
  }

  void _delete(String id) {
    setState(() => _notes.removeWhere((n) => n.id == id));
    _persist();
  }

  void _open(Note? existing) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorPage(note: existing, onSave: _upsert, onDelete: _delete),
    ));
  }

  List<Note> get _visible {
    final q = _query.toLowerCase();
    final list = _notes
        .where((n) => q.isEmpty || n.title.toLowerCase().contains(q) || n.body.toLowerCase().contains(q))
        .toList();
    list.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updated.compareTo(a.updated);
    });
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final notes = _visible;
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kGold,
        foregroundColor: kBg,
        onPressed: () => _open(null),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Note', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 4),
              child: Text('My Notes',
                  style: TextStyle(color: kText, fontSize: 30, fontWeight: FontWeight.bold)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('${_notes.length} notes',
                  style: const TextStyle(color: kMuted, fontSize: 14)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: kText),
                cursorColor: kGold,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  hintStyle: const TextStyle(color: kMuted),
                  prefixIcon: const Icon(Icons.search_rounded, color: kMuted),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: kGold, width: 1.5),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: kGold))
                  : notes.isEmpty
                      ? _empty()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: Column(children: left.map(_card).toList())),
                              Expanded(child: Column(children: right.map(_card).toList())),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF1A2A4D),
              border: Border.all(color: kGold, width: 2),
            ),
            child: const Icon(Icons.edit_note_rounded, color: kGold, size: 46),
          ),
          const SizedBox(height: 18),
          Text(_query.isEmpty ? 'Koi note nahi' : 'Kuch nahi mila',
              style: const TextStyle(color: kText, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(_query.isEmpty ? 'New Note par tap karke shuru karein' : 'Doosra word search karein',
              style: const TextStyle(color: kMuted)),
        ],
      ),
    );
  }

  Widget _card(Note n) {
    return GestureDetector(
      onTap: () => _open(n),
      onLongPress: () {
        n.pinned = !n.pinned;
        _upsert(n);
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kNoteColors[n.color % kNoteColors.length],
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    n.title.isEmpty ? 'Untitled' : n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: kText, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                if (n.pinned) const Icon(Icons.push_pin_rounded, color: kGold, size: 16),
              ],
            ),
            if (n.body.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(n.body,
                  maxLines: 7,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFD0D6E4), fontSize: 13.5, height: 1.4)),
            ],
            const SizedBox(height: 12),
            Text(formatDate(n.updated), style: const TextStyle(color: kMuted, fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

class EditorPage extends StatefulWidget {
  final Note? note;
  final void Function(Note) onSave;
  final void Function(String) onDelete;

  const EditorPage({super.key, this.note, required this.onSave, required this.onDelete});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _body;
  late int _color;
  late bool _pinned;
  late final String _id;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _id = n?.id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _title = TextEditingController(text: n?.title ?? '');
    _body = TextEditingController(text: n?.body ?? '');
    _color = n?.color ?? 0;
    _pinned = n?.pinned ?? false;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  void _saveAndExit() {
    final t = _title.text.trim();
    final b = _body.text.trim();
    if (t.isNotEmpty || b.isNotEmpty) {
      widget.onSave(Note(
        id: _id,
        title: t,
        body: b,
        color: _color,
        pinned: _pinned,
        updated: DateTime.now().millisecondsSinceEpoch,
      ));
    } else if (widget.note != null) {
      widget.onDelete(_id);
    }
    Navigator.of(context).pop();
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF12203D),
        title: const Text('Delete note?'),
        content: const Text('Ye note hamesha ke liye delete ho jayega.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok == true) {
      widget.onDelete(_id);
      if (mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _saveAndExit();
      },
      child: Scaffold(
        backgroundColor: Color.lerp(kBg, kNoteColors[_color], 0.55),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _saveAndExit,
          ),
          actions: [
            IconButton(
              icon: Icon(_pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: _pinned ? kGold : kText),
              onPressed: () => setState(() => _pinned = !_pinned),
            ),
            if (widget.note != null)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: _confirmDelete,
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  cursorColor: kGold,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: kText, fontSize: 26, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: 'Title',
                    hintStyle: TextStyle(color: kMuted),
                    border: InputBorder.none,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _body,
                    cursorColor: kGold,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(color: Color(0xFFE3E8F3), fontSize: 16, height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'Yahan likhna shuru karein...',
                      hintStyle: TextStyle(color: kMuted),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(kNoteColors.length, (i) {
                      final sel = i == _color;
                      return GestureDetector(
                        onTap: () => setState(() => _color = i),
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: kNoteColors[i],
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? kGold : Colors.white24,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: sel ? const Icon(Icons.check_rounded, color: kGold, size: 18) : null,
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
