import 'package:flutter/material.dart';

class RedesignedSongLibraryScreen extends StatefulWidget {
  const RedesignedSongLibraryScreen({Key? key}) : super(key: key);

  @override
  State<RedesignedSongLibraryScreen> createState() => _RedesignedSongLibraryScreenState();
}

class _RedesignedSongLibraryScreenState extends State<RedesignedSongLibraryScreen> {
  String _selectedGenre = '전체';
  String _selectedDifficulty = '전체';
  
  final List<Map<String, dynamic>> _songs = [
    {
      'title': 'Perfect',
      'artist': 'Ed Sheeran',
      'duration': '4:23',
      'difficulty': '쉬움',
      'rating': 4.8,
      'genre': '팝',
      'thumbnail': '🎵',
      'isNew': true,
    },
    {
      'title': 'Someone Like You',
      'artist': 'Adele',
      'duration': '4:47',
      'difficulty': '어려움',
      'rating': 4.9,
      'genre': '발라드',
      'thumbnail': '🎤',
      'isNew': false,
    },
    {
      'title': 'Shape of You',
      'artist': 'Ed Sheeran',
      'duration': '3:53',
      'difficulty': '보통',
      'rating': 4.7,
      'genre': '팝',
      'thumbnail': '🎸',
      'isNew': true,
    },
    {
      'title': 'Dynamite',
      'artist': 'BTS',
      'duration': '3:19',
      'difficulty': '보통',
      'rating': 4.6,
      'genre': 'K-팝',
      'thumbnail': '💃',
      'isNew': false,
    },
    {
      'title': 'Bohemian Rhapsody',
      'artist': 'Queen',
      'duration': '5:55',
      'difficulty': '어려움',
      'rating': 4.9,
      'genre': '록',
      'thumbnail': '👑',
      'isNew': false,
    },
    {
      'title': 'Fly Me to the Moon',
      'artist': 'Frank Sinatra',
      'duration': '2:28',
      'difficulty': '보통',
      'rating': 4.8,
      'genre': '재즈',
      'thumbnail': '🎺',
      'isNew': false,
    },
  ];
  
  List<Map<String, dynamic>> get _filteredSongs {
    return _songs.where((song) {
      final genreMatch = _selectedGenre == '전체' || song['genre'] == _selectedGenre;
      final difficultyMatch = _selectedDifficulty == '전체' || song['difficulty'] == _selectedDifficulty;
      return genreMatch && difficultyMatch;
    }).toList();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      body: SafeArea(
        child: Column(
          children: [
            // 헤더
            _buildHeader(),
            
            // 검색 바
            _buildSearchBar(),
            
            // 필터 칩들
            _buildFilterChips(),
            
            // 곡 리스트
            Expanded(
              child: _buildSongList(),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '노래 라이브러리',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: '노래나 아티스트 검색...',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: InputBorder.none,
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
        ),
      ),
    );
  }
  
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 장르 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  '장르',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                ..._buildGenreChips(),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // 난이도 필터
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  '난이도',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(width: 12),
                ..._buildDifficultyChips(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildGenreChips() {
    final genres = ['전체', '팝', '발라드', '록', '재즈', 'K-팝'];
    return genres.map((genre) {
      final isSelected = _selectedGenre == genre;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(genre),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedGenre = genre;
            });
          },
          selectedColor: const Color(0xFF5B8DEE),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }
  
  List<Widget> _buildDifficultyChips() {
    final difficulties = ['전체', '쉬움', '보통', '어려움'];
    return difficulties.map((difficulty) {
      final isSelected = _selectedDifficulty == difficulty;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(difficulty),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              _selectedDifficulty = difficulty;
            });
          },
          selectedColor: const Color(0xFF5B8DEE),
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[700],
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      );
    }).toList();
  }
  
  Widget _buildSongList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredSongs.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${_filteredSongs.length}곡 찾음',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          );
        }
        
        final song = _filteredSongs[index - 1];
        return _buildSongCard(song);
      },
    );
  }
  
  Widget _buildSongCard(Map<String, dynamic> song) {
    Color difficultyColor;
    switch (song['difficulty']) {
      case '쉬움':
        difficultyColor = const Color(0xFF4CAF50);
        break;
      case '보통':
        difficultyColor = const Color(0xFFFFC107);
        break;
      case '어려움':
        difficultyColor = const Color(0xFFFF5252);
        break;
      default:
        difficultyColor = Colors.grey;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // 곡 선택 시 동작
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // 썸네일
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C4DFF).withOpacity(0.8),
                        const Color(0xFF9C88FF).withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      song['thumbnail'],
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // 곡 정보
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (song['isNew'])
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          Expanded(
                            child: Text(
                              song['title'],
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A1A1A),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        song['artist'],
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: difficultyColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              song['difficulty'],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: difficultyColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                          const SizedBox(width: 4),
                          Text(
                            song['duration'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.star, size: 14, color: Colors.amber[400]),
                          const SizedBox(width: 4),
                          Text(
                            song['rating'].toString(),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // 재생 버튼
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B8DEE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}