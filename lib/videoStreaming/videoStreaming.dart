import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test_app/styles/styles.dart';
import 'package:flutter_test_app/constants/constants.dart';

import 'package:flutter/foundation.dart';
import 'package:rtmp_broadcaster/camera.dart';

import 'widgetPlate.dart';

import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:just_audio/just_audio.dart';

class VideoStream extends StatefulWidget {
  final List<CameraDescription> cameras;

  const VideoStream({
    Key? key,
    required this.cameras,
  }) : super(key: key);

  @override
  State<VideoStream> createState() => _VideoStreamState();
}

class _VideoStreamState extends State<VideoStream> {
  // Camera
  late CameraController _cameraController;
  late Future<void> _futureCameraControllerInitialized;
  StreamController streamControllerCamera = StreamController.broadcast();
  bool _cameraImageStreamStarted = false;

  void _cameraControllerInit() {
    _cameraController = CameraController(
      widget.cameras.first,
      ResolutionPreset.medium, //.max, //.medium,
    );
    // Next, initialize the controller. This returns a Future.
    _futureCameraControllerInitialized = _cameraController.initialize().then((value) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            debugPrint('Camera Error: CameraAccessDenied');
            break;
          default:
            // Handle other errors here.
            debugPrint('Camera Error: ${e.code}');
            break;
        }
      }
    });
  }

  void _cameraControllerDispose() {
    _cameraController.dispose();
  }

  // bool _cameraStreamSendLocked = false;
  void _cameraControllerImageStreamStart() async {
    try {
      // Ensure that the camera is initialized.
      await _futureCameraControllerInitialized;

      await _cameraController.startVideoStreaming(Constants.urlRtmp);

      _cameraImageStreamStarted = true;
      streamControllerCamera.sink.add(true);

      dataModeMatchedLiveSetMode();
      timerPlateDataFetch = Timer.periodic(const Duration(seconds: 1), (Timer t) => dataModeMatchedLive());
      timerPlateDataFetchOrganize =
          Timer.periodic(const Duration(seconds: 10), (Timer t) => dataModeMatchedLiveOrganize());
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void _cameraControllerImageStreamStop() async {
    try {
      // Ensure that the camera is initialized.
      await _futureCameraControllerInitialized;

      await _cameraController.stopVideoStreaming();

      timerPlateDataFetchOrganize?.cancel();
      timerPlateDataFetch?.cancel();
      timerPlateDataEmpty?.cancel();
      plateAudioPlayer.stop();

      _cameraImageStreamStarted = false;
      streamControllerCamera.sink.add(false);

      dataModeClose();
      setState(() {});
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // Data

  StreamController streamControllerPlate = StreamController.broadcast();
  bool plateSectionShow = false;
  String plateShowMode = '';
  Timer? timerPlateDataFetch;
  Timer? timerPlateDataFetchOrganize;
  Timer? timerPlateDataEmpty;
  final plateAudioPlayer = AudioPlayer();
  bool plateAudioPlayerPlaying = false;
  List<Map> plateDataToday = [];
  List<Map> plateDataLive = [
    {'matched': true, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
    {'matched': false, 'plate': 'ABC-1234', 'time': 1703345663.123},
  ];

  void dataModeMatchedLive() async {
    // plateShowMode = 'matched';

    // get and update data via websocket stream
    var plateDataTemp = await dataFetch();

    // reset hiding timer if keep fetching something
    // clear plateDataLive if keep fetching nothing
    if (plateDataTemp.isNotEmpty) {
      timerPlateDataEmpty?.cancel();
      timerPlateDataEmpty = Timer.periodic(const Duration(seconds: 300), (Timer timer) {
        debugPrint('timerPlateDataEmpty');
        plateDataLive = [];
      });
    }

    // insert the elements that are not yet in the showing list
    // debugPrint('plateDataLive: $plateDataLive');
    // debugPrint('plateDataTemp: $plateDataTemp');
    // debugPrint('${plateDataLive.length}');
    plateDataLive.insertAll(
      0,
      plateDataTemp.where(
        (element) {
          bool toReturn = true;
          plateDataLive.forEach((e) {
            if (mapEquals(e, element)) {
              toReturn = false;
            } else {
              // toReturn = true;
            }
          });
          return toReturn;
        },
      ).toList(),
    );
    streamControllerPlate.sink.add(true);

    // but still playing the sound even if not added to the showing list(because it's already in the list)
    plateDataTemp = plateDataTemp.where((element) => element['matched'] == true).toList();
    if (plateDataTemp.where((element) => element['matched'] == true).toList().isNotEmpty) {
      // if (plateDataTemp.isNotEmpty) {
      debugPrint('true matched');
      try {
        if (plateAudioPlayerPlaying == false) {
          plateAudioPlayerPlaying = true;
          await plateAudioPlayer.seek(Duration.zero);
          await plateAudioPlayer.play(); // 沒有 loop 才能等到 await 結束
          debugPrint('plateAudioPlayer played');
          plateAudioPlayer.stop();
          debugPrint('plateAudioPlayer stopped');
          plateAudioPlayerPlaying = false;
        } else {
          debugPrint('plateAudioPlayer playing');
        }
      } catch (e) {
        debugPrint('plateAudioPlayer: $e.toString()');
      }
    }
  }

  // separate to set it one time only
  void dataModeMatchedLiveSetMode() async {
    plateShowMode = 'matched';
  }

  // organize every 10 seconds, remove unmatched plate
  void dataModeMatchedLiveOrganize() async {
    debugPrint('dataModeMatchedLiveOrganize');
    plateDataLive = plateDataLive.where((element) => element['matched'] == true).toList();
  }

  void dataModeMatchedToday() async {
    plateShowMode = 'today matched';

    // get and update data once
    var plateDataTemp = await dataFetch();
    plateDataToday = plateDataTemp.where((element) => element['matched'] == true).toList();
    // print(plateData);

    plateSectionShow = true;
    streamControllerPlate.sink.add(true);
  }

  Future<void> dataModeRecordToday() async {
    plateShowMode = 'today record';

    // get and update data once
    plateDataToday = await dataFetch();
    // print(plateData);

    plateSectionShow = true;
    streamControllerPlate.sink.add(true);
  }

  Future<void> dataModeClose() async {
    plateSectionShow = false;
    if (_cameraImageStreamStarted) {
      plateShowMode = 'matched';
    } else {
      plateShowMode = '';
    }
    streamControllerPlate.sink.add(true);
  }

  int workAfter = 0;
  Future<List<Map>> dataFetch() async {
    debugPrint('dataFetch workAfter: $workAfter');
    var url = Uri.http(Constants.urlData, '/api/work', {'camera': '4', 'after': '$workAfter'});
    var response;
    try {
      response = await http.get(url).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          dataFetchFailed();
          return http.Response('Error', 408);
        },
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        var responseDataPlate = (responseData['res']['items'] as List).cast<Map>();

        workAfter += responseData['res']['count'] as int;

        // debugPrint(response.body);
        // debugPrint(responseData);
        // debugPrint(responseData['res']);
        // debugPrint('${responseDataPlate.length}');

        return responseDataPlate;
      } else {}
    } catch (e) {
      debugPrint(e.toString());
      dataFetchFailed();
    }

    return [];
  }

  void dataFetchFailed() async {
    final scaffold = ScaffoldMessenger.of(context);
    scaffold.showSnackBar(
      SnackBar(
        content: const Text('伺服器連線失敗！'),
        action: SnackBarAction(label: 'OK', onPressed: scaffold.hideCurrentSnackBar),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    _cameraControllerInit();

    plateAudioPlayer.setAsset('assets/beep.mp3');
    // plateAudioPlayer.setLoopMode(LoopMode.one);
  }

  @override
  void dispose() {
    _cameraControllerDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Live Video"),
      // ),
      body: Stack(
        children: [
          FutureBuilder(
            future: _futureCameraControllerInitialized,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                // If the Future is complete, display the preview.
                return CameraPreview(_cameraController);
              } else {
                // Otherwise, display a loading indicator.
                return const Center(child: CircularProgressIndicator());
              }
            },
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Part
              Column(
                children: [
                  const SizedBox(
                    height: 30,
                  ),
                  // Closing Button for today XXX
                  StreamBuilder(
                    stream: streamControllerPlate.stream,
                    builder: (context, snapshot) {
                      if (plateSectionShow && plateShowMode.contains('today')) {
                        // (plateShowMode.contains('today')) {
                        return Container(
                          height: 20,
                          margin: const EdgeInsets.only(left: 20),
                          alignment: Alignment.centerLeft,
                          child: ElevatedButton(
                            onPressed: () async {
                              await dataModeClose();
                            },
                            style: ElevatedButton.styleFrom(
                                backgroundColor: plateShowMode == 'today record' ? Styles.colorBlue : Styles.colorRed),
                            child: const Text('X'),
                          ),
                        );
                      } else {
                        return const SizedBox(
                          height: 1,
                        );
                      }
                    },
                  ),
                  StreamBuilder(
                    stream: streamControllerPlate.stream,
                    builder: (context, snapshot) {
                      if (plateShowMode.contains('today')) {
                        if (plateSectionShow) {
                          return WidgetPlateSection(plateData: plateDataToday, plateShowMode: plateShowMode);
                        } else {
                          return const SizedBox(
                            height: 1,
                          );
                        }
                      } else {
                        if (_cameraImageStreamStarted) {
                          return WidgetPlateSection(plateData: plateDataLive, plateShowMode: plateShowMode);
                        } else {
                          return const SizedBox(
                            height: 1,
                          );
                        }
                      }
                    },
                  ),
                  // WidgetPlateSection(plateData: plateData, showMode: "matched"),
                  // WidgetPlate(matched: false, plate: "ABC-1234", time: "2023-12-23 23:34:23"),
                  // WidgetPlate(matched: true, plate: "ABC-1234", time: "2023-12-23 23:34:23")
                ],
              ),
              // Bottom Part
              Column(
                children: [
                  StreamBuilder(
                    stream: streamControllerCamera.stream,
                    initialData: _cameraImageStreamStarted,
                    builder: (context, snapshot) {
                      return _cameraImageStreamStarted
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _cameraControllerImageStreamStop,
                                  style: Styles.elevatedButtonStyleTransparent,
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/camera-circle-icon-225x225.png',
                                        height: 50,
                                      ),
                                      const Text("停止 Stop"),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ElevatedButton(
                                  onPressed: _cameraControllerImageStreamStart,
                                  style: Styles.elevatedButtonStyleTransparent,
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/camera-circle-icon-225x225.png',
                                        height: 50,
                                      ),
                                      const Text("辨識 Scan"),
                                    ],
                                  ),
                                ),
                              ],
                            );
                    },
                  ),
                  StreamBuilder(
                    stream: streamControllerCamera.stream,
                    initialData: _cameraImageStreamStarted,
                    builder: (context, snapshot) {
                      return _cameraController.value.isStreamingVideoRtmp ?? false
                          ? const Text(
                              "✅ Streaming Started", //🟢 WebSocket Server Connected
                              style: TextStyle(fontSize: 8, color: Colors.white),
                              textAlign: TextAlign.center,
                            )
                          : const Text(
                              "❌ Streaming Stopped", // 🔴🔵❎ WebSocket Server Disconnected
                              style: TextStyle(fontSize: 8, color: Colors.white),
                              textAlign: TextAlign.center,
                            );
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            await dataModeRecordToday();
                          },
                          // style: Styles.buttonStyle,
                          style: ElevatedButton.styleFrom(backgroundColor: Styles.colorBlue), // Colors.blue
                          child: const Text("紀錄 Record"),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: dataModeMatchedToday,
                          // style: Styles.buttonStyle,
                          style: ElevatedButton.styleFrom(backgroundColor: Styles.colorRed), // Colors.red
                          child: const Text("配對 Matched"),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/logo-l.png',
                        height: 30,
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              )
            ],
          ),
        ],
      ),
    );
  }
}
