void main() {
  // 프리셋 URL 리스트 테스트
  final List<Map<String, dynamic>> _urlList = [];
  
  // 하드코딩된 프리셋 URL들
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
  
  // addAll()로 추가
  _urlList.addAll(presetURLs);
  
  print('✅ URL 프리셋 테스트 성공!');
  print('📊 로드된 URL 개수: ${_urlList.length}');
  
  for (var i = 0; i < _urlList.length; i++) {
    final item = _urlList[i];
    print('  ${i+1}. ${item['artist']} - ${item['song']}');
  }
}