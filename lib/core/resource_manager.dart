import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 중앙 리소스 관리자 - 모든 Timer, Stream, AnimationController를 추적하고 관리
class ResourceManager {
  static final ResourceManager _instance = ResourceManager._internal();
  factory ResourceManager() => _instance;
  ResourceManager._internal();

  // 리소스 추적용 컬렉션들
  final Set<Timer> _timers = <Timer>{};
  final Set<StreamController> _streamControllers = <StreamController>{};
  final Set<StreamSubscription> _streamSubscriptions = <StreamSubscription>{};
  final Set<AnimationController> _animationControllers = <AnimationController>{};
  final Set<Disposable> _disposables = <Disposable>{};

  // 메모리 사용량 모니터링
  final Map<String, int> _resourceCounts = <String, int>{};
  Timer? _monitoringTimer;
  bool _isMonitoring = false;

  /// 타이머 등록 및 추적
  Timer registerTimer(Duration duration, void Function() callback, {String? debugName}) {
    final timer = Timer.periodic(duration, (timer) => callback());
    _timers.add(timer);
    _incrementResourceCount('Timer', debugName);
    _logResourceAction('Timer registered', debugName);
    return timer;
  }

  /// 일회성 타이머 등록
  Timer registerSingleTimer(Duration duration, void Function() callback, {String? debugName}) {
    Timer? timer;
    timer = Timer(duration, () {
      callback();
      if (timer != null) {
        _timers.remove(timer);
        _decrementResourceCount('Timer', debugName);
      }
    });
    _timers.add(timer);
    _incrementResourceCount('Timer', debugName);
    _logResourceAction('Single timer registered', debugName);
    return timer;
  }

  /// StreamController 등록 및 추적
  StreamController<T> registerStreamController<T>({bool broadcast = false, String? debugName}) {
    final controller = broadcast 
        ? StreamController<T>.broadcast()
        : StreamController<T>();

    // 자동 정리를 위한 onCancel 핸들러 추가
    if (broadcast) {
      controller.onCancel = () {
        _streamControllers.remove(controller);
        _decrementResourceCount('StreamController', debugName);
        _logResourceAction('Broadcast StreamController auto-disposed', debugName);
      };
    }

    _streamControllers.add(controller);
    _incrementResourceCount('StreamController', debugName);
    _logResourceAction('StreamController registered', debugName);
    return controller;
  }

  /// StreamSubscription 등록 및 추적
  StreamSubscription<T> registerStreamSubscription<T>(
    StreamSubscription<T> subscription, 
    {String? debugName}
  ) {
    _streamSubscriptions.add(subscription);
    _incrementResourceCount('StreamSubscription', debugName);
    _logResourceAction('StreamSubscription registered', debugName);
    return subscription;
  }

  /// AnimationController 등록 및 추적
  AnimationController registerAnimationController({
    required Duration duration,
    required TickerProvider vsync,
    String? debugName,
    double? value,
    Duration? reverseDuration,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
  }) {
    final controller = AnimationController(
      duration: duration,
      vsync: vsync,
      value: value,
      reverseDuration: reverseDuration,
      animationBehavior: animationBehavior,
    );

    _animationControllers.add(controller);
    _incrementResourceCount('AnimationController', debugName);
    _logResourceAction('AnimationController registered', debugName);
    return controller;
  }

  /// Disposable 객체 등록 및 추적
  T registerDisposable<T extends Disposable>(T disposable, {String? debugName}) {
    _disposables.add(disposable);
    _incrementResourceCount('Disposable', debugName);
    _logResourceAction('Disposable registered', debugName);
    return disposable;
  }

  /// 특정 타이머 해제
  void disposeTimer(Timer timer, {String? debugName}) {
    if (_timers.remove(timer)) {
      timer.cancel();
      _decrementResourceCount('Timer', debugName);
      _logResourceAction('Timer disposed', debugName);
    }
  }

  /// 특정 StreamController 해제
  void disposeStreamController(StreamController controller, {String? debugName}) {
    if (_streamControllers.remove(controller)) {
      if (!controller.isClosed) {
        controller.close();
      }
      _decrementResourceCount('StreamController', debugName);
      _logResourceAction('StreamController disposed', debugName);
    }
  }

  /// 특정 StreamSubscription 해제
  void disposeStreamSubscription(StreamSubscription subscription, {String? debugName}) {
    if (_streamSubscriptions.remove(subscription)) {
      subscription.cancel();
      _decrementResourceCount('StreamSubscription', debugName);
      _logResourceAction('StreamSubscription disposed', debugName);
    }
  }

