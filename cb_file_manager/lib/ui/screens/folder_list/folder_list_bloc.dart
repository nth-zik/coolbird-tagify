
import 'package:flutter_bloc/flutter_bloc.dart';

import 'folder_list_event.dart';
import 'folder_list_state.dart';

class FolderListBloc extends Bloc<FolderListEvent, FolderListState> {

  @override
  FolderListState get initialState => FolderListState("/");

  @override
  Stream<FolderListState> mapEventToState(FolderListEvent event) {
    // TODO: implement mapEventToState
    throw UnimplementedError();
  }

}