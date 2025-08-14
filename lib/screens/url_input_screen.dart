import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'ai_labeling_dashboard.dart';

/// YouTube URL 입력 화면
/// 사용자가 분석할 YouTube URL들을 입력하는 화면
class URLInputScreen extends StatefulWidget {
  const URLInputScreen({Key? key}) : super(key: key);

  @override
  State<URLInputScreen> createState() => _URLInputScreenState();
}

class _URLInputScreenState extends State<URLInputScreen> {
  final List<Map<String, dynamic>> _urlList = [];
  final _urlController = TextEditingController();
  final _artistController = TextEditingController();
  final _songController = TextEditingController();
  final _startController = TextEditingController(text: '30');
  final _endController = TextEditingController(text: '45');
  
  bool _isLoadingPreset = false;
  
  @override
  void initState() {
    super.initState();
    _loadPresetURLs();
  }
  
  void _loadPresetURLs() async {
    setState(() {
      _isLoadingPreset = true;
    });
    
    // 하드코딩된 프리셋 URL들 (실제 YouTube URL)
    final presetURLs = [
      {
        'artist': 'Adele',
        'song': 'Hello',
        'url': 'https://www.youtube.com/watch?v=YQHsXMglC9A',
        'start': 30,
        'end': 60,
        'category': '팝 발라드',
      },
      {
        'artist': 'Sam Smith',
        'song': 'Stay With Me',
        'url': 'https://www.youtube.com/watch?v=pB-5XG-DbAA',
        'start': 45,
        'end': 75,
        'category': '소울',
      },
      {
        'artist': 'Bruno Mars',
        'song': 'When I Was Your Man',
        'url': 'https://www.youtube.com/watch?v=ekzHIouo8Q4',
        'start': 60,
        'end': 90,
        'category': 'R&B',
      },
      {
        'artist': '아이유',
        'song': '밤편지',
        'url': 'https://www.youtube.com/watch?v=BzYnNdJhZQw',
        'start': 30,
        'end': 60,
        'category': 'K-발라드',
      },
      {
        'artist': '박효신',
        'song': '야생화',
        'url': 'https://www.youtube.com/watch?v=_hsrsmwHv0A',
        'start': 60,
        'end': 90,
        'category': 'K-발라드',
      },
    ];
    
    // List에 추가
    _urlList.addAll(presetURLs);
    
    setState(() {
      _isLoadingPreset = false;
    });
  }
  
  void _addURL() {
    if (_urlController.text.isEmpty || 
        _artistController.text.isEmpty || 
        _songController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('모든 필드를 입력해주세요'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _urlList.add({
        'artist': _artistController.text,
        'song': _songController.text,
        'url': _urlController.text,
        'start': int.tryParse(_startController.text) ?? 30,
        'end': int.tryParse(_endController.text) ?? 45,
        'category': 'custom',
      });
    });
    
    // Clear fields
    _urlController.clear();
    _artistController.clear();
    _songController.clear();
    _startController.text = '30';
    _endController.text = '45';
  }
  
  void _startProcessing() {
    if (_urlList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('최소 1개 이상의 URL을 추가해주세요'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // AI Labeling Dashboard로 이동하면서 URL 리스트 전달
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => AILabelingDashboardWithData(
          urlList: _urlList,
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27),
      appBar: AppBar(
        title: const Text('YouTube URL 입력'),
        backgroundColor: const Color(0xFF151A30),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF0A0E27),
              const Color(0xFF1A1F3A),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Input Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YouTube 정보 입력',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // URL Input
                    TextField(
                      controller: _urlController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'YouTube URL',
                        labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                        hintText: 'https://youtu.be/...',
                        hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                        prefixIcon: Icon(Icons.link, color: const Color(0xFF7C4DFF)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Artist & Song
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _artistController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: '아티스트',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: Icon(Icons.person, color: const Color(0xFF7C4DFF)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _songController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: '곡명',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              prefixIcon: Icon(Icons.music_note, color: const Color(0xFF7C4DFF)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Time Range
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _startController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '시작 (초)',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _endController,
                            style: const TextStyle(color: Colors.white),
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: '끝 (초)',
                              labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: _addURL,
                          icon: const Icon(Icons.add),
                          label: const Text('추가'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF7C4DFF),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 18,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // URL List
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'URL 리스트 (${_urlList.length}개)',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (_isLoadingPreset)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF7C4DFF),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // List
                      Expanded(
                        child: ListView.builder(
                          itemCount: _urlList.length,
                          itemBuilder: (context, index) {
                            final item = _urlList[index];
                            final isPreset = item['category'] != 'custom';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isPreset
                                      ? const Color(0xFF7C4DFF).withOpacity(0.3)
                                      : Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (isPreset)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C4DFF).withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'PRESET',
                                        style: TextStyle(
                                          color: Color(0xFF7C4DFF),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  if (isPreset) const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${item['artist']} - ${item['song']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${item['start']}s - ${item['end']}s',
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.5),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _urlList.removeAt(index);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _startProcessing,
                  icon: const Icon(Icons.auto_awesome, size: 24),
                  label: Text(
                    'AI 라벨링 시작 (${_urlList.length}개)',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7C4DFF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  @override
  void dispose() {
    _urlController.dispose();
    _artistController.dispose();
    _songController.dispose();
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }
}

/// AI Labeling Dashboard with Data
class AILabelingDashboardWithData extends AILabelingDashboard {
  final List<Map<String, dynamic>> urlList;
  
  const AILabelingDashboardWithData({
    Key? key,
    required this.urlList,
  }) : super(key: key);
  
  @override
  State<AILabelingDashboard> createState() => _AILabelingDashboardWithDataState();
}

class _AILabelingDashboardWithDataState extends State<AILabelingDashboard> {
  @override
  void initState() {
    super.initState();
    // URL 리스트를 사용하여 처리 시작
    print('Processing ${(widget as AILabelingDashboardWithData).urlList.length} URLs');
  }

  @override
  Widget build(BuildContext context) {
    final urls = (widget as AILabelingDashboardWithData).urlList;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Labeling Dashboard'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Processing ${urls.length} URLs'),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            const Text('AI labeling in progress...'),
          ],
        ),
      ),
    );
  }
}