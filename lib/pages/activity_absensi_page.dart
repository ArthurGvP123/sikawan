import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';

class ActivityAbsensiPage extends StatefulWidget {
  final String groupId;
  final String meetingId;

  const ActivityAbsensiPage({
    super.key,
    required this.groupId,
    required this.meetingId,
  });

  @override
  State<ActivityAbsensiPage> createState() => _ActivityAbsensiPageState();
}

class _ActivityAbsensiPageState extends State<ActivityAbsensiPage> {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  bool _submitting = false;

  bool _isAdmin(Map<String, dynamic> gdata, String uid) {
    final admins = List<String>.from(gdata['admins'] ?? []);
    return admins.contains(uid);
  }

  Future<void> _doAttendance() async {
    if (_submitting) return;
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    setState(() => _submitting = true);

    try {
      final attRef = _db
          .collection('groups')
          .doc(widget.groupId)
          .collection('meetings')
          .doc(widget.meetingId)
          .collection('attendance')
          .doc(uid);

      final snap = await attRef.get();
      if (!snap.exists) {
        await attRef.set({
          'uid': uid,
          'present': true,
          'at': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Absensi berhasil!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal absensi: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showEditWindowDialog(
    DocumentSnapshot<Map<String, dynamic>> meetingSnap,
  ) async {
    final data = meetingSnap.data() ?? {};
    final startTs = data['attendanceWindowStart'] as Timestamp?;
    final endTs = data['attendanceWindowEnd'] as Timestamp?;

    DateTime start = startTs?.toDate() ?? DateTime.now();
    DateTime end = endTs?.toDate() ?? start.add(const Duration(minutes: 30));

    bool saving = false;
    String? err;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setLocal) {
            Future<void> save() async {
              if (end.isBefore(start)) {
                setLocal(() => err = 'Waktu akhir tidak boleh sebelum mulai.');
                return;
              }

              setLocal(() {
                saving = true;
                err = null;
              });

              try {
                await meetingSnap.reference.set({
                  'attendanceWindowStart': Timestamp.fromDate(start),
                  'attendanceWindowEnd': Timestamp.fromDate(end),
                }, SetOptions(merge: true));

                if (!mounted || !dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
              } catch (e) {
                setLocal(() {
                  err = 'Gagal menyimpan: $e';
                  saving = false;
                });
              }
            }

            Future<void> pickDateStart() async {
              final d = await showDatePicker(
                context: ctx,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: start,
              );
              if (d != null) {
                setLocal(() {
                  start = DateTime(d.year, d.month, d.day, start.hour,
                      start.minute);
                });
              }
            }

            Future<void> pickDateEnd() async {
              final d = await showDatePicker(
                context: ctx,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
                initialDate: end,
              );
              if (d != null) {
                setLocal(() {
                  end = DateTime(d.year, d.month, d.day, end.hour, end.minute);
                });
              }
            }

            Future<void> pickTimeStart() async {
              final t = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(start),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      alwaysUse24HourFormat: true,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
              if (t != null) {
                setLocal(() {
                  start = DateTime(start.year, start.month, start.day, t.hour,
                      t.minute);
                });
              }
            }

            Future<void> pickTimeEnd() async {
              final t = await showTimePicker(
                context: ctx,
                initialTime: TimeOfDay.fromDateTime(end),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(
                      alwaysUse24HourFormat: true,
                    ),
                    child: child ?? const SizedBox.shrink(),
                  );
                },
              );
              if (t != null) {
                setLocal(() {
                  end = DateTime(end.year, end.month, end.day, t.hour, t.minute);
                });
              }
            }

            return AlertDialog(
              backgroundColor: SiKawanTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: const Text('Edit Jadwal Absensi'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _rowBtn(
                    label: 'Tanggal mulai',
                    value: _dateLabel(start),
                    onTap: pickDateStart,
                  ),
                  const SizedBox(height: 8),
                  _rowBtn(
                    label: 'Waktu mulai',
                    value: _timeLabel(start),
                    onTap: pickTimeStart,
                  ),
                  const SizedBox(height: 12),
                  _rowBtn(
                    label: 'Tanggal selesai',
                    value: _dateLabel(end),
                    onTap: pickDateEnd,
                  ),
                  const SizedBox(height: 8),
                  _rowBtn(
                    label: 'Waktu selesai',
                    value: _timeLabel(end),
                    onTap: pickTimeEnd,
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(err!,
                        style: const TextStyle(color: SiKawanTheme.error)),
                  ],
                ],
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

  Widget _rowBtn({
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: SiKawanTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: SiKawanTheme.border),
        ),
        child: Row(
          children: [
            Text(label),
            const Spacer(),
            Text(value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 6),
            const Icon(Icons.edit_outlined, size: 16),
          ],
        ),
      ),
    );
  }

  String _dateLabel(DateTime d) => '${d.day}/${d.month}/${d.year}';
  String _timeLabel(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final uid = _auth.currentUser?.uid;

    if (uid == null) {
      return const Center(child: Text('Tidak ada user login'));
    }

    final meetingRef = _db
        .collection('groups')
        .doc(widget.groupId)
        .collection('meetings')
        .doc(widget.meetingId);

    final groupRef = _db.collection('groups').doc(widget.groupId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: meetingRef.snapshots(),
      builder: (context, meetingSnap) {
        final mdata = meetingSnap.data?.data() ?? {};

        final startTs = mdata['attendanceWindowStart'] as Timestamp?;
        final endTs = mdata['attendanceWindowEnd'] as Timestamp?;
        final start = startTs?.toDate();
        final end = endTs?.toDate();

        final now = DateTime.now();
        final withinWindow = (start != null && end != null)
            ? now.isAfter(start) && now.isBefore(end)
            : false;

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: groupRef.snapshots(),
          builder: (context, groupSnap) {
            final gdata = groupSnap.data?.data() ?? {};
            final isAdmin = _isAdmin(gdata, uid);

            final members = List<String>.from(gdata['members'] ?? []);

            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ABSENSI CARD
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: SiKawanTheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: SiKawanTheme.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Absensi',
                                style: t.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800)),
                            const Spacer(),
                            if (isAdmin && meetingSnap.hasData)
                              TextButton.icon(
                                onPressed: () =>
                                    _showEditWindowDialog(meetingSnap.data!),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                label: const Text('Edit jadwal'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          start == null || end == null
                              ? 'Jadwal belum ditentukan'
                              : 'Buka: ${_dateLabel(start)} ${_timeLabel(start)}  •  Tutup: ${_dateLabel(end)} ${_timeLabel(end)}',
                          style: t.bodySmall?.copyWith(
                            color: SiKawanTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: (!withinWindow && !isAdmin)
                                ? null
                                : _doAttendance,
                            icon: _submitting
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor:
                                          AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.check_circle_outline),
                            label: Text(
                              withinWindow
                                  ? 'Lakukan Absensi'
                                  : (isAdmin
                                      ? 'Absensi ditutup (Admin bisa edit jadwal)'
                                      : 'Absensi sudah ditutup'),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Status Absensi',
                    style:
                        t.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),

                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream:
                          meetingRef.collection('attendance').snapshots(),
                      builder: (context, attSnap) {
                        final attDocs = attSnap.data?.docs ?? [];
                        final presentUids =
                            attDocs.map((d) => d.id).toSet();

                        final hadir =
                            members.where((m) => presentUids.contains(m)).toList();
                        final belum =
                            members.where((m) => !presentUids.contains(m)).toList();

                        return ListView(
                          children: [
                            _sectionTitle('Sudah absensi (${hadir.length})'),
                            ...hadir.map((id) => _UserTile(uid: id, isPresent: true)),
                            const SizedBox(height: 8),
                            _sectionTitle('Belum absensi (${belum.length})'),
                            ...belum.map((id) => _UserTile(uid: id, isPresent: false)),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6),
      child: Text(
        text,
        style:
            const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  final String uid;
  final bool isPresent;
  const _UserTile({required this.uid, required this.isPresent});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final db = FirebaseFirestore.instance;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: db.collection('users').doc(uid).get(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = (data?['name'] ?? uid) as String;
        return Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SiKawanTheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SiKawanTheme.border),
          ),
          child: Row(
            children: [
              Icon(
                isPresent ? Icons.check_circle : Icons.cancel_outlined,
                color: isPresent
                    ? SiKawanTheme.primary
                    : SiKawanTheme.error,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  style: t.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
