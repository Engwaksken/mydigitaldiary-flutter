import 'dart:async';
import 'dart:math' as math;

import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sensors_plus/sensors_plus.dart';

import 'api_client.dart';

enum StepSensorMode {
  waiting,
  hardware,
  validatedMotion,
  unavailable,
}

int _normaliseGoal(dynamic value) {
  final goal = int.tryParse('${value ?? ''}') ?? 0;
  return goal > 0 ? goal : 5000;
}

class StepTrackingState {
  final int steps;
  final int dailyGoal;
  final bool isTracking;
  final int progressPercent;
  final DateTime? lastSyncedAt;
  final bool serverAvailable;
  final String? statusMessage;
  final StepSensorMode sensorMode;
  final int? distanceM;

  const StepTrackingState({
    required this.steps,
    required this.dailyGoal,
    required this.isTracking,
    required this.progressPercent,
    this.lastSyncedAt,
    this.serverAvailable = true,
    this.statusMessage,
    this.sensorMode = StepSensorMode.waiting,
    this.distanceM,
  });

  factory StepTrackingState.fromMap(Map<String, dynamic> map) {
    return StepTrackingState(
      steps: int.tryParse('${map['steps'] ?? 0}') ?? 0,
      dailyGoal: _normaliseGoal(map['daily_goal']),
      isTracking: map['is_tracking'] == true ||
          map['is_tracking'] == 1 ||
          map['is_tracking'] == '1',
      progressPercent:
          int.tryParse('${map['progress_percent'] ?? 0}') ?? 0,
      lastSyncedAt:
          DateTime.tryParse('${map['last_synced_at'] ?? ''}')?.toLocal(),
      serverAvailable: map['server_available'] ?? true,
      statusMessage: map['status_message']?.toString(),
      sensorMode: _sensorModeFromString(map['sensor_mode']),
      distanceM: int.tryParse('${map['distance_m'] ?? 0}') ?? 0,
    );
  }

  static StepSensorMode _sensorModeFromString(dynamic value) {
    final str = value?.toString() ?? '';
    if (str == 'hardware') return StepSensorMode.hardware;
    if (str == 'validatedMotion') return StepSensorMode.validatedMotion;
    if (str == 'unavailable') return StepSensorMode.unavailable;
    return StepSensorMode.waiting;
  }
}

class StepTrackingService {
  StepTrackingService._();

  static final StepTrackingService instance = StepTrackingService._();

  final StreamController<StepTrackingState> _controller =
      StreamController<StepTrackingState>.broadcast();

  Stream<StepTrackingState> get stream => _controller.stream;

  StreamSubscription<StepCount>? _pedometerSub;
  StreamSubscription<AccelerometerEvent>? _accelerometerSub;
  Timer? _fallbackTimer;
  Timer? _syncTimer;

  bool _tracking = false;
  bool _serverAvailable = true;
  bool _nativeStepEventSeen = false;
  bool _autoPausedForInactivity = false;
  DateTime _activeDate = DateTime.now();
  Timer? _inactivityTimer;
  Timer? _midnightTimer;

  int _serverSteps = 0;
  int _dailyGoal = 5000;
  int _validatedSessionSteps = 0;
  int? _nativeBaseline;
  int? _distanceM;

  double _gravityEstimate = 9.81;
  bool _peakArmed = true;
  DateTime? _lastCandidateAt;
  int _candidateBurstCount = 0;
  int _acceptedBurstSteps = 0;
  DateTime? _lastSyncAt;

  StepSensorMode _mode = StepSensorMode.waiting;

  bool get isTracking => _tracking;

  Future<StepTrackingState> load() async {
    _rollOverIfNeeded();
    try {
      final response = await ApiClient.instance.get(
        'wellbeing/steps',
        cacheable: false,
      );

      final server = StepTrackingState.fromMap(_unwrap(response));
      final localTotal = _serverSteps + _validatedSessionSteps;

      _serverSteps = server.steps > localTotal ? server.steps : localTotal;
      _validatedSessionSteps = 0;
      _dailyGoal = _normaliseGoal(server.dailyGoal);
      _tracking = server.isTracking;
      _serverAvailable = true;
      _distanceM = server.distanceM;

      if (_tracking) {
        _scheduleMidnightRollover();
        await _startSensors();
      }

      final state = _state(
        message: _tracking
            ? 'Ready to continue from your saved daily total.'
            : null,
      );
      _emit(state);
      return state;
    } catch (_) {
      _serverAvailable = false;
      final state = _state(
        message: 'Working locally. Waiting to sync with My Digital Diary.',
      );
      _emit(state);
      return state;
    }
  }

