import 'dart:async';

import 'package:flutter/material.dart';

import '../services/step_tracking_service.dart';

class DashboardStepsCard extends StatefulWidget {
  const DashboardStepsCard({super.key});

  @override
  State<DashboardStepsCard> createState() => _DashboardStepsCardState();
}

class _DashboardStepsCardState extends State<DashboardStepsCard> {
  final _service = StepTrackingService.instance;
  StepTrackingState? _state;
  bool _loading = true;
  StreamSubscription<StepTrackingState>? _subscription;

  @override
  void initState() {
    super.initState();

    _subscription = _service.stream.listen((value) {
      if (!mounted) return;
      setState(() {
        _state = value;
        _loading = false;
      });
    });

    _load();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final value = await _service.load();
      if (!mounted) return;
      setState(() {
        _state = value;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _state = const StepTrackingState(
          steps: 0,
          dailyGoal: 5000,
          isTracking: false,
          progressPercent: 0,
          serverAvailable: false,
          statusMessage: 'Waiting to connect to step tracking.',
        );
      });
    }
  }

  Future<void> _toggle() async {
    try {
      if (_state?.isTracking == true) {
        await _service.stop();
      } else {
        await _service.start();
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not start step tracking. Allow Physical activity permission and confirm the wellbeing/steps API is deployed.',
          ),
        ),
      );
    }
  }

  String _sensorLabel(StepTrackingState? state) {
    switch (state?.sensorMode) {
      case StepSensorMode.hardware:
        return 'Phone step sensor';
      case StepSensorMode.validatedMotion:
        return 'Validated walking';
      case StepSensorMode.unavailable:
        return 'Sensor unavailable';
      case StepSensorMode.waiting:
      case null:
        return state?.isTracking == true ? 'Detecting sensor' : 'Paused';
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final steps = state?.steps ?? 0;
    final goal = state?.dailyGoal ?? 5000;
    final progress = state?.progressPercent ?? 0;
    final tracking = state?.isTracking ?? false;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_walk_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Today’s Steps',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: tracking
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFF1F5F9),
                  ),
                  child: Text(
                    tracking ? _sensorLabel(state) : 'Paused',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: tracking
                          ? const Color(0xFF047857)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_loading)
              const LinearProgressIndicator(minHeight: 2)
            else ...[
              Text(
                '$steps steps today · $goal daily target',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              LinearProgressIndicator(
                value: progress / 100,
                minHeight: 7,
              ),
              const SizedBox(height: 5),
              Text(
                '$progress% · ${goal - steps > 0 ? goal - steps : 0} remaining',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                ),
              ),
              if ((state?.statusMessage ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 5),
                Text(
                  state!.statusMessage!,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFD97706),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              FilledButton.tonalIcon(
                onPressed: _toggle,
                icon: Icon(
                  tracking
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                ),
                label: Text(
                  tracking ? 'Stop Walking' : 'Start Walking',
                ),
              ),
              const SizedBox(height: 5),
              Text(
                state?.sensorMode == StepSensorMode.validatedMotion
                    ? 'Validated walking mode ignores isolated hand movements and only accepts sustained walking rhythm. Keep My Digital Diary running while this fallback is active.'
                    : 'My Digital Diary counts your active walking session and synchronises the daily total to your account.',
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
