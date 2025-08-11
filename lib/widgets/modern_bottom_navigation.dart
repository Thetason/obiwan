import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class ModernBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  
  const ModernBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  State<ModernBottomNavigation> createState() => _ModernBottomNavigationState();
}

class _ModernBottomNavigationState extends State<ModernBottomNavigation>
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late List<Animation<double>> _animations;
  
  final List<NavigationItem> items = [
    NavigationItem(
      icon: CupertinoIcons.home,
      activeIcon: CupertinoIcons.house_fill,
      label: '홈',
    ),
    NavigationItem(
      icon: CupertinoIcons.music_note,
      activeIcon: CupertinoIcons.music_note_2,
      label: '노래',
    ),
    NavigationItem(
      icon: CupertinoIcons.play_circle,
      activeIcon: CupertinoIcons.play_circle_fill,
      label: '연습',
    ),
    NavigationItem(
      icon: CupertinoIcons.chart_line,
      activeIcon: CupertinoIcons.chart_bar_alt_fill,
      label: '진도',
    ),
    NavigationItem(
      icon: CupertinoIcons.person,
      activeIcon: CupertinoIcons.person_fill,
      label: '프로필',
    ),
  ];
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _animations = List.generate(
      items.length,
      (index) => Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Interval(
            index * 0.1,
            0.5 + index * 0.1,
            curve: Curves.easeOutCubic,
          ),
        ),
      ),
    );
    
    _animationController.forward();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 65,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final isSelected = widget.currentIndex == index;
              final item = items[index];
              
              return Expanded(
                child: AnimatedBuilder(
                  animation: _animations[index],
                  builder: (context, child) {
                    return GestureDetector(
                      onTap: () {
                        widget.onTap(index);
                        _animationController.reset();
                        _animationController.forward();
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSelected ? 16 : 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFF6366F1).withOpacity(0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: Icon(
                                isSelected ? item.activeIcon : item.icon,
                                key: ValueKey(isSelected),
                                color: isSelected
                                    ? const Color(0xFF6366F1)
                                    : const Color(0xFF9CA3AF),
                                size: isSelected ? 26 : 24,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isSelected ? 11 : 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected
                                  ? const Color(0xFF6366F1)
                                  : const Color(0xFF9CA3AF),
                            ),
                            child: Text(item.label),
                          ),
                          if (isSelected)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(top: 4),
                              height: 3,
                              width: 3,
                              decoration: const BoxDecoration(
                                color: Color(0xFF6366F1),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  
  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}