import 'package:equatable/equatable.dart';

abstract class FolderListEvent extends Equatable {
  const FolderListEvent();

  @override
  List<Object?> get props => [];
}

class FolderListInit extends FolderListEvent {
  const FolderListInit();
}

class FolderListLoad extends FolderListEvent {
  final String path;

  const FolderListLoad(this.path);

  @override
  List<Object> get props => [path];
}

class FolderListFilter extends FolderListEvent {
  final String? fileType;

  const FolderListFilter(this.fileType);

  @override
  List<Object?> get props => [fileType];
}

class AddTagToFile extends FolderListEvent {
  final String filePath;
  final String tag;

  const AddTagToFile(this.filePath, this.tag);

  @override
  List<Object> get props => [filePath, tag];
}

class RemoveTagFromFile extends FolderListEvent {
  final String filePath;
  final String tag;

  const RemoveTagFromFile(this.filePath, this.tag);

  @override
  List<Object> get props => [filePath, tag];
}

class SearchByTag extends FolderListEvent {
  final String tag;

  const SearchByTag(this.tag);

  @override
  List<Object> get props => [tag];
}

class LoadTagsFromFile extends FolderListEvent {
  final String filePath;

  const LoadTagsFromFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class LoadAllTags extends FolderListEvent {
  final String directory;

  const LoadAllTags(this.directory);

  @override
  List<Object> get props => [directory];
}
