import 'package:objectbox/objectbox.dart';

/// Entity class for storing video library file associations in ObjectBox
@Entity()
class VideoLibraryFile {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Video Library ID this file belongs to
  @Index()
  int videoLibraryId;

  /// Full path to the video file
  @Index()
  String filePath;

  /// When this file was added to the library
  DateTime addedAt;

  /// Optional caption or description
  String? caption;

  /// Order index for manual sorting
  int orderIndex;

  /// Creates a new video library file association
  VideoLibraryFile({
    required this.videoLibraryId,
    required this.filePath,
    DateTime? addedAt,
    this.caption,
    this.orderIndex = 0,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Creates a copy of this file with updated fields
  VideoLibraryFile copyWith({
    int? videoLibraryId,
    String? filePath,
    DateTime? addedAt,
    String? caption,
    int? orderIndex,
  }) {
    return VideoLibraryFile(
      videoLibraryId: videoLibraryId ?? this.videoLibraryId,
      filePath: filePath ?? this.filePath,
      addedAt: addedAt ?? this.addedAt,
      caption: caption ?? this.caption,
      orderIndex: orderIndex ?? this.orderIndex,
    )..id = id;
  }

  @override
  String toString() {
    return 'VideoLibraryFile{id: $id, videoLibraryId: $videoLibraryId, '
        'filePath: $filePath, addedAt: $addedAt}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoLibraryFile &&
        other.id == id &&
        other.videoLibraryId == videoLibraryId &&
        other.filePath == filePath &&
        other.addedAt == addedAt &&
        other.caption == caption &&
        other.orderIndex == orderIndex;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      videoLibraryId,
      filePath,
      addedAt,
      caption,
      orderIndex,
    );
  }
}
