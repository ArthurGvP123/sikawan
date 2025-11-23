import 'package:flutter/material.dart';

import 'home_page.dart';
import 'group_page.dart';
import 'profile_page.dart';

class RootPage extends StatefulWidget {
  final int initialIndex;
  const RootPage({super.key, this.initialIndex = 0});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late int _index;

  final _pages = const [
    HomePage(),
    GroupPage(),
    ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: _pages,
      ),
    );
  }
}
