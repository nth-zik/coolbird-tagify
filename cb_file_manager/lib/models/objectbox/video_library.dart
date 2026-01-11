import 'package:objectbox/objectbox.dart';
import '../../objectbox.g.dart';

/// Entity class for storing video libraries in ObjectBox
@Entity()
class VideoLibrary {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Library name
  @Index()
  String name;

  /// Library description (optional)
  String? description;

  /// Library cover image path (optional)
  String? coverImagePath;

  /// Creation timestamp
  DateTime createdAt;

  /// Last modified timestamp
  DateTime modifiedAt;

  /// Library color theme (hex color code, optional)
  String? colorTheme;

  /// Whether this is a system library or user-created
  bool isSystemLibrary;

  /// Creates a new video library
  VideoLibrary({
    required this.name,
    this.description,
    this.coverImagePath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.colorTheme,
    this.isSystemLibrary = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        modifiedAt = modifiedAt ?? DateTime.now();

  /// Updates the modified timestamp
  void updateModifiedTime() {
    modifiedAt = DateTime.now();
  }

  /// Creates a copy of this library with updated fields
  VideoLibrary copyWith({
    String? name,
    String? description,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? colorTheme,
    bool? isSystemLibrary,
  }) {
    return VideoLibrary(
      name: name ?? this.name,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      colorTheme: colorTheme ?? this.colorTheme,
      isSystemLibrary: isSystemLibrary ?? this.isSystemLibrary,
    )..id = id;
  }

  @override
  String toString() {
    return 'VideoLibrary{id: $id, name: $name, description: $description, '
        'createdAt: $createdAt, modifiedAt: $modifiedAt, '
        'isSystemLibrary: $isSystemLibrary}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoLibrary &&
        other.id == id &&
        other.name == name &&
        other.description == description &&
        other.coverImagePath == coverImagePath &&
        other.createdAt == createdAt &&
        other.modifiedAt == modifiedAt &&
        other.colorTheme == colorTheme &&
        other.isSystemLibrary == isSystemLibrary;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      coverImagePath,
      createdAt,
      modifiedAt,
      colorTheme,
      isSystemLibrary,
    );
  }
}
