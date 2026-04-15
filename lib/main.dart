// ============================================================
//  OBJECT JOURNAL — single file version
//  Paste this entire file into lib/main.dart
//  Only dependency needed: flutter_riverpod: ^2.4.0
// ============================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════

class DetectionEvent {
  final String label;
  final DateTime timestamp;

  const DetectionEvent({required this.label, required this.timestamp});

  String get normalisedLabel => label.trim().toLowerCase();
}

class DailySummary {
  final DateTime date;
  final Map<String, int> objectCounts;

  const DailySummary({required this.date, required this.objectCounts});

  int get totalObjects => objectCounts.values.fold(0, (s, c) => s + c);

  List<MapEntry<String, int>> get sortedEntries =>
      objectCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

  static String dateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

// ════════════════════════════════════════════════════════════
//  CONTROLLER (pure Dart, no Flutter dependency)
// ════════════════════════════════════════════════════════════

class JournalController {
  final List<DetectionEvent> _events = [];
  final Map<String, DailySummary> _summaries = {};
  final StreamController<List<DailySummary>> _streamController =
      StreamController<List<DailySummary>>.broadcast();

  Stream<List<DailySummary>> get summariesStream => _streamController.stream;

  StreamSubscription<DetectionEvent>? _externalSub;

  // ── Integration point A: direct call ──
  void addDetection(DetectionEvent event) {
    _events.add(event);
    _recompute(DailySummary.dateKey(event.timestamp));
    _emit();
  }

  // ── Integration point B: stream subscription ──
  void subscribeToStream(Stream<DetectionEvent> stream) {
    _externalSub?.cancel();
    _externalSub = stream.listen(addDetection);
  }

  // ── Integration point C: bulk restore ──
  void addDetections(List<DetectionEvent> events) {
    if (events.isEmpty) return;
    _events.addAll(events);
    final keys = events.map((e) => DailySummary.dateKey(e.timestamp)).toSet();
    for (final k in keys) _recompute(k);
    _emit();
  }

  List<DailySummary> get summaries =>
      _summaries.values.toList()..sort((a, b) => b.date.compareTo(a.date));

  void _recompute(String key) {
    final dayEvents =
        _events.where((e) => DailySummary.dateKey(e.timestamp) == key).toList();
    if (dayEvents.isEmpty) { _summaries.remove(key); return; }
    final counts = <String, int>{};
    for (final e in dayEvents) {
      counts[e.normalisedLabel] = (counts[e.normalisedLabel] ?? 0) + 1;
    }
    _summaries[key] = DailySummary(date: dayEvents.first.timestamp, objectCounts: counts);
  }

  void _emit() {
    if (!_streamController.isClosed) _streamController.add(summaries);
  }

  void dispose() {
    _externalSub?.cancel();
    _streamController.close();
  }
}

// ════════════════════════════════════════════════════════════
//  RIVERPOD STATE
// ════════════════════════════════════════════════════════════

class JournalNotifier extends StateNotifier<List<DailySummary>> {
  JournalNotifier() : super([]);

  final JournalController _controller = JournalController();
  StreamSubscription<List<DailySummary>>? _sub;

  void init() {
    _sub = _controller.summariesStream.listen((s) => state = s);
  }

  void addDetection(DetectionEvent event) => _controller.addDetection(event);
  void addDetections(List<DetectionEvent> events) => _controller.addDetections(events);
  void subscribeToDetectionStream(Stream<DetectionEvent> stream) =>
      _controller.subscribeToStream(stream);

  @override
  void dispose() {
    _sub?.cancel();
    _controller.dispose();
    super.dispose();
  }
}

final journalProvider =
    StateNotifierProvider<JournalNotifier, List<DailySummary>>(
  (ref) => JournalNotifier()..init(),
);

// ════════════════════════════════════════════════════════════
//  THEME
// ════════════════════════════════════════════════════════════

class T {
  static const bg         = Color(0xFF0D0F1A);
  static const surface    = Color(0xFF171B2E);
  static const surfaceHi  = Color(0xFF1E2340);
  static const accent     = Color(0xFF7C5CFC);
  static const accentSoft = Color(0xFF9B7FFF);
  static const textPri    = Color(0xFFEEEEF5);
  static const textSec    = Color(0xFF7A7D9C);
  static const divider    = Color(0xFF252849);
}

// ════════════════════════════════════════════════════════════
//  APP ENTRY
// ════════════════════════════════════════════════════════════

void main() {
  runApp(const ProviderScope(child: _App()));
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Journal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: T.bg,
        colorScheme: const ColorScheme.dark(surface: T.surface, primary: T.accent),
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
      ),
      home: const _JournalScreen(),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  JOURNAL SCREEN
// ════════════════════════════════════════════════════════════

class _JournalScreen extends ConsumerWidget {
  const _JournalScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(journalProvider);

