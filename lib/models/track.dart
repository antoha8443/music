class Track {
  final int? id;
  final String title;
  final String artist;
  final int duration;
  final String? filePath;
  final int? folderId; // Связь с папкой

  Track({
    this.id,
    required this.title,
    required this.artist,
    required this.duration,
    this.filePath,
    this.folderId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'duration': duration,
      'filePath': filePath,
      'folderId': folderId,
    };
  }

  factory Track.fromMap(Map<String, dynamic> map) {
    return Track(
      id: map['id'],
      title: map['title'],
      artist: map['artist'],
      duration: map['duration'],
      filePath: map['filePath'],
      folderId: map['folderId'],
    );
  }
}