  Future<void> start() async {
    _rollOverIfNeeded();
    _scheduleMidnightRollover();
    if (_tracking) {
      return;
    }

    final permission = await Permission.activityRecognition.request();

    if (!permission.isGranted) {
      throw StateError(
        permission.isPermanentlyDenied
            ? 'Physical activity permission is permanently denied. Enable it in Settings.'
            : 'Physical activity permission is required to track steps.',
      );
    }

    try {
      final response = await ApiClient.instance.get(
        'wellbeing/steps',
        cacheable: false,
      );
      final server = StepTrackingState.fromMap(_unwrap(response));
      if (server.steps > _serverSteps) {
        _serverSteps = server.steps;
      }
      _dailyGoal = _normaliseGoal(server.dailyGoal);
      _serverAvailable = true;
      _distanceM = server.distanceM;
    } catch (_) {
      _serverAvailable = false;
    }

    _tracking = true;
    _validatedSessionSteps = 0;
    _nativeBaseline = null;
    _resetMotionValidation();

    try {
      await ApiClient.instance.post(
        'wellbeing/steps/start',
        const <String, dynamic>{},
      );
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }

    await _startSensors();
    _startSyncTimer();
    _startInactivityWatch();

    _emit(
      _state(
        message:
            'Tracking started. Only sustained walking is added to your daily total.',
      ),
    );
  }

  Future<void> stop() async {
    if (!_tracking) {
      return;
    }

    await _syncSafely();

    _tracking = false;
    _autoPausedForInactivity = false;
    _midnightTimer?.cancel();
    _midnightTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    await _stopSensors();

    try {
      await ApiClient.instance.post(
        'wellbeing/steps/stop',
        const <String, dynamic>{},
      );
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }

    _emit(_state(message: 'Walking tracking paused.'));
  }

  void _rollOverIfNeeded() {
    final now = DateTime.now();
    final sameDay = now.year == _activeDate.year &&
        now.month == _activeDate.month &&
        now.day == _activeDate.day;

    // IMPORTANT:
    // Never reset because the user reached 500 steps, synced with Laravel,
    // paused tracking, reopened the app, or the sensor baseline changed.
    // A reset is allowed only after the local calendar date changes.
    if (sameDay) {
      return;
    }

    _activeDate = now;
    _serverSteps = 0;
    _validatedSessionSteps = 0;
    _dailyGoal = 5000;
    _nativeBaseline = null;
    _autoPausedForInactivity = false;
    _lastSyncAt = null;

    _emit(
      _state(
        message: 'New day started. Today’s step count has reset to 0.',
      ),
    );

    _scheduleMidnightRollover();
  }