    return Scaffold(
      backgroundColor: T.bg,
 

         //floating action button
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Object Journal',
                          style: TextStyle(
                              color: T.textPri,
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5)),
                      const SizedBox(height: 2),
                      Text('Daily detection history',
                          style: TextStyle(color: T.textSec, fontSize: 13)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                        color: T.surface, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.book_outlined, color: T.accent, size: 22),
                  ),
                ],
              ),
            ),

            // List or empty state
            Expanded(
              child: summaries.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: summaries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _DayCard(summary: summaries[i]),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  DAY CARD
// ════════════════════════════════════════════════════════════

class _DayCard extends StatelessWidget {
  final DailySummary summary;
  const _DayCard({required this.summary});

  static const _months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final previewLabels =
        summary.sortedEntries.take(3).map((e) => _cap(e.key)).join(', ');
    final extra = summary.objectCounts.length - 3;

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => _DetailSheet(summary: summary),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: T.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: T.divider),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            // Date badge
            Container(
              width: 48, height: 52,
              decoration: BoxDecoration(
                color: T.accent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(_months[summary.date.month - 1].toUpperCase(),
                      style: const TextStyle(
                          color: T.accent, fontSize: 10,
                          fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  Text('${summary.date.day}',
                      style: const TextStyle(
                          color: T.textPri, fontSize: 20,
                          fontWeight: FontWeight.w800, height: 1.1)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${summary.totalObjects} object${summary.totalObjects == 1 ? '' : 's'} detected',
                    style: const TextStyle(
                        color: T.textPri, fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: TextStyle(color: T.textSec, fontSize: 12.5),
                      children: [
                        TextSpan(text: previewLabels),
                        if (extra > 0)
                          TextSpan(
                              text: ' +$extra more',
                              style: const TextStyle(color: T.accentSoft)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: T.textSec, size: 20),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  DETAIL BOTTOM SHEET
// ════════════════════════════════════════════════════════════

class _DetailSheet extends StatelessWidget {
  final DailySummary summary;
  const _DetailSheet({required this.summary});

  static const _months = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  @override
  Widget build(BuildContext context) {
    final entries = summary.sortedEntries;

    return Container(
      decoration: const BoxDecoration(
        color: T.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: T.divider),
          left: BorderSide(color: T.divider),
          right: BorderSide(color: T.divider),
        ),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: T.divider, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.arrow_back_ios_new,
                      color: T.textSec, size: 18),
                ),
                Text(
                  '${_months[summary.date.month - 1]} ${summary.date.day}, ${summary.date.year}',
                  style: const TextStyle(
                      color: T.textPri, fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Total banner
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                  color: T.surfaceHi, borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Total Objects Seen',
                      style: TextStyle(color: T.textSec, fontSize: 13.5,
                          fontWeight: FontWeight.w500)),
                  Text('${summary.totalObjects}',
                      style: const TextStyle(
                          color: T.textPri, fontSize: 18, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Divider(color: T.divider, height: 1),
          ),
          const SizedBox(height: 12),
          // Dynamic object list — 100% driven by real data
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: entries.length,
              itemBuilder: (_, i) {
                final e = entries[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == 0 ? T.accent : T.textSec,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(_cap(e.key),
                            style: TextStyle(
                                color: T.textPri, fontSize: 15,
                                fontWeight: i == 0
                                    ? FontWeight.w600
                                    : FontWeight.w400)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: i == 0
                              ? T.accent.withOpacity(0.2)
                              : T.surfaceHi,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('${e.value}',
                            style: TextStyle(
                                color: i == 0 ? T.accentSoft : T.textSec,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Close button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: T.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text('Close',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════
//  EMPTY STATE
// ════════════════════════════════════════════════════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: T.surface,
                shape: BoxShape.circle,
                border: Border.all(color: T.divider, width: 1.5),
              ),
              child: const Icon(Icons.sensors_off_outlined,
                  size: 36, color: T.textSec),
            ),
            const SizedBox(height: 24),
            const Text('No detections yet',
                style: TextStyle(
                    color: T.textPri, fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              'The journal will populate automatically\nwhen the detection system sends data.',
              textAlign: TextAlign.center,
              style: TextStyle(color: T.textSec, fontSize: 13.5, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}