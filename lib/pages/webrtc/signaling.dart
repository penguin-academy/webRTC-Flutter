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

import 'dart:async';

import 'package:flutter_webrtc/webrtc.dart';

import 'websocket.dart';

enum SignalingState {
  CallStateNew,
  CallStateRinging,
  CallStateInvite,
  CallStateConnected,
  CallStateBye,
  ConnectionOpen,
  ConnectionClosed,
  ConnectionError,
}

/*
 * callbacks for Signaling API.
 */
typedef void SignalingStateCallback(SignalingState state);
typedef void StreamStateCallback(MediaStream stream);
typedef void OtherEventCallback(dynamic event);
typedef void DataChannelMessageCallback(
    RTCDataChannel dc, RTCDataChannelMessage data);
typedef void DataChannelCallback(RTCDataChannel dc);

class Signaling {
  SimpleWebSocket _socket;
  String remoteUser;
  RTCPeerConnection peerConnection;
  RTCDataChannel dataChannel;
  var _remoteCandidates = [];

  MediaStream _localStream;
  List<MediaStream> _remoteStreams;
  SignalingStateCallback onStateChange;
  StreamStateCallback onLocalStream;
  StreamStateCallback onAddRemoteStream;
  StreamStateCallback onRemoveRemoteStream;
  OtherEventCallback onPeersUpdate;
  OtherEventCallback onEventUpdate;
  DataChannelMessageCallback onDataChannelMessage;
  DataChannelCallback onDataChannel;
  String roomNumber;

  Signaling(this.roomNumber);

  Map<String, dynamic> _iceServers = {
    'iceServers': [
      {"url": "stun:stun.l.google.com:19302"},
      {"url": "stun:stun.stunprotocol.org"},
      {
        "url": "turn:numb.viagenie.ca",
        "credential": 'muazkh',
        "username": 'webrtc@live.com',
      },
    ]
  };

  final Map<String, dynamic> _config = {
    'mandatory': {},
    'optional': [
      {'DtlsSrtpKeyAgreement': true},
    ],
  };

  final Map<String, dynamic> _constraints = {
    'mandatory': {
      'OfferToReceiveAudio': true,
      'OfferToReceiveVideo': true,
    },
    'optional': [],
  };

  final Map<String, dynamic> _dcConstraints = {
    'mandatory': {
      'OfferToReceiveAudio': false,
      'OfferToReceiveVideo': false,
    },
    'optional': [],
  };

  close() {
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }

