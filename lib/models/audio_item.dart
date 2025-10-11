class AudioItem {
  final String id;
  final String name;
  final String audioPath;
  final String? transcriptPath;
  final DateTime addedDate;
  final int totalDuration; // in seconds

  AudioItem({
    required this.id,
    required this.name,
    required this.audioPath,
    this.transcriptPath,
    required this.addedDate,
    this.totalDuration = 0,
  });

  bool get hasTranscript => transcriptPath != null && transcriptPath!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'audioPath': audioPath,
        'transcriptPath': transcriptPath,
        'addedDate': addedDate.toIso8601String(),
        'totalDuration': totalDuration,
      };

  factory AudioItem.fromJson(Map<String, dynamic> json) => AudioItem(
        id: json['id'],
        name: json['name'],
        audioPath: json['audioPath'],
        transcriptPath: json['transcriptPath'],
        addedDate: DateTime.parse(json['addedDate']),
        totalDuration: json['totalDuration'] ?? 0,
      );

  AudioItem copyWith({
    String? id,
    String? name,
    String? audioPath,
    String? transcriptPath,
    DateTime? addedDate,
    int? totalDuration,
  }) {
    return AudioItem(
      id: id ?? this.id,
      name: name ?? this.name,
      audioPath: audioPath ?? this.audioPath,
      transcriptPath: transcriptPath ?? this.transcriptPath,
      addedDate: addedDate ?? this.addedDate,
      totalDuration: totalDuration ?? this.totalDuration,
    );
  }
}