  /// 특정 AnimationController 해제
  void disposeAnimationController(AnimationController controller, {String? debugName}) {
    if (_animationControllers.remove(controller)) {
      controller.dispose();
      _decrementResourceCount('AnimationController', debugName);
      _logResourceAction('AnimationController disposed', debugName);
    }
  }

  /// 특정 Disposable 해제
  void disposeDisposable(Disposable disposable, {String? debugName}) {
    if (_disposables.remove(disposable)) {
      disposable.dispose();
      _decrementResourceCount('Disposable', debugName);
      _logResourceAction('Disposable disposed', debugName);
    }
  }

  /// 모든 리소스 일괄 정리
  Future<void> disposeAll() async {
    _logResourceAction('Starting bulk disposal', null);
    
    // Timer 정리
    for (final timer in List.from(_timers)) {
      timer.cancel();
    }
    _timers.clear();

    // StreamSubscription 정리 (StreamController보다 먼저)
    for (final subscription in List.from(_streamSubscriptions)) {
      await subscription.cancel();
    }
    _streamSubscriptions.clear();

    // StreamController 정리
    for (final controller in List.from(_streamControllers)) {
      if (!controller.isClosed) {
        controller.close();
      }
    }
    _streamControllers.clear();

    // AnimationController 정리
    for (final controller in List.from(_animationControllers)) {
      controller.dispose();
    }
    _animationControllers.clear();

    // Disposable 객체 정리
    for (final disposable in List.from(_disposables)) {
      disposable.dispose();
    }
    _disposables.clear();

    // 모니터링 타이머 정리
    _stopMonitoring();

    _resourceCounts.clear();
    _logResourceAction('Bulk disposal completed', null);
  }

  /// 메모리 사용량 모니터링 시작
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    if (_isMonitoring) return;

    _isMonitoring = true;
    _monitoringTimer = Timer.periodic(interval, (timer) {
      _logMemoryUsage();
    });
    
    debugPrint('🔍 [ResourceManager] Memory monitoring started');
  }

  /// 메모리 사용량 모니터링 중지
  void _stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _isMonitoring = false;
    debugPrint('🔍 [ResourceManager] Memory monitoring stopped');
  }

  /// 현재 리소스 상태 조회
  ResourceStatus getStatus() {
    return ResourceStatus(
      timerCount: _timers.length,
      streamControllerCount: _streamControllers.length,
      streamSubscriptionCount: _streamSubscriptions.length,
      animationControllerCount: _animationControllers.length,
      disposableCount: _disposables.length,
      resourceCounts: Map.from(_resourceCounts),
    );
  }

  /// 약한 참조를 사용한 순환 참조 방지
  final Map<String, WeakReference<Object>> _weakReferences = {};
  
  void registerWeakReference<T extends Object>(String key, T object) {
    _weakReferences[key] = WeakReference(object);
    debugPrint('🔗 [ResourceManager] Weak reference registered: $key');
  }

  T? getWeakReference<T extends Object>(String key) {
    final weakRef = _weakReferences[key];
    final target = weakRef?.target;
    
    if (target == null) {
      _weakReferences.remove(key);
      debugPrint('🔗 [ResourceManager] Weak reference garbage collected: $key');
    }
    
    return target as T?;
  }

  /// 리소스 카운트 증가
  void _incrementResourceCount(String type, String? debugName) {
    final key = debugName != null ? '$type($debugName)' : type;
    _resourceCounts[key] = (_resourceCounts[key] ?? 0) + 1;
  }

  /// 리소스 카운트 감소
  void _decrementResourceCount(String type, String? debugName) {
    final key = debugName != null ? '$type($debugName)' : type;
    final currentCount = _resourceCounts[key] ?? 0;
    if (currentCount > 0) {
      _resourceCounts[key] = currentCount - 1;
      if (_resourceCounts[key] == 0) {
        _resourceCounts.remove(key);
      }
    }
  }

  /// 리소스 액션 로깅
  void _logResourceAction(String action, String? debugName) {
    if (kDebugMode) {
      final nameText = debugName != null ? ' ($debugName)' : '';
      debugPrint('📋 [ResourceManager] $action$nameText');
    }
  }

  /// 메모리 사용량 로깅
  void _logMemoryUsage() {
    if (kDebugMode) {
      final status = getStatus();
      debugPrint('📊 [ResourceManager] Memory Status:');
      debugPrint('   Timers: ${status.timerCount}');
      debugPrint('   StreamControllers: ${status.streamControllerCount}');
      debugPrint('   StreamSubscriptions: ${status.streamSubscriptionCount}');
      debugPrint('   AnimationControllers: ${status.animationControllerCount}');
      debugPrint('   Disposables: ${status.disposableCount}');
      
      if (status.resourceCounts.isNotEmpty) {
        debugPrint('   Detailed counts:');
        status.resourceCounts.forEach((key, count) {
          debugPrint('     $key: $count');
        });
      }
    }
  }

  /// 앱 종료시 호출할 정리 메서드
  Future<void> cleanup() async {
    debugPrint('🧹 [ResourceManager] Starting app cleanup...');
    await disposeAll();
    debugPrint('✅ [ResourceManager] App cleanup completed');
  }
}

