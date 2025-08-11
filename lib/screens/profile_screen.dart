import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  bool _isEditing = false;
  
  // 프로필 데이터
  String _userName = '음악애호가';
  String _userLevel = '중급';
  String _userBio = '매일 성장하는 보컬리스트';
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildProfileCard(),
              _buildStatsSection(),
              _buildSettingsSection(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            '프로필',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: const Color(0xFF7C4DFF),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() {
                _isEditing = !_isEditing;
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildProfileCard() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_animationController.value * 0.2),
          child: Opacity(
            opacity: _animationController.value,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF7C4DFF),
                    Color(0xFF9C88FF),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF7C4DFF).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // 프로필 이미지
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            '🎤',
                            style: TextStyle(fontSize: 48),
                          ),
                        ),
                      ),
                      if (_userLevel == '중급')
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFC107),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: const Icon(
                              Icons.star,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  // 사용자 이름
                  _isEditing
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: TextEditingController(text: _userName),
                          onChanged: (value) => _userName = value,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                  const SizedBox(height: 8),
                  
                  // 레벨 뱃지
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '레벨: $_userLevel',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 소개
                  _isEditing
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: TextEditingController(text: _userBio),
                          onChanged: (value) => _userBio = value,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                          decoration: const InputDecoration(
                            border: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            enabledBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                            focusedBorder: UnderlineInputBorder(
                              borderSide: BorderSide(color: Colors.white),
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _userBio,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatsSection() {
    final stats = [
      {'icon': Icons.emoji_events, 'value': '15', 'label': '업적'},
      {'icon': Icons.local_fire_department, 'value': '12', 'label': '연속일'},
      {'icon': Icons.favorite, 'value': '284', 'label': '좋아요'},
      {'icon': Icons.group, 'value': '1.2k', 'label': '팔로워'},
    ];
    
    return Container(
      margin: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: stats.map((stat) {
          return _buildStatItem(
            icon: stat['icon'] as IconData,
            value: stat['value'] as String,
            label: stat['label'] as String,
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: const Color(0xFF7C4DFF),
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingsSection() {
    final settings = [
      {
        'icon': Icons.notifications,
        'title': '알림 설정',
        'subtitle': '연습 리마인더, 업데이트 알림',
        'trailing': Switch(
          value: true,
          onChanged: (value) {},
          activeColor: const Color(0xFF7C4DFF),
        ),
      },
      {
        'icon': Icons.music_note,
        'title': '음역대 설정',
        'subtitle': 'A3 - C5',
        'trailing': const Icon(Icons.chevron_right, color: Colors.grey),
      },
      {
        'icon': Icons.mic,
        'title': '마이크 설정',
        'subtitle': '입력 감도 조절',
        'trailing': const Icon(Icons.chevron_right, color: Colors.grey),
      },
      {
        'icon': Icons.language,
        'title': '언어',
        'subtitle': '한국어',
        'trailing': const Icon(Icons.chevron_right, color: Colors.grey),
      },
      {
        'icon': Icons.dark_mode,
        'title': '다크 모드',
        'subtitle': '눈의 피로를 줄여줍니다',
        'trailing': Switch(
          value: false,
          onChanged: (value) {},
          activeColor: const Color(0xFF7C4DFF),
        ),
      },
      {
        'icon': Icons.privacy_tip,
        'title': '개인정보 처리방침',
        'subtitle': '데이터 보호 정책',
        'trailing': const Icon(Icons.chevron_right, color: Colors.grey),
      },
      {
        'icon': Icons.info,
        'title': '앱 정보',
        'subtitle': '버전 3.0.0',
        'trailing': const Icon(Icons.chevron_right, color: Colors.grey),
      },
    ];
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: settings.map((setting) {
          final isLast = settings.last == setting;
          return _buildSettingItem(
            icon: setting['icon'] as IconData,
            title: setting['title'] as String,
            subtitle: setting['subtitle'] as String,
            trailing: setting['trailing'] as Widget,
            showDivider: !isLast,
          );
        }).toList(),
      ),
    );
  }
  
  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required bool showDivider,
  }) {
    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              HapticFeedback.lightImpact();
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7C4DFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      icon,
                      color: const Color(0xFF7C4DFF),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              height: 1,
              color: Colors.grey.withOpacity(0.2),
            ),
          ),
      ],
    );
  }
}