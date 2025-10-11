import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../models/playback_settings.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late PlaybackSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = context.read<PlayerProvider>().settings;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Playback Settings',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSpeedControl(),
          const Divider(height: 32),
          _buildLoopSettings(),
          const Divider(height: 32),
          _buildPauseIntervalSetting(),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Apply Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeedControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_settings.playbackSpeed.toStringAsFixed(1)}x',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _settings.playbackSpeed,
                min: 0.5,
                max: 2.0,
                divisions: 15,
                label: '${_settings.playbackSpeed.toStringAsFixed(1)}x',
                onChanged: (value) {
                  setState(() {
                    _settings = _settings.copyWith(playbackSpeed: value);
                  });
                },
              ),
            ),
          ],
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final speed in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
              TextButton(
                onPressed: () {
                  setState(() {
                    _settings = _settings.copyWith(playbackSpeed: speed);
                  });
                },
                child: Text('${speed}x'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoopSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Loop Playback',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Switch(
              value: _settings.loopEnabled,
              onChanged: (value) {
                setState(() {
                  _settings = _settings.copyWith(loopEnabled: value);
                });
              },
            ),
          ],
        ),
        if (_settings.loopEnabled) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Loop Count'),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: _settings.loopCount > 0
                        ? () {
                            setState(() {
                              _settings = _settings.copyWith(
                                loopCount: _settings.loopCount - 1,
                              );
                            });
                          }
                        : null,
                  ),
                  Container(
                    width: 60,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _settings.loopCount == 0 ? '∞' : '${_settings.loopCount}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      setState(() {
                        final newCount = _settings.loopCount == 0 
                            ? 1 
                            : _settings.loopCount + 1;
                        _settings = _settings.copyWith(loopCount: newCount);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final count in [0, 2, 3, 5, 10])
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _settings = _settings.copyWith(loopCount: count);
                    });
                  },
                  child: Text(count == 0 ? '∞' : '$count'),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPauseIntervalSetting() {
    final seconds = _settings.pauseInterval.inSeconds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pause Interval',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            Text(
              '${seconds}s',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Slider(
          value: seconds.toDouble(),
          min: 0,
          max: 10,
          divisions: 20,
          label: '${seconds}s',
          onChanged: (value) {
            setState(() {
              _settings = _settings.copyWith(
                pauseInterval: Duration(seconds: value.round()),
              );
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final sec in [0, 1, 2, 3, 5])
              TextButton(
                onPressed: () {
                  setState(() {
                    _settings = _settings.copyWith(
                      pauseInterval: Duration(seconds: sec),
                    );
                  });
                },
                child: Text('${sec}s'),
              ),
          ],
        ),
      ],
    );
  }

  void _saveSettings() {
    context.read<PlayerProvider>().updateSettings(_settings);
    Navigator.pop(context);
  }
}
