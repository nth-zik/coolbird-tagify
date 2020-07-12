
import 'dart:io';

import 'package:cb_file_manager/helpers/filesystem_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'folder_list_bloc.dart';

class FolderListScreen extends StatelessWidget {

  final String path;
  const FolderListScreen({@required this.path}) : assert(path != null);

  @override
  Widget build(BuildContext context) {
    final FolderListBloc listBloc = BlocProvider.of<FolderListBloc>(context);

    return FutureBuilder<List<FileSystemEntity>>(
        future: getStorageList(),
        builder: (BuildContext context, AsyncSnapshot<List<FileSystemEntity>> snapshot) {
          return Scaffold(body: RefreshIndicator(
            onRefresh: () {
            return Future.delayed(Duration(milliseconds: 100))
                .then((_) => {
                  // change scroll value
                });
            },
            child: NestedScrollView(
            // body: ,
          ),),)
        }
    );
  }

}