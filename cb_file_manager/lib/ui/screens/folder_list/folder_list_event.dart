
import 'package:equatable/equatable.dart';
import 'package:simple_permissions/simple_permissions.dart';

abstract class FolderListEvent extends Equatable {
  const FolderListEvent();

  @override
  List<Object> get props => [];
}

class FolderListInit extends FolderListEvent {
  const FolderListInit();
}