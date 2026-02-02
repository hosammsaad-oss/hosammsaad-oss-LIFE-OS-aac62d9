class MeetingResult {
  final String summary;
  final List<String> tasks;
  final List<String> decisions;
  final DateTime timestamp;

  MeetingResult({
    required this.summary,
    required this.tasks,
    required this.decisions,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  factory MeetingResult.fromJson(Map<String, dynamic> json) {
    return MeetingResult(
      summary: json['summary'] ?? '',
      tasks: List<String>.from(json['tasks'] ?? []),
      decisions: List<String>.from(json['decisions'] ?? []),
      timestamp: DateTime.now(),
    );
  }
}
