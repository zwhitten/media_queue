import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';

class DatabaseClient{
  static final DatabaseClient _instance = new DatabaseClient.internal();

  factory DatabaseClient() => _instance;
  static Database _db;

  Future<Database> get db async {
    if(_db!=null) {
      return _db;
    }
    _db = await init();
    return _db;
  }
  DatabaseClient.internal();



  init() async{
    Directory path = await getApplicationDocumentsDirectory();
    String dbString = join(path.path, "queue.db");

    var database = await openDatabase(dbString, version: 1, onCreate: this.initTables);
    return database;
  }

  Future initTables(Database db, int version) async{
    await db.execute('''
    create table $mediaTable (
      $columnId integer primary key,
      $columnOrder integer not null,
      $columnTitle text not null,
      $columnType text not null,
      $columnNotes text default null,
      $columnComplete integer default 0
    )
    ''');
  }

  Future<Media> insert(Media media) async {
    var dbClient = await db;
    media.id = await dbClient.insert(mediaTable, media.toMap());
    return media;
  }

  Future<int> updateOrder(int id, int newOrder) async {
    debugPrint("Updating item_id: $id to new position $newOrder");

    var dbClient = await db;
    return await dbClient.update(mediaTable, {
      columnOrder: newOrder
    },
    where: "id = ? ",
    whereArgs: [id]);

  }

  Future<Media> getMedia(int id) async {
    var dbClient = await db;
    List<Map> maps = await dbClient.query(mediaTable,
      columns: [columnId, columnComplete, columnTitle],
      where: "$columnId = ? ",
      whereArgs: [id]);
    if(maps.length > 0) {
      return Media.fromMap(maps.first);
    }
    return null;
  }

  Future<List<Media>> getMediaByType(String type) async {
    final result = <Media>[];
    var dbClient = await db;
    List<Map> resultList = await dbClient.query(mediaTable,
      columns: [columnId, columnTitle, columnComplete, columnNotes, columnOrder, columnType],
      where: "$columnType = ? ",
      whereArgs: [type],
      orderBy: "$columnComplete, $columnOrder asc");

    for(var mapEntry in resultList){
      result.add(Media.fromMap(mapEntry));
    }
    debugPrint("Querying for $type and found "+result.length.toString());
    return result;

  }

  Future<int> delete(int id) async{
    var dbClient = await db;
    return await dbClient.delete(mediaTable, where: "$columnId = ? ", whereArgs: [id]);
  }

  Future<int> update(Media media) async {
    var dbClient = await db;
    return await dbClient.update(mediaTable, media.toMap(),
      where: "$columnId = ? ", whereArgs: [media.id]);
  }

//  Future close() async => database.close();
}

final String mediaTable = "media";
final String columnId = "id";
final String columnOrder = "priority";
final String columnTitle = "title";
final String columnType="type";
final String columnNotes="notes";
final String columnComplete="complete";

class Media {
  int id;
  int order;
  String title;
  String type;
  String notes;
  bool complete;
  Key key;

  Map<String, dynamic> toMap(){
    var map = new Map<String, dynamic>();

    map[columnTitle]= title;
    map[columnType]= type;
    map[columnNotes]= notes;
    map[columnOrder]= order;
    map[columnComplete]= complete == true ? 1 : 0;

    if(id!=null) {
      map[columnId] = id;
    }
    return map;
  }

  Media();

  Media.fromMap(dynamic map){
    id = map[columnId];
    order = map[columnOrder];
    title = map[columnTitle];
    type= map[columnType];
    notes=map[columnNotes];
    complete = map[columnComplete]==1;
    key = ValueKey(id);

  }

}