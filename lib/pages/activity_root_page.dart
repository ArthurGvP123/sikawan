import 'package:flutter/material.dart';

import '../theme/sikawan_theme.dart';
import '../widgets/activity_bottom_nav.dart';
import 'activity_absensi_page.dart';
import 'activity_notula_page.dart';
import 'activity_dokumentasi_page.dart';
import 'activity_materi_page.dart';
import 'activity_selfdev_page.dart';

class ActivityRootPage extends StatefulWidget {
  final String groupId;
  final String meetingId;
  final String meetingTitle;

  const ActivityRootPage({
    super.key,
    required this.groupId,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  State<ActivityRootPage> createState() => _ActivityRootPageState();
}

class _ActivityRootPageState extends State<ActivityRootPage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ActivityAbsensiPage(
        groupId: widget.groupId,
        meetingId: widget.meetingId,
      ),
      ActivityNotulaPage(
        groupId: widget.groupId,
        meetingId: widget.meetingId,
      ),
      ActivityDokumentasiPage(
        groupId: widget.groupId,
        meetingId: widget.meetingId,
      ),
      ActivityMateriPage(
        groupId: widget.groupId,
        meetingId: widget.meetingId,
      ),
      ActivitySelfDevPage(
        groupId: widget.groupId,
        meetingId: widget.meetingId,
      ),
    ];

    return Scaffold(
      backgroundColor: SiKawanTheme.surface,
      appBar: AppBar(
        title: Text(widget.meetingTitle),
        centerTitle: true,
      ),

      // ✅ body pakai Stack supaya navbar floating tetap di tengah bawah layar
      body: Stack(
        children: [
          // isi halaman
          IndexedStack(index: _index, children: pages),

          // navbar floating di tengah bawah
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Center(
                child: ActivityBottomNav(
                  currentIndex: _index,
                  onTap: (i) => setState(() => _index = i),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
