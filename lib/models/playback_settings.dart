enum PlaybackMode {
  singleSentence,
  fullArticle,
  bookmarkedOnly,
}

class PlaybackSettings {
  final bool loopEnabled;
  final int loopCount; // 0 means infinite
  final Duration pauseInterval; // pause duration between loops
  final double playbackSpeed;
  final PlaybackMode mode;

  PlaybackSettings({
    this.loopEnabled = false,
    this.loopCount = 1,
    this.pauseInterval = const Duration(seconds: 1),
    this.playbackSpeed = 1.0,
    this.mode = PlaybackMode.fullArticle,
  });

  Map<String, dynamic> toJson() => {
        'loopEnabled': loopEnabled,
        'loopCount': loopCount,
        'pauseInterval': pauseInterval.inMilliseconds,
        'playbackSpeed': playbackSpeed,
        'mode': mode.index,
      };

  factory PlaybackSettings.fromJson(Map<String, dynamic> json) =>
      PlaybackSettings(
        loopEnabled: json['loopEnabled'] ?? false,
        loopCount: json['loopCount'] ?? 1,
        pauseInterval: Duration(milliseconds: json['pauseInterval'] ?? 1000),
        playbackSpeed: json['playbackSpeed'] ?? 1.0,
        mode: PlaybackMode.values[json['mode'] ?? 1],
      );

  PlaybackSettings copyWith({
    bool? loopEnabled,
    int? loopCount,
    Duration? pauseInterval,
    double? playbackSpeed,
    PlaybackMode? mode,
  }) {
    return PlaybackSettings(
      loopEnabled: loopEnabled ?? this.loopEnabled,
      loopCount: loopCount ?? this.loopCount,
      pauseInterval: pauseInterval ?? this.pauseInterval,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      mode: mode ?? this.mode,
    );
  }
}