  void _scheduleMidnightRollover() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    );

    final delay = nextMidnight.difference(now) + const Duration(seconds: 1);

    _midnightTimer = Timer(delay, () {
      _rollOverIfNeeded();
    });
  }

  void _markWalkingActivity() {
    _rollOverIfNeeded();

    if (_autoPausedForInactivity) {
      _autoPausedForInactivity = false;
      _emit(_state(message: 'Walking detected. Step tracking resumed.'));
    }

    _startInactivityWatch();
  }

  void _startInactivityWatch() {
    _inactivityTimer?.cancel();
    if (!_tracking) return;

    _inactivityTimer = Timer(const Duration(minutes: 2), () {
      if (!_tracking) return;
      _autoPausedForInactivity = true;
      _emit(
        _state(
          message:
              'Paused while you are not walking. It will resume automatically when walking is detected.',
        ),
      );
    });
  }

  Future<List<Map<String, dynamic>>> history({int days = 30}) async {
    final safeDays = days.clamp(7, 90);

    // Prefer a dedicated history endpoint when the backend provides it.
    try {
      dynamic response = await ApiClient.instance.get(
        'wellbeing/steps/history?days=$safeDays',
        cacheable: false,
      );

      if (response is Map && response['data'] is List) response = response['data'];
      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    } catch (_) {
      // Fallback below keeps older servers compatible.
    }

    try {
      dynamic response = await ApiClient.instance.get(
        'daily-steps?days=$safeDays',
        cacheable: false,
      );

      if (response is Map && response['data'] is Map) {
        response = response['data']['data'] ?? response['data'];
      } else if (response is Map && response['data'] is List) {
        response = response['data'];
      }

      if (response is List) {
        return response
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      }
    } catch (_) {}

    return <Map<String, dynamic>>[];
  }

  Future<void> _startSensors() async {
    await _stopSensors(keepTracking: true);

    _mode = StepSensorMode.waiting;
    _nativeStepEventSeen = false;
    _nativeBaseline = null;

    _pedometerSub = Pedometer.stepCountStream.listen(
      _onNativeStepCount,
      onError: (_) {
        if (_tracking && !_nativeStepEventSeen) {
          unawaited(_startValidatedMotionFallback());
        }
      },
      cancelOnError: false,
    );

    _fallbackTimer = Timer(const Duration(seconds: 7), () {
      if (_tracking && !_nativeStepEventSeen) {
        unawaited(_startValidatedMotionFallback());
      }
    });
  }

  void _onNativeStepCount(StepCount event) {
    if (!_tracking) {
      return;
    }

    _nativeStepEventSeen = true;
    _markWalkingActivity();

    if (_mode != StepSensorMode.hardware) {
      _mode = StepSensorMode.hardware;
      _nativeBaseline = event.steps;
      _validatedSessionSteps = 0;

      unawaited(_accelerometerSub?.cancel());
      _accelerometerSub = null;

      _emit(
        _state(
          message:
              'Using your phone’s hardware step counter.',
        ),
      );
      return;
    }

    _nativeBaseline ??= event.steps;

    final delta = event.steps - _nativeBaseline!;

    if (delta < 0) {
      // The phone's cumulative sensor can reset after a reboot or sensor
      // restart. Preserve today's app/server total and only establish a new
      // raw sensor baseline.
      _nativeBaseline = event.steps;
      _validatedSessionSteps = 0;
      _emit(
        _state(
          message:
              'Step sensor restarted. Today’s saved step total was preserved.',
        ),
      );
      return;
    }

    _validatedSessionSteps = delta;
    _emit(_state());
    _maybeSync();
  }

  Future<void> _startValidatedMotionFallback() async {
    if (!_tracking || _mode == StepSensorMode.hardware) {
      return;
    }

    if (_accelerometerSub != null) {
      return;
    }

    _mode = StepSensorMode.validatedMotion;
    _resetMotionValidation();

    try {
      _accelerometerSub = accelerometerEventStream(
        samplingPeriod: SensorInterval.gameInterval,
      ).listen(
        _onAccelerometer,
        onError: (_) {
          _mode = StepSensorMode.unavailable;
          _emit(
            _state(
              message:
                  'No supported step or motion sensor was available on this phone.',
            ),
          );
        },
        cancelOnError: false,
      );

      _emit(
        _state(
          message:
              'Using validated walking detection. Isolated hand movements are ignored.',
        ),
      );
    } catch (_) {
      _mode = StepSensorMode.unavailable;
      _emit(
        _state(
          message:
              'No supported step or motion sensor was available on this phone.',
        ),
      );
    }
  }

  void _onAccelerometer(AccelerometerEvent event) {
    if (!_tracking || _mode != StepSensorMode.validatedMotion) {
      return;
    }

    final magnitude = math.sqrt(
      (event.x * event.x) +
          (event.y * event.y) +
          (event.z * event.z),
    );

    _gravityEstimate =
        (0.92 * _gravityEstimate) + (0.08 * magnitude);

    final dynamicAcceleration = magnitude - _gravityEstimate;
    final now = DateTime.now();

    const upperThreshold = 1.45;
    const resetThreshold = 0.30;
    const minCadence = Duration(milliseconds: 300);
    const maxCadence = Duration(milliseconds: 1100);
    const burstTimeout = Duration(milliseconds: 1500);

    if (_peakArmed && dynamicAcceleration > upperThreshold) {
      final previous = _lastCandidateAt;

      if (previous == null ||
          now.difference(previous) > burstTimeout) {
        _candidateBurstCount = 1;
        _acceptedBurstSteps = 0;
      } else {
        final gap = now.difference(previous);

        if (gap >= minCadence && gap <= maxCadence) {
          _candidateBurstCount += 1;
        } else {
          _candidateBurstCount = 1;
          _acceptedBurstSteps = 0;
        }
      }

      _lastCandidateAt = now;
      _peakArmed = false;

      if (_candidateBurstCount >= 4) {
        if (_acceptedBurstSteps == 0) {
          _validatedSessionSteps += _candidateBurstCount;
          _acceptedBurstSteps = _candidateBurstCount;
        } else {
          _validatedSessionSteps += 1;
          _acceptedBurstSteps += 1;
        }

        _markWalkingActivity();
        _emit(_state());
        _maybeSync();
      }
    } else if (!_peakArmed &&
        dynamicAcceleration.abs() < resetThreshold) {
      _peakArmed = true;
    }

    if (_lastCandidateAt != null &&
        now.difference(_lastCandidateAt!) > burstTimeout) {
      _candidateBurstCount = 0;
      _acceptedBurstSteps = 0;
    }
  }

  void _resetMotionValidation() {
    _gravityEstimate = 9.81;
    _peakArmed = true;
    _lastCandidateAt = null;
    _candidateBurstCount = 0;
    _acceptedBurstSteps = 0;
  }

  void _maybeSync() {
    final now = DateTime.now();

    if (_lastSyncAt == null ||
        now.difference(_lastSyncAt!) >= const Duration(seconds: 2)) {
      _lastSyncAt = now;
      unawaited(_syncSafely());
    }
  }

  void _startSyncTimer() {
    _syncTimer?.cancel();

    _syncTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_syncSafely()),
    );
  }

  Future<void> _syncSafely() async {
    try {
      await _sync();
      _serverAvailable = true;
    } catch (_) {
      _serverAvailable = false;
    }

    _emit(_state());
  }

  Future<void> _sync() async {
    _rollOverIfNeeded();
    final total = _serverSteps + _validatedSessionSteps;

    final response = await ApiClient.instance.post(
      'wellbeing/steps/sync',
      <String, dynamic>{
        'steps': total,
        'daily_goal': _dailyGoal,
      },
    );

    final payload = _unwrap(response);
    final serverReturned =
        int.tryParse('${payload['steps'] ?? total}') ?? total;

    _serverSteps =
        serverReturned > total ? serverReturned : total;
    if (payload['distance_m'] != null) {
      _distanceM = int.tryParse('${payload['distance_m']}') ?? _distanceM ?? 0;
    }

    if (_mode == StepSensorMode.hardware &&
        _nativeBaseline != null &&
        _validatedSessionSteps > 0) {
      // Move the hardware baseline forward by the exact number of sensor
      // steps already committed to the daily total. This keeps one continuous
      // daily count across frequent API syncs.
      _nativeBaseline = _nativeBaseline! + _validatedSessionSteps;
    }

    _validatedSessionSteps = 0;
  }

  StepTrackingState _state({String? message}) {
    final total = _serverSteps + _validatedSessionSteps;
    final goal = _dailyGoal;

    return StepTrackingState(
      steps: total,
      dailyGoal: goal,
      isTracking: _tracking,
      progressPercent:
          ((total / goal) * 100).round().clamp(0, 100),
      lastSyncedAt: DateTime.now(),
      serverAvailable: _serverAvailable,
      statusMessage: message,
      sensorMode: _mode,
      distanceM: _distanceM,
    );
  }

  void _emit(StepTrackingState state) {
    if (!_controller.isClosed) {
      _controller.add(state);
    }
  }

  Future<void> _stopSensors({bool keepTracking = false}) async {
    _fallbackTimer?.cancel();
    _fallbackTimer = null;

    _syncTimer?.cancel();
    _syncTimer = null;

    await _pedometerSub?.cancel();
    _pedometerSub = null;

    await _accelerometerSub?.cancel();
    _accelerometerSub = null;

    _nativeStepEventSeen = false;
    _nativeBaseline = null;

    if (!keepTracking) {
      _mode = StepSensorMode.waiting;
    }
  }

  Map<String, dynamic> _unwrap(dynamic response) {
    dynamic value = response;

    if (value is Map && value['data'] is Map) {
      value = value['data'];
    }

    return value is Map
        ? Map<String, dynamic>.from(value)
        : <String, dynamic>{};
  }

  Future<void> dispose() async {
    _midnightTimer?.cancel();
    _midnightTimer = null;

    await _stopSensors();

    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
