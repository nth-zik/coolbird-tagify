import 'package:equatable/equatable.dart';

abstract class StorageListEvent extends Equatable {
  const StorageListEvent();

  @override
  List<Object> get props => [];
}

class StorageListInit extends StorageListEvent {
  const StorageListInit();
}

class LoadStorageLocations extends StorageListEvent {
  const LoadStorageLocations();
}
