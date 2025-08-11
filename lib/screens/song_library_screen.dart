import 'package:flutter/material.dart';

class SongLibraryScreen extends StatelessWidget {
  final Function(dynamic) onSelectSong;
  final VoidCallback onStartPractice;

  const SongLibraryScreen({
    Key? key,
    required this.onSelectSong,
    required this.onStartPractice,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        '노래 라이브러리',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}