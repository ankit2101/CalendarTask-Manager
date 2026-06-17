import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import '../core/theme/catppuccin_mocha.dart';
import '../core/constants.dart';
import '../core/time_utils.dart';
import '../models/account.dart';
import '../models/calendar_event.dart';
import '../providers/app_providers.dart';
import '../services/ai/whisper_service.dart';
import '../services/recording/recording_service.dart';
import '../widgets/quick_note_dialog.dart';
import '../widgets/timezone_picker_dialog.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  DateTime _selectedDate = DateTime.now();
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    try {
      await ref.read(eventsProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  String _eventStatus(NormalizedEvent event, Map<String, Map<String, String>> overrides) {
    final now = DateTime.now();
    final ov = overrides[event.id];
    final start = ov != null ? parseToLocal(ov['start']!) : parseToLocal(event.start);
    final end = ov != null ? parseToLocal(ov['end']!) : parseToLocal(event.end);
    if (now.isAfter(end)) return 'past';
    if (now.isAfter(start)) return 'active';
    return 'upcoming';
  }

  @override
  Widget build(BuildContext context) {
    final eventsAsync = ref.watch(eventsProvider);
    final history = ref.watch(meetingHistoryProvider);
    final notedEventIds = history.map((r) => r.eventId).toSet();
    final dismissedIds = ref.watch(dismissedMeetingsProvider);
    final tzOverrides = ref.watch(eventTimeOverridesProvider);
    final today = _startOfDay(DateTime.now());
    final isToday = _isSameDay(_selectedDate, today);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: CatppuccinMocha.overlay0),
                          onPressed: () => setState(() {
                            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
                          }),
                        ),
                        Text(
                          isToday ? 'Today' : DateFormat('EEEE').format(_selectedDate),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: CatppuccinMocha.text),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: CatppuccinMocha.overlay0),
                          onPressed: () => setState(() {
                            _selectedDate = _selectedDate.add(const Duration(days: 1));
                          }),
                        ),
                      ],
                    ),
                    Text(
                      DateFormat('EEEE, MMMM d').format(_selectedDate),
                      style: const TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
                    ),
                  ],
                ),
              ),
              if (!isToday)
                TextButton(
                  onPressed: () => setState(() => _selectedDate = today),
                  child: const Text('Today'),
                ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isRefreshing ? null : _refresh,
                icon: _isRefreshing
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Events list
          Expanded(
            child: eventsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CatppuccinMocha.red.withValues(alpha: 0.1),
                    border: Border.all(color: CatppuccinMocha.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('$e', style: const TextStyle(color: CatppuccinMocha.red)),
                ),
              ),
              data: (events) {
                final dayEvents = events.where((e) {
                  final ov = tzOverrides[e.id];
                  final start = ov != null ? parseToLocal(ov['start']!) : parseToLocal(e.start);
                  return _isSameDay(start, _selectedDate) && !isLeaveEvent(e.title);
                }).toList()
                  ..sort((a, b) {
                    final aOv = tzOverrides[a.id];
                    final bOv = tzOverrides[b.id];
                    final aStart = aOv != null ? parseToLocal(aOv['start']!) : parseToLocal(a.start);
                    final bStart = bOv != null ? parseToLocal(bOv['start']!) : parseToLocal(b.start);
                    return aStart.compareTo(bStart);
                  });

                final now = DateTime.now();
                final missingCount = dayEvents.where((e) {
                  final ov = tzOverrides[e.id];
                  final end = ov != null ? parseToLocal(ov['end']!) : parseToLocal(e.end);
                  return !e.isPrivate &&
                      end.isBefore(now) &&
                      !notedEventIds.contains(e.id) &&
                      !dismissedIds.contains(e.id);
                }).length;

                if (dayEvents.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('No meetings on this day.', style: TextStyle(color: CatppuccinMocha.overlay0)),
                        if (events.isEmpty)
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'Add calendar accounts in the Accounts tab to see your events.',
                              style: TextStyle(fontSize: 13, color: CatppuccinMocha.overlay0),
                            ),
                          ),
                      ],
                    ),
                  );
                }

                return ListView(
                  children: [
                    if (missingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: CatppuccinMocha.yellow.withValues(alpha: 0.1),
                          border: Border.all(color: CatppuccinMocha.yellow.withValues(alpha: 0.25)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$missingCount meeting${missingCount != 1 ? 's' : ''} need${missingCount == 1 ? 's' : ''} notes',
                          style: const TextStyle(color: CatppuccinMocha.yellow, fontSize: 13),
                        ),
                      ),
                    ...dayEvents.map((event) {
                      final ov = tzOverrides[event.id];
                      final end = ov != null ? parseToLocal(ov['end']!) : parseToLocal(event.end);
                      return _EventCard(
                      event: event,
                      status: _eventStatus(event, tzOverrides),
                      hasNote: notedEventIds.contains(event.id),
                      isMissing: end.isBefore(now) &&
                          !notedEventIds.contains(event.id) &&
                          !dismissedIds.contains(event.id),
                      isDismissed: dismissedIds.contains(event.id),
                      );
                    }),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends ConsumerStatefulWidget {
  final NormalizedEvent event;
  final String status;
  final bool hasNote;
  final bool isMissing;
  final bool isDismissed;

  const _EventCard({
    required this.event,
    required this.status,
    required this.hasNote,
    required this.isMissing,
    required this.isDismissed,
  });

  @override
  ConsumerState<_EventCard> createState() => _EventCardState();
}

class _EventCardState extends ConsumerState<_EventCard> {
  // Local recording state (recording this specific card)
  bool _isRecording = false;
  bool _isTranscribing = false;

  bool get _isWithin30Min {
    try {
      final start = DateTime.parse(widget.event.start).toLocal();
      final diff = start.difference(DateTime.now());
      return diff.inMinutes <= 30 && diff.inMinutes >= 0;
    } catch (_) { return false; }
  }

  Future<void> _toggleRecording(BuildContext context) async {
    final activeId = ref.read(activeRecordingEventIdProvider);

    if (_isRecording) {
      // Stop recording
      setState(() { _isRecording = false; _isTranscribing = true; });
      ref.read(activeRecordingEventIdProvider.notifier).state = null;
      try {
        final wavPath = await RecordingService.instance.stopRecording();
        if (wavPath.isEmpty) { setState(() => _isTranscribing = false); return; }

        final settings = ref.read(settingsProvider);
        final model = WhisperModel.fromId(settings.whisperModelId);
        final transcript = await WhisperService.instance.transcribeFile(wavPath: wavPath, model: model);

        if (!settings.keepAudioFiles) {
          try { await File(wavPath).delete(); } catch (_) {}
        }

        setState(() => _isTranscribing = false);
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (_) => QuickNoteDialog(
            event: widget.event,
            initialTranscription: transcript.isNotEmpty ? transcript : null,
          ),
        );
      } catch (e) {
        setState(() => _isTranscribing = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recording error: $e')));
        }
      }
      return;
    }

    // Don't allow two events to record at once
    if (activeId != null && activeId != widget.event.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Another meeting is already being recorded.')),
      );
      return;
    }

    // Ensure a Whisper model is ready before we commit to recording
    final settings = ref.read(settingsProvider);
    final model = WhisperModel.fromId(settings.whisperModelId);
    if (!await WhisperService.instance.isModelDownloaded(model)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No Whisper model downloaded. Go to Settings → Recording and download a model first.'),
          duration: Duration(seconds: 5),
        ));
      }
      return;
    }

    final svc = RecordingService.instance;
    final perm = await svc.getMicrophonePermission();
    if (perm == 'denied') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Microphone access denied. Enable it in System Settings > Privacy > Microphone.'),
        ));
      }
      return;
    }
    if (perm == 'notDetermined') {
      final granted = await svc.requestMicrophonePermission();
      if (!granted) return;
    }

    try {
      final mode = settings.audioCaptureModeStr;
      await svc.startRecording(mode);
      ref.read(activeRecordingEventIdProvider.notifier).state = widget.event.id;
      setState(() => _isRecording = true);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start recording: $e')));
      }
    }
  }

  Widget _buildTimeDisplay(
    DateFormat timeFormat,
    DateTime Function() resolveStart,
    DateTime Function() resolveEnd,
    Map<String, String>? ov,
  ) {
    final sysStart = resolveStart();
    final sysEnd = resolveEnd();
    final sysAbbr = sysStart.timeZoneName;
    final sysLine = '${timeFormat.format(sysStart)} \u2013 ${timeFormat.format(sysEnd)} $sysAbbr';

    // Show source tz line only when there is no user override and the event has a source tz
    String? srcLine;
    if (ov == null && widget.event.timeZone != null) {
      try {
        // Strip surrounding quotes that some ICS producers add (e.g. Outlook)
        final cleanTz = widget.event.timeZone!.trim().replaceAll('"', '');
        final ianaId = windowsToIana[cleanTz] ?? cleanTz;
        final location = tz.getLocation(ianaId);
        final utcStart = DateTime.parse(widget.event.start);
        final utcEnd = DateTime.parse(widget.event.end);
        final srcStart = tz.TZDateTime.from(utcStart, location);
        final srcEnd = tz.TZDateTime.from(utcEnd, location);
        final srcAbbr = srcStart.timeZoneName;
        if (srcAbbr != sysAbbr) {
          srcLine = '${timeFormat.format(srcStart)} \u2013 ${timeFormat.format(srcEnd)} $srcAbbr';
        }
      } catch (_) {
        // unrecognized tz — skip source line
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (srcLine != null)
          Text(
            srcLine,
            style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 11),
          ),
        Text(
          sysLine,
          style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13),
        ),
      ],
    );
  }

  static const _statusColors = {
    'past': CatppuccinMocha.overlay0,
    'active': CatppuccinMocha.green,
    'upcoming': CatppuccinMocha.text,
  };

  static const _statusDots = {'past': '\u25CB', 'active': '\u25CF', 'upcoming': '\u25CC'};

  Widget _buildRecordButton(BuildContext context) {
    if (_isTranscribing) {
      return const Tooltip(
        message: 'Transcribing…',
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: CatppuccinMocha.teal)),
      );
    }
    return Tooltip(
      message: _isRecording ? 'Stop recording' : 'Record meeting',
      child: InkWell(
        onTap: () => _toggleRecording(context),
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (_isRecording ? CatppuccinMocha.red : CatppuccinMocha.surface1).withValues(alpha: _isRecording ? 0.15 : 1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: (_isRecording ? CatppuccinMocha.red : CatppuccinMocha.overlay0).withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isRecording)
                _PulsingRecordDot()
              else
                const Icon(Icons.mic_outlined, size: 13, color: CatppuccinMocha.overlay0),
              const SizedBox(width: 4),
              Text(
                _isRecording ? 'Stop' : 'Record',
                style: TextStyle(fontSize: 12, color: _isRecording ? CatppuccinMocha.red : CatppuccinMocha.overlay0),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Aliases for the widget's immutable fields so existing build code is unchanged
    final event = widget.event;
    final status = widget.status;
    final hasNote = widget.hasNote;
    final isMissing = widget.isMissing;
    final isDismissed = widget.isDismissed;

    final accounts = ref.watch(accountsProvider);
    final account = accounts.firstWhere(
      (a) => a.id == event.accountId,
      orElse: () => CalendarAccount(
        id: event.accountId,
        email: '',
        displayName: event.provider.name.toUpperCase(),
        provider: event.provider.name,
      ),
    );
    final calColor = event.isPrivate
        ? CatppuccinMocha.overlay0
        : accountColor(event.accountId, customHex: account.color);
    final borderColor = event.isPrivate
        ? CatppuccinMocha.overlay0.withValues(alpha: 0.4)
        : isMissing ? CatppuccinMocha.yellow : calColor;
    final timeFormat = DateFormat('h:mm a');
    final overrides = ref.watch(eventTimeOverridesProvider);
    final ov = overrides[event.id];
    DateTime resolveStart() => ov != null ? parseToLocal(ov['start']!) : parseToLocal(event.start);
    DateTime resolveEnd() => ov != null ? parseToLocal(ov['end']!) : parseToLocal(event.end);

    return Opacity(
      opacity: event.isPrivate ? 0.55 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: CatppuccinMocha.surface0,
          borderRadius: BorderRadius.circular(8),
          border: Border(left: BorderSide(color: borderColor, width: 4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                if (event.isPrivate)
                  const Icon(Icons.lock_outline, size: 13, color: CatppuccinMocha.overlay0)
                else
                  Text(
                    _statusDots[status]!,
                    style: TextStyle(color: _statusColors[status], fontSize: 12),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: event.isPrivate ? CatppuccinMocha.overlay0 : CatppuccinMocha.text,
                      fontStyle: event.isPrivate ? FontStyle.italic : FontStyle.normal,
                    ),
                  ),
                ),
                if (!event.isPrivate && isMissing)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: CatppuccinMocha.yellow.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NOTE MISSING',
                      style: TextStyle(color: CatppuccinMocha.yellow, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  ),
                const SizedBox(width: 6),
                if (event.isPrivate)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: CatppuccinMocha.overlay0.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: CatppuccinMocha.overlay0.withValues(alpha: 0.3)),
                    ),
                    child: const Text(
                      'PRIVATE',
                      style: TextStyle(color: CatppuccinMocha.overlay0, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                    ),
                  )
                else
                  Container(
                    constraints: const BoxConstraints(maxWidth: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: calColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: calColor.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(right: 4),
                          decoration: BoxDecoration(
                            color: calColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Flexible(
                          child: Text(
                            account.displayName,
                            style: TextStyle(
                              color: calColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),

            // Time row
            Row(
              children: [
                _buildTimeDisplay(timeFormat, resolveStart, resolveEnd, ov),
                if (ov != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: CatppuccinMocha.peach.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: CatppuccinMocha.peach.withValues(alpha: 0.4)),
                    ),
                    child: const Text(
                      'edited',
                      style: TextStyle(color: CatppuccinMocha.peach, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                if (!event.isPrivate) ...[
                  if (event.attendees.length > 1)
                    Text(
                      ' \u00B7 ${event.attendees.length} attendees',
                      style: const TextStyle(color: CatppuccinMocha.subtext0, fontSize: 13),
                    ),
                  if (event.isOnlineMeeting)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: CatppuccinMocha.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Online', style: TextStyle(color: CatppuccinMocha.blue, fontSize: 11)),
                    ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: () async {
                    final result = await showTimeEditDialog(
                        context, resolveStart(), resolveEnd());
                    if (result == null) return;
                    ref.read(eventTimeOverridesProvider.notifier)
                        .setOverride(event.id, result.start, result.end);
                  },
                  child: Tooltip(
                    message: ov != null ? 'Edit time (custom)' : 'Edit time',
                    child: Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: ov != null ? CatppuccinMocha.peach : CatppuccinMocha.overlay0,
                    ),
                  ),
                ),
                if (ov != null) ...[
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => ref.read(eventTimeOverridesProvider.notifier).clearOverride(event.id),
                    child: const Tooltip(
                      message: 'Reset to original time',
                      child: Icon(Icons.refresh, size: 14, color: CatppuccinMocha.overlay0),
                    ),
                  ),
                ],
              ],
            ),

            if (!event.isPrivate && event.location != null) ...[
              const SizedBox(height: 4),
              Text(
                event.location!,
                style: const TextStyle(color: CatppuccinMocha.overlay0, fontSize: 12),
              ),
            ],

            // Note action row — hidden for private/dismissed events, shown for active & past
            if (!event.isPrivate && !isDismissed && (status == 'past' || status == 'active')) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == 'active')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: CatppuccinMocha.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: CatppuccinMocha.green.withValues(alpha: 0.3)),
                      ),
                      child: const Text(
                        'IN PROGRESS',
                        style: TextStyle(color: CatppuccinMocha.green, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ),
                  if (hasNote)
                    const Text('\u2713 Note saved', style: TextStyle(color: CatppuccinMocha.green, fontSize: 12))
                  else ...[
                    if (status == 'past') ...[
                      IconButton(
                        icon: const Icon(Icons.close, size: 14),
                        color: CatppuccinMocha.overlay0,
                        tooltip: 'Dismiss reminder',
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        onPressed: () =>
                            ref.read(dismissedMeetingsProvider.notifier).dismiss(event.id),
                      ),
                      const SizedBox(width: 8),
                    ],
                    OutlinedButton(
                      onPressed: () => showDialog(
                        context: context,
                        builder: (_) => QuickNoteDialog(event: event),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: (status == 'active' ? CatppuccinMocha.green : CatppuccinMocha.yellow).withValues(alpha: 0.4)),
                        foregroundColor: status == 'active' ? CatppuccinMocha.green : CatppuccinMocha.yellow,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        minimumSize: Size.zero,
                        textStyle: const TextStyle(fontSize: 12),
                      ),
                      child: Text(status == 'active' ? '+ Live Notes' : '+ Add Notes'),
                    ),
                  ],
                  // Record button \u2014 active and upcoming meetings
                  if (status == 'active' || status == 'upcoming') ...[
                    const SizedBox(width: 8),
                    _buildRecordButton(context),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// \u2500\u2500\u2500 Pulsing dot for dashboard record button \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

class _PulsingRecordDot extends StatefulWidget {
  @override
  State<_PulsingRecordDot> createState() => _PulsingRecordDotState();
}

class _PulsingRecordDotState extends State<_PulsingRecordDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _ctrl,
    builder: (_, __) => Container(
      width: 8, height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: CatppuccinMocha.red.withValues(alpha: 0.4 + _ctrl.value * 0.6),
      ),
    ),
  );
}
