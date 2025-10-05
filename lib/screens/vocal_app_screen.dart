import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import '../widgets/animated_background.dart';
import 'redesigned_home_screen.dart';
import 'redesigned_song_library_screen.dart';
import 'practice_session_screen.dart';
import 'progress_dashboard_screen.dart';
import 'profile_screen.dart';
import '../services/native_audio_service.dart';
import '../services/audio_backends/audio_backend_interface.dart';
import '../design_system/screens/vj_recording_flow.dart';

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
  final NativeAudioService _audioService = NativeAudioService.instance;
  AudioServiceStatus? _audioStatus;
  VoidCallback? _statusListener;
  
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

    _audioStatus = _audioService.status;
    _statusListener = () {
      if (!mounted) return;
      setState(() {
        _audioStatus = _audioService.status;
      });
    };
    _audioService.statusNotifier.addListener(_statusListener!);
  }
  
  @override
  void dispose() {
    _backgroundController.dispose();
    _tabController.dispose();
    if (_statusListener != null) {
      _audioService.statusNotifier.removeListener(_statusListener!);
    }
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

          if (_shouldShowAudioBanner)
            Positioned(
              left: 16,
              right: 16,
              bottom: 96,
              child: _buildAudioSupportBanner(),
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

  bool get _shouldShowAudioBanner {
    final status = _audioStatus;
    if (status == null) return false;
    if (!status.supported) return true;
    if (!status.permissionGranted) return true;
    return false;
  }

  Widget _buildAudioSupportBanner() {
    final status = _audioStatus;
    if (status == null) {
      return const SizedBox.shrink();
    }

    IconData icon;
    String title;
    String description;

    if (!status.supported) {
      icon = Icons.computer;
      title = '현재 디바이스에서는 실시간 마이크 캡처가 제한됩니다.';
      description = '녹음 플로우에서 "WAV 파일 업로드" 옵션을 사용해 기존 파일로 분석을 진행해주세요.';
    } else {
      icon = Icons.mic_off;
      title = '마이크 권한이 비활성화되어 있습니다.';
      description = '설정에서 마이크 권한을 허용하거나, 권한 허용이 어려운 경우 WAV 파일 업로드 플로우로 전환할 수 있습니다.';
    }

    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.redAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ) ??
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.black54,
                        ) ??
                        const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _showAudioSupportSheet,
                        icon: const Icon(Icons.help_outline),
                        label: const Text('도움말 보기'),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const VJRecordingFlow(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.library_music),
                        label: const Text('업로드 플로우'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAudioSupportSheet() {
    final status = _audioStatus;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.mic, color: Colors.deepPurple),
                    const SizedBox(width: 12),
                    Text(
                      '마이크 권한 & 대체 플로우 가이드',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (status != null && !status.permissionGranted)
                  Text(
                    '1. 설정 > 앱 > 오비완 > 권한 > 마이크 허용 (Android)\n   설정 > 개인정보 보호 > 마이크 > 오비완 허용 (iOS)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                const SizedBox(height: 12),
                Text(
                  '2. 웹 브라우저에서는 주소창의 잠금 아이콘을 눌러 마이크를 허용해주세요. Safari는 페이지 재로드가 필요할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  '3. 권한 허용이 불가하거나 실시간 녹음이 지원되지 않는 환경에서는 WAV 파일을 업로드하여 분석을 진행할 수 있습니다.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const VJRecordingFlow(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.upload_file),
                  label: const Text('WAV 업로드 플로우 열기'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}