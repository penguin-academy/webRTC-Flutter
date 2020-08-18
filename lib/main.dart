/*
 * MIT License
 *
 * Copyright (c) 2020 Nhan Cao
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import 'package:flutter/material.dart';
import 'package:webRTCDemo/pages/webrtc/call_screen.dart';

void main() async {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  GlobalKey<FormState> _homeKey =
      GlobalKey<FormState>(debugLabel: '_homeScreenkey');
  TextEditingController controllerRoomNumber = TextEditingController();
  String roomNumber = '';
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _homeKey,
        backgroundColor: Colors.grey[50],
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                "WebRTC",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 50,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "made simple",
                style: TextStyle(
                    color: Colors.deepPurple,
                    fontSize: 45,
                    fontWeight: FontWeight.bold),
              ),
              SizedBox(
                height: 15,
              ),
              Text(
                "We created a webRTC solution for you, completely open-source, easy to use and handy tutorials so you can learn how to get started.",
                style: TextStyle(fontSize: 17),
                textAlign: TextAlign.center,
              ),
              SizedBox(
                height: 30,
              ),
              Container(
                width: 200,
                child: TextField(
                  decoration: InputDecoration(
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey),
                      ),
                      labelText: "Enter room id e.g. xLw12",
                      labelStyle:
                          TextStyle(fontSize: 18.0, color: Colors.black),
                      border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.red))),
                  style: TextStyle(fontSize: 18.0, color: Colors.black),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.none,
                  controller: controllerRoomNumber,
                ),
              ),
              SizedBox(
                height: 20,
              ),
              RaisedButton(
                color: Colors.white,

                padding: EdgeInsets.symmetric(vertical: 15, horizontal: 95),
                textColor: Theme.of(context).textTheme.button.color,

                onPressed: () {
                  if (controllerRoomNumber.text == null ||
                      controllerRoomNumber.text == "") {
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          CallScreen(roomNumber: controllerRoomNumber.text),
                    ),
                  );
                },

                child: Text(
                  "Live Demo",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 17, color: Colors.deepPurple),
                ),
                // width: MediaQuery.of(context).size.width * 0.20,
              ),
            ],
          ),
        ));
  }
}
