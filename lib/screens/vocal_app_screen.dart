import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../widgets/animated_background.dart';
import 'redesigned_home_screen.dart';
import 'redesigned_song_library_screen.dart';
import 'practice_session_screen.dart';
import 'progress_dashboard_screen.dart';
import 'profile_screen.dart';

enum TabType { home, songs, practice, progress, profile }

class VocalAppScreen extends StatefulWidget {
  const VocalAppScreen({Key? key}) : super(key: key);

  @override
  State<VocalAppScreen> createState() => _VocalAppScreenState();
}

class _VocalAppScreenState extends State<VocalAppScreen>
    with TickerProviderStateMixin {
  
  TabType _activeTab = TabType.home;
  dynamic _selectedSong;
  
  late AnimationController _backgroundController;
  late AnimationController _tabController;
  
  @override
  void initState() {
    super.initState();
    _backgroundController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);
    
    _tabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }
  
  @override
  void dispose() {
    _backgroundController.dispose();
    _tabController.dispose();
    super.dispose();
  }
  
  void _navigateToTab(dynamic tab) {
    HapticFeedback.lightImpact();
    if (tab is String) {
      // String 기반 네비게이션 처리
      switch (tab) {
        case 'songs':
          setState(() => _activeTab = TabType.songs);
          break;
        case 'progress':
          setState(() => _activeTab = TabType.progress);
          break;
        case 'practice':
          setState(() => _activeTab = TabType.practice);
          break;
        case 'profile':
          setState(() => _activeTab = TabType.profile);
          break;
        default:
          setState(() => _activeTab = TabType.home);
      }
    } else if (tab is TabType) {
      setState(() => _activeTab = tab);
    }
    _tabController.forward().then((_) => _tabController.reset());
  }
  
  void _selectSong(dynamic song) {
    setState(() {
      _selectedSong = song;
    });
  }
  
  Widget _renderContent() {
    switch (_activeTab) {
      case TabType.home:
        return RedesignedHomeScreen(
          onNavigate: (tab) => _navigateToTab(tab),
        );
      case TabType.songs:
        return const RedesignedSongLibraryScreen();
      case TabType.practice:
        return PracticeSessionScreen(selectedSong: _selectedSong);
      case TabType.progress:
        return const ProgressDashboardScreen();
      case TabType.profile:
        return const ProfileScreen();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated Background - 피그마 디자인 그대로
          AnimatedBackground(controller: _backgroundController),
          
          // Main Content
          Column(
            children: [
              // Content Area
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: _renderContent(),
                ),
              ),
              
              // Enhanced Bottom Navigation - 피그마 스타일
              _buildBottomNavigation(),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildBottomNavigation() {
    final tabs = [
      {'id': TabType.home, 'label': '홈', 'icon': Icons.home},
      {'id': TabType.songs, 'label': '노래', 'icon': Icons.music_note},
      {'id': TabType.practice, 'label': '연습', 'icon': Icons.track_changes},
      {'id': TabType.progress, 'label': '진도', 'icon': Icons.trending_up},
      {'id': TabType.profile, 'label': '프로필', 'icon': Icons.person},
    ];
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: SafeArea(
              top: false,
              child: Stack(
                children: [
                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0x0D3B82F6),
                            Colors.transparent,
                            Color(0x0D8B5CF6),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  // Tab Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: tabs.map((tab) {
                      final tabType = tab['id'] as TabType;
                      final isActive = _activeTab == tabType;
                      
                      return GestureDetector(
                        onTap: () => _navigateToTab(tabType),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12, 
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            color: isActive 
                              ? const Color(0x60EBF4FF) 
                              : Colors.transparent,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: isActive
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF8B5CF6),
                                        ],
                                      )
                                    : null,
                                  boxShadow: isActive
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF3B82F6)
                                              .withOpacity(0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                                ),
                                child: Icon(
                                  tab['icon'] as IconData,
                                  size: 18,
                                  color: isActive
                                    ? Colors.white
                                    : const Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                tab['label'] as String,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isActive
                                    ? const Color(0xFF1E40AF)
                                    : const Color(0xFF6B7280),
                                ),
                              ),
                              if (isActive)
                                Container(
                                  margin: const EdgeInsets.only(top: 2),
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}