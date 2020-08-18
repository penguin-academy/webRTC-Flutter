import 'dart:core';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/webrtc.dart';

import 'signaling.dart';

class CallScreen extends StatefulWidget {
  CallScreen({Key key, @required this.roomNumber}) : super(key: key);
  final String roomNumber;
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  Signaling _signaling;
  GlobalKey<FormState> _callScreenKey =
      GlobalKey<FormState>(debugLabel: '_callScreenkey');
  RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  bool _inCalling = false;

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = Signaling(widget.roomNumber)..connect();

      _signaling.onStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.CallStateNew:
            this.setState(() {
              _inCalling = true;
            });
            break;
          case SignalingState.CallStateBye:
            this.setState(() {
              _localRenderer.srcObject = null;
              _remoteRenderer.srcObject = null;
              _inCalling = false;
            });
            break;
          case SignalingState.CallStateInvite:
          case SignalingState.CallStateConnected:
          case SignalingState.CallStateRinging:
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      _signaling.onLocalStream = ((stream) {
        _localRenderer.srcObject = stream;
      });

      _signaling.onAddRemoteStream = ((stream) {
        _remoteRenderer.srcObject = stream;
      });

      _signaling.onRemoveRemoteStream = ((stream) {
        _remoteRenderer.srcObject = null;
      });
    }
  }

  _hangUp() {
    if (_signaling != null) {
      _signaling.bye();
    }

    Navigator.of(context).pop();
  }

  _switchCamera() {
    _signaling.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _callScreenKey,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: _inCalling
          ? Padding(
              padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      child: const Icon(Icons.arrow_back),
                      onPressed: _hangUp,
                    ),
                    FloatingActionButton(
                      child: const Icon(Icons.switch_camera),
                      onPressed: _switchCamera,
                    ),
                    FloatingActionButton(
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                  ]),
            )
          : null,
      body: _inCalling
          ? OrientationBuilder(builder: (context, orientation) {
              return Container(
                child: Stack(children: <Widget>[
                  Positioned(
                      left: 0.0,
                      right: 0.0,
                      top: 0.0,
                      bottom: 0.0,
                      child: Container(
                        margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: RTCVideoView(_remoteRenderer),
                        decoration: BoxDecoration(color: Colors.black54),
                      )),
                  Positioned(
                    left: 20.0,
                    bottom: 20.0,
                    child: Container(
                      width: orientation == Orientation.portrait ? 90.0 : 120.0,
                      height:
                          orientation == Orientation.portrait ? 120.0 : 90.0,
                      child: RTCVideoView(_localRenderer),
                      decoration: BoxDecoration(color: Colors.black54),
                    ),
                  ),
                ]),
              );
            })
          : Center(
              child: Container(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Room name: ${widget.roomNumber}"),
                    SizedBox(
                      height: 10,
                    ),
                    Text("Waiting for peers to connect..."),
                  ],
                ),
              ),
            ),
    );
  }
}
