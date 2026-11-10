import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../kit/kit_service.dart';

/// Where a student is in a lab. Saved on the phone so they can resume.
class LabProgress {
  const LabProgress({this.step = 0, this.readings = const {}, this.autoOff = false});

  final int step;
  final Map<String, double> readings;

  /// True when the app switched the 5 V off because the student left the lab.
  final bool autoOff;

  bool get started => step > 0 || readings.isNotEmpty;

  Map<String, dynamic> toJson() => {'step': step, 'readings': readings, 'autoOff': autoOff};

  static LabProgress fromJson(Map<String, dynamic> j) => LabProgress(
        step: (j['step'] as num?)?.toInt() ?? 0,
        readings: {
          for (final e in ((j['readings'] as Map?) ?? const {}).entries) e.key as String: (e.value as num).toDouble(),
        },
        autoOff: j['autoOff'] == true,
      );
}

/// One saved export. Every export is kept; nothing is overwritten.
class ExportAttempt {
  const ExportAttempt({required this.number, required this.savedAt, required this.sections, required this.compare});

  final int number;
  final DateTime savedAt;
  final List<({String title, List<({String label, String value})> rows})> sections;
  final List<({String label, String calc, String meas, String diff})> compare;

  Map<String, dynamic> toJson() => {
        'number': number,
        'savedAt': savedAt.toIso8601String(),
        'sections': [
          for (final s in sections)
            {
              'title': s.title,
              'rows': [for (final r in s.rows) {'label': r.label, 'value': r.value}],
            }
        ],
        'compare': [
          for (final c in compare) {'label': c.label, 'calc': c.calc, 'meas': c.meas, 'diff': c.diff}
        ],
      };

  static ExportAttempt fromJson(Map<String, dynamic> j) => ExportAttempt(
        number: (j['number'] as num).toInt(),
        savedAt: DateTime.tryParse(j['savedAt'] as String? ?? '') ?? DateTime.now(),
        sections: [
          for (final s in (j['sections'] as List? ?? const []))
            (
              title: (s as Map)['title'] as String,
              rows: [
                for (final r in (s['rows'] as List? ?? const []))
                  (label: (r as Map)['label'] as String, value: r['value'] as String),
              ],
            ),
        ],
        compare: [
          for (final c in (j['compare'] as List? ?? const []))
            (
              label: (c as Map)['label'] as String,
              calc: c['calc'] as String,
              meas: c['meas'] as String,
              diff: c['diff'] as String,
            ),
        ],
      );

  String get dateLabel => formatDate(savedAt);
  String get timeLabel => formatTime(savedAt);

  /// Plain CSV of everything in this attempt, for pasting into a spreadsheet.
  String toCsv(String labTitle) {
    final b = StringBuffer()
      ..writeln('"$labTitle","Export Attempt $number","$dateLabel $timeLabel"')
      ..writeln();
    for (final s in sections) {
      b.writeln('"${s.title}"');
      for (final r in s.rows) {
        b.writeln('"${r.label}","${r.value}"');
      }
      b.writeln();
    }
    if (compare.isNotEmpty) {
      b.writeln('"Calculated vs. measured"');
      b.writeln('"","Calculated","Measured","% difference"');
      for (final c in compare) {
        b.writeln('"${c.label}","${c.calc}","${c.meas}","${c.diff}"');
      }
    }
    return b.toString();
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDate(DateTime d) => '${_months[d.month - 1]} ${d.day}';

String formatTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final m = d.minute.toString().padLeft(2, '0');
  return '$h:$m ${d.hour < 12 ? 'AM' : 'PM'}';
}

/// App-wide state: lab progress, saved exports and the connected kit.
class AppState extends ChangeNotifier {
  AppState(this._prefs, this.kit) {
    _load();
    kit.addListener(notifyListeners); // e.g. the kit card updates after connecting
  }

  final SharedPreferences _prefs;
  final KitService kit;

  final Map<String, LabProgress> _progress = {};
  final Map<String, List<ExportAttempt>> _attempts = {};

  void _load() {
    for (final key in _prefs.getKeys()) {
      try {
        if (key.startsWith('progress.')) {
          _progress[key.substring(9)] = LabProgress.fromJson(jsonDecode(_prefs.getString(key)!) as Map<String, dynamic>);
        } else if (key.startsWith('attempts.')) {
          final list = jsonDecode(_prefs.getString(key)!) as List;
          _attempts[key.substring(9)] = [for (final a in list) ExportAttempt.fromJson(a as Map<String, dynamic>)];
        }
      } catch (_) {
        // Ignore anything unreadable rather than crash on start.
      }
    }
  }

  LabProgress progressFor(String labId) => _progress[labId] ?? const LabProgress();

  List<ExportAttempt> attemptsFor(String labId) => List.unmodifiable(_attempts[labId] ?? const []);

  void saveProgress(String labId, LabProgress p) {
    _progress[labId] = p;
    _prefs.setString('progress.$labId', jsonEncode(p.toJson()));
    notifyListeners();
  }

  void clearProgress(String labId) {
    _progress.remove(labId);
    _prefs.remove('progress.$labId');
    notifyListeners();
  }

  ExportAttempt addAttempt(
    String labId, {
    required List<({String title, List<({String label, String value})> rows})> sections,
    required List<({String label, String calc, String meas, String diff})> compare,
  }) {
    final list = [...(_attempts[labId] ?? const <ExportAttempt>[])];
    final attempt = ExportAttempt(number: list.length + 1, savedAt: DateTime.now(), sections: sections, compare: compare);
    list.add(attempt);
    _attempts[labId] = list;
    _prefs.setString('attempts.$labId', jsonEncode([for (final a in list) a.toJson()]));
    notifyListeners();
    return attempt;
  }
}

/// Makes [AppState] available to every screen: `AppScope.of(context)`.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// Read without rebuilding when state changes (for button handlers).
  static AppState read(BuildContext context) => context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
