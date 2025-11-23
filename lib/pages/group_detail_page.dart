import 'dart:collection';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/group_drawer.dart';
import 'activity_root_page.dart';

class GroupDetailPage extends StatefulWidget {
  final String groupId;
  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  bool _showArchive = false;

  late final LinkedHashMap<DateTime, List<GroupActivity>> _events =
      LinkedHashMap<DateTime, List<GroupActivity>>(
    equals: isSameDay,
    hashCode: _hashCode,
  );

  static int _hashCode(DateTime key) =>
      key.day * 1000000 + key.month * 10000 + key.year;

  List<GroupActivity> _getEventsForDay(DateTime day) {
    final k = DateTime.utc(day.year, day.month, day.day);
    return _events[k] ?? [];
  }

  void _rebuildEvents(List<GroupActivity> items) {
    _events.clear();
    for (final e in items) {
      final d = DateTime.utc(e.date.year, e.date.month, e.date.day);
      final list = _events[d] ?? <GroupActivity>[];
      list.add(e);
      _events[d] = list;
    }
  }

  bool _isAdmin(Map<String, dynamic> data, String uid) {
    final admins = List<String>.from(data['admins'] ?? []);
    return admins.contains(uid);
  }

  bool _isArchived(GroupActivity a) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final activityDayStart = DateTime(a.date.year, a.date.month, a.date.day);
    return activityDayStart.isBefore(todayStart);
  }

  // ======================
  // CREATE MEETING (ADMIN)
  // ======================
  Future<void> _showCreateMeetingDialog(String groupId) async {
    final titleC = TextEditingController();
    final descC = TextEditingController();
    DateTime? selectedDate;
    TimeOfDay? selectedTime; // opsional 24h
    bool saving = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              final title = titleC.text.trim();
              final desc = descC.text.trim();

              if (title.isEmpty) {
                setLocal(() => err = 'Nama kegiatan wajib diisi.');
                return;
              }
              if (selectedDate == null) {
                setLocal(() => err = 'Tanggal wajib dipilih.');
                return;
              }

              setLocal(() {
                saving = true;
                err = null;
              });

              try {
                final hasTime = selectedTime != null;
                final dt = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime?.hour ?? 0,
                  selectedTime?.minute ?? 0,
                );

                await _db
                    .collection('groups')
                    .doc(groupId)
                    .collection('meetings')
                    .add({
                  'title': title,
                  'description': desc,
                  'dateTime': Timestamp.fromDate(dt),
                  'hasTime': hasTime,

                  // default attendance window: dt .. dt+30m
                  'attendanceWindowStart': Timestamp.fromDate(dt),
                  'attendanceWindowEnd':
                      Timestamp.fromDate(dt.add(const Duration(minutes: 30))),

                  'createdBy': _auth.currentUser?.uid,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                if (!mounted || !dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
              } catch (e) {
                setLocal(() {
                  err = 'Gagal membuat kegiatan: $e';
                  saving = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Buat Kegiatan Baru'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleC,
                      decoration: const InputDecoration(
                        labelText: 'Nama kegiatan',
                        prefixIcon: Icon(Icons.event_note_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descC,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Deskripsi singkat (opsional)',
                        prefixIcon: Icon(Icons.notes_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_outlined),
                      label: Text(selectedDate == null
                          ? 'Pilih tanggal *'
                          : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}'),
                      onPressed: () async {
                        final d = await showDatePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDate: DateTime.now(),
                        );
                        if (d != null) setLocal(() => selectedDate = d);
                      },
                    ),
                    const SizedBox(height: 8),

                    OutlinedButton.icon(
                      icon: const Icon(Icons.access_time_outlined),
                      label: Text(
                        selectedTime == null
                            ? 'Pilih waktu (opsional)'
                            : selectedTime!.format(context),
                      ),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                          builder: (context, child) {
                            return MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                alwaysUse24HourFormat: true,
                              ),
                              child: child ?? const SizedBox.shrink(),
                            );
                          },
                        );
                        if (picked != null) {
                          setLocal(() => selectedTime = picked);
                        }
                      },
                    ),

                    if (selectedTime != null) ...[
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => setLocal(() => selectedTime = null),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('Hapus waktu'),
                        ),
                      ),
                    ],

                    if (err != null) ...[
                      const SizedBox(height: 10),
                      Text(err!,
                          style: const TextStyle(color: SiKawanTheme.error)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogCtx),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: saving ? null : save,
                  child: saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEventsSheet(DateTime day, List<GroupActivity> events) {
    if (events.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: SiKawanTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 4,
                  width: 48,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: SiKawanTheme.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Text(
                  'Kegiatan ${day.day}/${day.month}/${day.year}',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 10),
                ...events.map((e) {
                  final archived = _isArchived(e);
                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SiKawanTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SiKawanTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                e.title,
                                style: t.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (archived)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: SiKawanTheme.border,
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Text(
                                  'Arsip',
                                  style: t.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: SiKawanTheme.textSecondary,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          e.timeLabel,
                          style: t.bodySmall?.copyWith(
                            color: SiKawanTheme.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (e.desc.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            e.desc,
                            style: t.bodySmall?.copyWith(
                              color: SiKawanTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final myUid = _auth.currentUser?.uid;

    return Scaffold(
      drawer: GroupDrawer(groupId: widget.groupId, current: 'kegiatan'),
      appBar: AppBar(
        title: const Text('Kegiatan'),
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
      ),

      floatingActionButton: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _db.collection('groups').doc(widget.groupId).snapshots(),
        builder: (context, snap) {
          final gdata = snap.data?.data() ?? {};
          final isAdmin = myUid != null ? _isAdmin(gdata, myUid) : false;

          if (!isAdmin) return const SizedBox.shrink();

          return Container(
            height: 58,
            width: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [SiKawanTheme.primary, SiKawanTheme.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'addMeetingFab',
              onPressed: () => _showCreateMeetingDialog(widget.groupId),
              backgroundColor: Colors.transparent,
              elevation: 0,
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          );
        },
      ),

      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _db
              .collection('groups')
              .doc(widget.groupId)
              .collection('meetings')
              .orderBy('dateTime', descending: false)
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snap.data!.docs;

            final activities = docs.map((d) {
              final m = d.data();
              final ts = (m['dateTime'] ?? m['date']) as Timestamp?;
              final date = ts?.toDate() ?? DateTime.now();

              final title = (m['title'] ?? 'Kegiatan') as String;
              final desc = (m['description'] ?? '') as String;
              final hasTime = (m['hasTime'] ?? true) as bool;
              final timeLabel = _timeLabelFromDate(date, hasTime);

              return GroupActivity(
                id: d.id,
                title: title,
                desc: desc,
                date: date,
                hasTime: hasTime,
                timeLabel: timeLabel,
              );
            }).toList();

            _rebuildEvents(activities);

            final upcoming =
                activities.where((a) => !_isArchived(a)).toList();
            final archived =
                activities.where((a) => _isArchived(a)).toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
              children: [
                SizedBox(
                  height: 360,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: SiKawanTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SiKawanTheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: TableCalendar<GroupActivity>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2100, 12, 31),
                      focusedDay: _focusedDay,
                      selectedDayPredicate: (day) =>
                          isSameDay(_selectedDay, day),
                      onDaySelected: (selectedDay, focusedDay) {
                        setState(() {
                          _selectedDay = selectedDay;
                          _focusedDay = focusedDay;
                        });

                        final ev = _getEventsForDay(selectedDay);
                        _showEventsSheet(selectedDay, ev);
                      },
                      onPageChanged: (focusedDay) {
                        _focusedDay = focusedDay;
                      },
                      eventLoader: _getEventsForDay,
                      rowHeight: 38,
                      daysOfWeekHeight: 22,
                      headerStyle: HeaderStyle(
                        titleCentered: true,
                        formatButtonVisible: false,
                        headerPadding:
                            const EdgeInsets.symmetric(vertical: 4),
                        titleTextStyle: t.titleMedium!.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        leftChevronIcon:
                            const Icon(Icons.chevron_left_rounded),
                        rightChevronIcon:
                            const Icon(Icons.chevron_right_rounded),
                      ),
                      calendarStyle: CalendarStyle(
                        todayDecoration: BoxDecoration(
                          color:
                              SiKawanTheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        selectedDecoration: const BoxDecoration(
                          color: SiKawanTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: const BoxDecoration(
                          color: SiKawanTheme.secondary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 1,
                        markerSize: 6,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Kegiatan Mendatang',
                  style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),

                if (upcoming.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 18, bottom: 8),
                      child: Text(
                        'Tidak ada kegiatan mendatang.',
                        style: t.bodyMedium?.copyWith(
                          color: SiKawanTheme.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...upcoming.map((a) => _ActivityCard(
                        a: a,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityRootPage(
                              groupId: widget.groupId,
                              meetingId: a.id,
                              meetingTitle: a.title,
                            ),
                          ),
                        ),
                      )),

                const SizedBox(height: 12),

                if (archived.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: SiKawanTheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: SiKawanTheme.border),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () =>
                          setState(() => _showArchive = !_showArchive),
                      child: Row(
                        children: [
                          Icon(
                            _showArchive
                                ? Icons.keyboard_arrow_down_rounded
                                : Icons.keyboard_arrow_right_rounded,
                            color: SiKawanTheme.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Arsip Kegiatan (${archived.length})',
                            style: t.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _showArchive ? 'Sembunyikan' : 'Tampilkan',
                            style: t.bodySmall?.copyWith(
                              color: SiKawanTheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_showArchive) ...[
                  const SizedBox(height: 8),
                  ...archived.map((a) => _ActivityCard(
                        a: a,
                        archived: true,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ActivityRootPage(
                              groupId: widget.groupId,
                              meetingId: a.id,
                              meetingTitle: a.title,
                            ),
                          ),
                        ),
                      )),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  static String _timeLabelFromDate(DateTime dt, bool hasTime) {
    if (!hasTime) return 'Tanpa waktu';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m WIB';
  }
}

class GroupActivity {
  final String id;
  final String title;
  final String desc;
  final DateTime date;
  final bool hasTime;
  final String timeLabel;

  GroupActivity({
    required this.id,
    required this.title,
    required this.desc,
    required this.date,
    required this.hasTime,
    required this.timeLabel,
  });
}

class _ActivityCard extends StatelessWidget {
  final GroupActivity a;
  final bool archived;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.a,
    required this.onTap,
    this.archived = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final d = a.date;
    final dateText = '${d.day}/${d.month}/${d.year}';
    final metaText = a.hasTime ? '$dateText • ${a.timeLabel}' : dateText;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: SiKawanTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: SiKawanTheme.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: archived
                    ? SiKawanTheme.border
                    : SiKawanTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${d.day}',
                style: t.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: archived
                      ? SiKawanTheme.textSecondary
                      : SiKawanTheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.title,
                    style: t.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metaText,
                    style: t.bodySmall?.copyWith(
                      color: SiKawanTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (a.desc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      a.desc,
                      style: t.bodySmall?.copyWith(
                        color: SiKawanTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: SiKawanTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}