    if (peerConnection != null) {
      peerConnection.close();
    }
    if (_socket != null) _socket.close();
  }

  void switchCamera() {
    if (_localStream != null) {
      try {
        _localStream.getVideoTracks()[0].switchCamera();
      } catch (err) {
        print(err);
      }
    }
  }

  void bye() {
    emitDisconnectEvent();
    if (_localStream != null) {
      _localStream.dispose();
      _localStream = null;
    }

    if (dataChannel != null) {
      dataChannel.close();
    }
    if (peerConnection != null) {
      peerConnection.close();
    }

    if (this.onStateChange != null) {
      this.onStateChange(SignalingState.CallStateBye);
    }
    _remoteCandidates.clear();
  }

  void onMessage(tag, message) async {
    switch (tag) {
      case 'offer':
        {
          var id = 'caller';
          var sdp = message["sdp"];
          var callerID = message["caller"];
          var media = 'call';

          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }

          var pc = await _createPeerConnection(id, media, false);
          peerConnection = pc;
          await pc.setRemoteDescription(
              RTCSessionDescription(sdp['sdp'], sdp['type']));
          await _createAnswer(id, pc, media, callerID);
          if (this._remoteCandidates.length > 0) {
            _remoteCandidates.forEach((candidate) async {
              await pc.addCandidate(candidate);
            });
            _remoteCandidates.clear();
          }
        }
        break;
      case 'answer':
        {
          var sdp = message["sdp"];
          var pc = peerConnection;
          if (pc != null) {
            await pc.setRemoteDescription(
                RTCSessionDescription(sdp['sdp'], sdp['type']));
          }
        }
        break;
      case 'ice-candidate':
        {
          var candidateMap = message["candidate"];
          if (candidateMap != null) {
            var pc = peerConnection;
            RTCIceCandidate candidate = RTCIceCandidate(
                candidateMap['candidate'],
                candidateMap['sdpMid'],
                candidateMap['sdpMLineIndex']);
            if (pc != null) {
              await pc.addCandidate(candidate);
            } else {
              _remoteCandidates.add(candidate);
            }
          }
        }
        break;
      case 'call partner':
        {
          String peerId = message;
          String media = "video";
          bool useScreen = false;
          remoteUser = message;
          if (this.onStateChange != null) {
            this.onStateChange(SignalingState.CallStateNew);
          }

          _createPeerConnection(peerId, media, useScreen, isHost: true)
              .then((pc) {
            peerConnection = pc;
            if (media == 'data') {
              _createDataChannel(peerId, pc);
            }
            _createOffer(peerId, pc, media);
          });
        }
        break;
      case 'call host':
        {
          remoteUser = message;
        }
        break;
      default:
        break;
    }
  }

  void connect() async {
    var url = 'https://penguin-signaling-server.herokuapp.com/';
    _socket = SimpleWebSocket(url, roomNumber);

    print('connect to $url');

    _socket.onOpen = () {
      print('onOpen');
      this?.onStateChange(SignalingState.ConnectionOpen);
    };

    _socket.onMessage = (tag, message) {
      print('Received data: $tag - $message');
      this.onMessage(tag, message);
    };

    _socket.onClose = (int code, String reason) {
      print('Closed by server [$code => $reason]!');
      if (this.onStateChange != null) {
        this.onStateChange(SignalingState.ConnectionClosed);
      }
    };

    await _socket.connect();
  }

  Future<MediaStream> createStream(media, userScreen) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth':
              '640', // Provide your own width, height and frame rate here
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      }
    };

    MediaStream stream = userScreen
        ? await navigator.getDisplayMedia(mediaConstraints)
        : await navigator.getUserMedia(mediaConstraints);
    if (this.onLocalStream != null) {
      this.onLocalStream(stream);
    }
    return stream;
  }

  _createPeerConnection(id, media, userScreen, {isHost = false}) async {
    if (media != 'data') _localStream = await createStream(media, userScreen);
    RTCPeerConnection pc = await createPeerConnection(_iceServers, _config);
    if (media != 'data') pc.addStream(_localStream);
    pc.onIceCandidate = (candidate) {
      final iceCandidate = {
        'sdpMLineIndex': candidate.sdpMlineIndex,
        'sdpMid': candidate.sdpMid,
        'candidate': candidate.candidate,
      };
      emitIceCandidateEvent(iceCandidate);
    };

    pc.onIceConnectionState = (state) {
      print('onIceConnectionState $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateClosed ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        bye();
      }
    };

    pc.onAddStream = (stream) {
      if (this.onAddRemoteStream != null) this.onAddRemoteStream(stream);
      //_remoteStreams.add(stream);
    };

    pc.onRemoveStream = (stream) {
      if (this.onRemoveRemoteStream != null) this.onRemoveRemoteStream(stream);
      _remoteStreams.removeWhere((it) {
        return (it.id == stream.id);
      });
    };

    pc.onDataChannel = (channel) {
      _addDataChannel(id, channel);
    };

    return pc;
  }

  _addDataChannel(id, RTCDataChannel channel) {
    channel.onDataChannelState = (e) {};
    channel.onMessage = (RTCDataChannelMessage data) {
      if (this.onDataChannelMessage != null)
        this.onDataChannelMessage(channel, data);
    };
    dataChannel = channel;

    if (this.onDataChannel != null) this.onDataChannel(channel);
  }

  _createDataChannel(id, RTCPeerConnection pc, {label: 'fileTransfer'}) async {
    RTCDataChannelInit dataChannelDict = RTCDataChannelInit();
    RTCDataChannel channel = await pc.createDataChannel(label, dataChannelDict);
    _addDataChannel(id, channel);
  }

  _createOffer(String id, RTCPeerConnection pc, String media) async {
    try {
      RTCSessionDescription s =
          await pc.createOffer(media == 'data' ? _dcConstraints : _constraints);
      pc.setLocalDescription(s);

      final sdp = {'sdp': s.sdp, 'type': s.type};
      emitOfferEvent(sdp);
    } catch (e) {
      print(e.toString());
    }
  }

  _createAnswer(String id, RTCPeerConnection pc, media, String callerID) async {
    try {
      RTCSessionDescription s = await pc
          .createAnswer(media == 'data' ? _dcConstraints : _constraints);
      pc.setLocalDescription(s);

      final sdp = {'sdp': s.sdp, 'type': s.type};
      emitAnswerEvent(sdp, callerID);
    } catch (e) {
      print(e.toString());
    }
  }

  _send(event, data) {
    _socket.send(event, data);
  }

  emitOfferEvent(sdp) {
    _send('offer',
        {'caller': _socket.socket.id, "target": remoteUser, 'sdp': sdp});
  }

  emitDisconnectEvent() {
    _send('offer', {
      'caller': _socket.socket.id,
    });
  }

  emitAnswerEvent(sdp, callerID) {
    _send('answer',
        {'sdp': sdp, "target": callerID, "caller": _socket.socket.id});
  }

  emitIceCandidateEvent(candidate) {
    _send('ice-candidate', {'target': remoteUser, 'candidate': candidate});
  }
}
