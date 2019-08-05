import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dash_chat/dash_chat.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  TextEditingController _editingController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dash Chat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              TextFormField(
                controller: _editingController,
                decoration: InputDecoration(hintText: "Enter Name here..."),
                validator: (val) {
                  if (val.length < 3) {
                    return "Name to short";
                  }
                  return null;
                },
              ),
              SizedBox(
                height: 40.0,
              ),
              FlatButton(
                child: Text("Next"),
                onPressed: () async {
                  if (_formKey.currentState.validate()) {
                    print(_editingController.value.text);
                    try {
                      await FirebaseAuth.instance.signInAnonymously();

                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            username: _editingController.text,
                            uuid: Uuid().v4().toString(),
                          ),
                        ),
                      );
                    } catch (e) {
                      print(e);
                    }
                  }
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String username;
  final String uuid;

  ChatScreen({this.username, this.uuid});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  ChatUser user = ChatUser();

  @override
  void initState() {
    user.name = widget.username;
    user.uid = widget.uuid;
    super.initState();
  }

  void onSend(ChatMessage message) {
    var documentReference = Firestore.instance
        .collection('messages')
        .document(DateTime.now().millisecondsSinceEpoch.toString());

    Firestore.instance.runTransaction((transaction) async {
      await transaction.set(
        documentReference,
        message.toJson(),
      );
    });
  }

  void uploadFile() async {
    File result = await ImagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxHeight: 400,
      maxWidth: 400,
    );

    if (result != null) {
      String id = Uuid().v4().toString();

      final StorageReference storageRef =
          FirebaseStorage.instance.ref().child("chat_images/$id.jpg");

      StorageUploadTask uploadTask = storageRef.putFile(
        result,
        StorageMetadata(
          contentType: 'image/jpg',
        ),
      );
      StorageTaskSnapshot download = await uploadTask.onComplete;

      String url = await download.ref.getDownloadURL();

      ChatMessage message = ChatMessage(text: "", user: user, image: url);

      var documentReference = Firestore.instance
          .collection('messages')
          .document(DateTime.now().millisecondsSinceEpoch.toString());

      Firestore.instance.runTransaction((transaction) async {
        await transaction.set(
          documentReference,
          message.toJson(),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Dash Chat"),
      ),
      body: StreamBuilder(
        stream: Firestore.instance.collection('messages').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).primaryColor),
              ),
            );
          } else {
            List<DocumentSnapshot> items = snapshot.data.documents;
            var messages =
                items.map((i) => ChatMessage.fromJson(i.data)).toList();
            return DashChat(
              user: user,
              messages: messages,
              inputDecoration: InputDecoration(
                hintText: "Message here...",
                border: InputBorder.none,
              ),
              onSend: onSend,
              trailing: <Widget>[
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: uploadFile,
                )
              ],
            );
          }
        },
      ),
    );
  }
}
