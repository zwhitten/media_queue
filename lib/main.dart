import 'package:flutter/material.dart';
import 'db.dart';
import 'reorderable_list.dart';

void main() => runApp(new MyApp());

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
        title: 'Media Queue',
        theme: new ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: new AppPage());
  }
}

class AppPage extends StatefulWidget
{
  @override
  AppPageState createState() => new AppPageState();
}

class AppPageState extends State<AppPage>
  with SingleTickerProviderStateMixin{
  DatabaseClient client = new DatabaseClient();

  final List<Tab> myTabs = <Tab> [
    Tab(icon: Icon(Icons.bookmark)),
    Tab(icon: Icon(Icons.live_tv))
  ];

  TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = new TabController(length: myTabs.length, vsync: this);
  }

  @override
  void dispose(){
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return
         new Scaffold(
          appBar: new AppBar(
            bottom: new TabBar(
              controller: _tabController,
              tabs: myTabs,
            ),
            title: new Text("Media Queue"),
          ),
          body: new TabBarView(
              controller: _tabController,
              children: [
            new MediaPage(type: 'book'),
            new MediaPage(type: 'show')
          ]),
          floatingActionButton: new FloatingActionButton(
              onPressed: _newItem, child: new Icon(Icons.add)),
        );
  }

  void _newItem() {
    String type = _tabController.index==0? 'book':'show';
    Navigator
        .of(context)
        .push(new MaterialPageRoute(builder: (BuildContext context) {
      return new Scaffold(
        appBar: new AppBar(
          title:  Text("Add new $type to queue"),
        ),
        body: new MyForm(type: type)
      );
    })).then((val)=> setState((){
      debugPrint("Set state called...");
    }));
  }

  void resetState() {
    debugPrint("Reset called");
    setState(() {});
  }
}

class MyForm extends StatefulWidget {
  MyForm({this.type});
  final String type;
  @override
  MyFormState createState() => new MyFormState(type: type);
}

class MyFormState extends State<MyForm> {
  MyFormState({this.type});
  final String type;
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  Media _mediaInfo = new Media();
  DatabaseClient client = new DatabaseClient();
  void addMedia() {
//    setState(() {
    _mediaInfo.type = this.type;
    _mediaInfo.order = 100;
    client.insert(_mediaInfo);
//    parentReset();
//    });
  }

  @override
  Widget build(BuildContext context) {
    return new Form(
        key: _formKey,
        child: new Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            new TextFormField(
              decoration: new InputDecoration(
                  hintText: 'Moby Dick', labelText: 'Book Title'),
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please Enter a Title';
                }
              },
              onSaved: (String value) {
                this._mediaInfo.title = value;
              },
            ),
            new Text('Notes'),
            new TextFormField(
              onSaved: (String value) {
                this._mediaInfo.notes = value;
              },
            ),
            new Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: new RaisedButton(
                  onPressed: () {
                    if (_formKey.currentState.validate()) {
                      Scaffold.of(context).showSnackBar(
                          new SnackBar(content: new Text("ProcessingData")));
                      _formKey.currentState.save();
                      addMedia();
                      Navigator.pop(context, true);
                    }
                  },
                  child: new Text(
                    'Submit',
                    style: new TextStyle(color: Colors.white),
                  ),
                  color: Colors.blue,
                ))
          ],
        ));
  }
}

class MediaPage extends StatefulWidget {
  const MediaPage({this.type});
  final String type;
  @override
  MediaPageState createState() => new MediaPageState(mediaType: this.type);
}

class MediaPageState extends State<MediaPage> {
  MediaPageState({this.mediaType});
  final String mediaType;
  List<Media> mediaList = <Media>[];
  DatabaseClient client = new DatabaseClient();

  @override
  void initState() {
    debugPrint("initState");
    client.getMediaByType(this.mediaType).then(setMedia);
    super.initState();
  }

  void setMedia(List<Media> list) {
    setState(() {
      this.mediaList = list;
    });
  }

  @override
  void dispose() {
    debugPrint("Dispose");
    super.dispose();
  }

  bool _reorderCallBack(Key item, Key newPosition) {
    int draggingIndex = _indexOfKey(item);
    int newPositionIndex = _indexOfKey(newPosition);

    final Media draggedItem = mediaList[draggingIndex];
    setState(() {
      mediaList.removeAt(draggingIndex);
      mediaList.insert(newPositionIndex, draggedItem);

      int startIndex = newPositionIndex == 0 ? 0 : newPositionIndex - 1;
      for (int i = startIndex; i < mediaList.length; ++i) {
        client.updateOrder(mediaList[i].id, i);
      }
      debugPrint(
          "Reordering " + item.toString() + " -> " + newPosition.toString());
//      client.getMediaByType("book").then(this.displayBooks);
    });
    return true;
  }

  int _indexOfKey(Key key) {
    for (int i = 0; i < mediaList.length; ++i) {
      if (mediaList[i].key == key) return i;
    }
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
            child: ReorderableList(
                onReorder: this._reorderCallBack,
                child: ListView.builder(
                  itemCount: this.mediaList.length,
                  itemBuilder: (BuildContext c, index) => new Item(
                      media: mediaList[index],
                      first: index == 0,
                      last: index == mediaList.length - 1,
                      deleteAction: () => this.deleteItem(mediaList[index].id))
                )
      )
      )

      ],
    );
  }

  void deleteItem(int id) {
    setState(() {
      client.delete(id);
      client.getMediaByType(this.mediaType).then(this.setMedia );
    });
  }
}

class Item extends StatelessWidget {
  Item({this.media, this.first, this.last, this.deleteAction});

  final Media media;
  final bool first;
  final bool last;

  var deleteAction;

  BoxDecoration _buildDecoration(BuildContext context, bool dragging) {
    return BoxDecoration(
        border: Border(
            top: first && !dragging
                ? Divider.createBorderSide(context)
                : BorderSide.none,
            bottom: last && dragging
                ? BorderSide.none
                : Divider.createBorderSide(context)));
  }

  Widget _buildChild(BuildContext context, bool dragging) {
    return GestureDetector(
        onLongPress: () => deleteAction(),
        child: Container(
          height: 50.0,
      decoration:
          BoxDecoration(
              color: dragging ? Colors.lightGreen : Colors.white70,
              border: Border.all(
              color: Colors.lightBlueAccent,
            width: 1.0
          )),
      child: SafeArea(
          top: false,
          bottom: false,
          child: Row(
            children: <Widget>[
              Checkbox(value: false),
              Expanded(child: Text(media.title)),
              Icon(Icons.reorder, color: dragging ? Colors.blue : Colors.grey)
            ],
          )),
      padding: EdgeInsets.symmetric(vertical: 14.0, horizontal: 14.0),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ReorderableItem(
        key: media.key,
        childBuilder: _buildChild,
        decorationBuilder: _buildDecoration);
  }
}