/// 리소스 상태 정보
class ResourceStatus {
  final int timerCount;
  final int streamControllerCount;
  final int streamSubscriptionCount;
  final int animationControllerCount;
  final int disposableCount;
  final Map<String, int> resourceCounts;

  const ResourceStatus({
    required this.timerCount,
    required this.streamControllerCount,
    required this.streamSubscriptionCount,
    required this.animationControllerCount,
    required this.disposableCount,
    required this.resourceCounts,
  });

  int get totalResourceCount => 
      timerCount + streamControllerCount + streamSubscriptionCount + 
      animationControllerCount + disposableCount;

  bool get hasLeaks => totalResourceCount > 0;

  @override
  String toString() {
    return 'ResourceStatus(total: $totalResourceCount, '
           'timers: $timerCount, controllers: $streamControllerCount, '
           'subscriptions: $streamSubscriptionCount, '
           'animations: $animationControllerCount, '
           'disposables: $disposableCount)';
  }
}

/// Disposable 인터페이스
abstract class Disposable {
  void dispose();
}

/// ResourceManager를 사용하는 StatefulWidget용 믹스인
mixin ResourceManagerMixin<T extends StatefulWidget> on State<T> {
  final ResourceManager _resourceManager = ResourceManager();
  final List<Timer> _timers = [];
  final List<StreamController> _streamControllers = [];
  final List<StreamSubscription> _streamSubscriptions = [];
  final List<AnimationController> _animationControllers = [];

  /// 타이머 등록
  Timer registerTimer(Duration duration, void Function() callback, {String? debugName}) {
    final timer = _resourceManager.registerTimer(duration, callback, debugName: debugName);
    _timers.add(timer);
    return timer;
  }

  /// StreamController 등록
  StreamController<E> registerStreamController<E>({bool broadcast = false, String? debugName}) {
    final controller = _resourceManager.registerStreamController<E>(
      broadcast: broadcast, 
      debugName: debugName
    );
    _streamControllers.add(controller);
    return controller;
  }

  /// StreamSubscription 등록
  StreamSubscription<E> registerStreamSubscription<E>(
    StreamSubscription<E> subscription, 
    {String? debugName}
  ) {
    final registeredSub = _resourceManager.registerStreamSubscription(
      subscription, 
      debugName: debugName
    );
    _streamSubscriptions.add(registeredSub);
    return registeredSub;
  }

  /// AnimationController 등록
  AnimationController registerAnimationController({
    required Duration duration,
    String? debugName,
    double? value,
    Duration? reverseDuration,
    AnimationBehavior animationBehavior = AnimationBehavior.normal,
  }) {
    final controller = _resourceManager.registerAnimationController(
      duration: duration,
      vsync: this as TickerProviderStateMixin,
      debugName: debugName,
      value: value,
      reverseDuration: reverseDuration,
      animationBehavior: animationBehavior,
    );
    _animationControllers.add(controller);
    return controller;
  }

  /// 자동 정리 - StatefulWidget의 dispose에서 호출
  @override
  void dispose() {
    // 역순으로 정리하여 의존성 문제 방지
    for (final controller in _animationControllers.reversed) {
      _resourceManager.disposeAnimationController(controller);
    }
    _animationControllers.clear();

    for (final subscription in _streamSubscriptions.reversed) {
      _resourceManager.disposeStreamSubscription(subscription);
    }
    _streamSubscriptions.clear();

    for (final controller in _streamControllers.reversed) {
      _resourceManager.disposeStreamController(controller);
    }
    _streamControllers.clear();

    for (final timer in _timers.reversed) {
      _resourceManager.disposeTimer(timer);
    }
    _timers.clear();

    super.dispose();
  }
}