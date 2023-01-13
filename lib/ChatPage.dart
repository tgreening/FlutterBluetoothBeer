import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final BluetoothDevice server;

  const ChatPage({required this.server});

  @override
  _ChatPage createState() => new _ChatPage();
}

class Reading {
  double reading = 0.0;
  DateTime time = DateTime.now();

  Reading(currReading) {
    this.reading = currReading;
    this.time = DateTime.now();
  }
}

class _ChatPage extends State<ChatPage> {
  static final clientID = 0;
  BluetoothConnection? connection;

  List<Reading> one = List<Reading>.empty(growable: true);
  List<Reading> two = List<Reading>.empty(growable: true);
  String _messageBuffer = '';
  ChartSeriesController? _chartOneSeriesController;
  ChartSeriesController? _chartTwoSeriesController;

  final TextEditingController textEditingController =
      new TextEditingController();
  final ScrollController listScrollController = new ScrollController();

  bool isConnecting = true;
  bool get isConnected => (connection?.isConnected ?? false);

  bool isDisconnecting = false;

  @override
  void initState() {
    super.initState();

    one = [
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0)
    ];
    two = [
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0),
      Reading(60.0)
    ];

    BluetoothConnection.toAddress(widget.server.address).then((_connection) {
      print('Connected to the device');
      connection = _connection;
      setState(() {
        isConnecting = false;
        isDisconnecting = false;
      });

      connection!.input!.listen(_onDataReceived).onDone(() {
        // Example: Detect which side closed the connection
        // There should be `isDisconnecting` flag to show are we are (locally)
        // in middle of disconnecting process, should be set before calling
        // `dispose`, `finish` or `close`, which all causes to disconnect.
        // If we except the disconnection, `onDone` should be fired as result.
        // If we didn't except this (no flag set), it means closing by remote.
        if (isDisconnecting) {
          print('Disconnecting locally!');
          Navigator.of(context).pop();
        } else {
          print('Disconnected remotely!');
          Navigator.of(context).pop();
        }
        if (this.mounted) {
          setState(() {});
        }
      });
    }).catchError((error) {
      print('Cannot connect, exception occured');
      print(error);
    });
  }

  @override
  void dispose() {
    // Avoid memory leak (`setState` after dispose) and disconnect
    if (isConnected) {
      isDisconnecting = true;
      connection?.dispose();
      connection = null;
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
            child: Column(children: [
          SfCartesianChart(primaryXAxis: CategoryAxis(), series: <ChartSeries>[
            // Initialize line series
            LineSeries<Reading, String>(
                onRendererCreated: (ChartSeriesController controller) {
                  _chartOneSeriesController = controller;
                },
                dataSource: one,
                xValueMapper: (Reading readings, _) =>
                    DateFormat.ms().format(readings.time),
                yValueMapper: (Reading readings, _) => readings.reading)
          ]),
          SfCartesianChart(primaryXAxis: CategoryAxis(), series: <ChartSeries>[
            // Initialize line series
            LineSeries<Reading, String>(
                onRendererCreated: (ChartSeriesController controller) {
                  _chartOneSeriesController = controller;
                },
                dataSource: two,
                xValueMapper: (Reading readings, _) =>
                    DateFormat.ms().format(readings.time),
                yValueMapper: (Reading readings, _) => readings.reading)
          ]),
          Container(
              margin: const EdgeInsets.only(left: 16.0),
              child: Column(children: [
                TextField(
                  style: const TextStyle(fontSize: 15.0),
                  controller: textEditingController,
                  decoration: InputDecoration.collapsed(
                    hintText: isConnecting
                        ? 'Wait until connected...'
                        : isConnected
                            ? 'Type your message...'
                            : 'Chat got disconnected',
                    hintStyle: const TextStyle(color: Colors.grey),
                  ),
                  enabled: isConnected,
                ),
                IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: isConnected
                        ? () => _sendMessage(textEditingController.text)
                        : null),
              ])),
        ])),
      ),
    );
  }

  void _onDataReceived(Uint8List data) {
    // Allocate buffer for parsed data

    Uint8List buffer = Uint8List(data.length);
    int bufferIndex = buffer.length;

    // Apply backspace control character

    for (int i = data.length - 1; i >= 0; i--) {
      buffer[--bufferIndex] = data[i];
    }

    // Create message if there is new line character
    String dataString = String.fromCharCodes(buffer);
    int index = buffer.indexOf(13);
    if (~index != 0) {
      setState(() {
        final Map<String, dynamic> decoded =
            jsonDecode(_messageBuffer + dataString);
        one.add(
          Reading(decoded['sensors'][0]["temperature"]),
        );
        two.add(
          Reading(decoded['sensors'][1]["temperature"]),
        );
        if (one.length > 6) {
          one.removeAt(0);
          two.removeAt(0);
          _chartOneSeriesController?.updateDataSource(
            updatedDataIndexes: <int>[
              one!.length - 1,
              one!.length - 2,
              one!.length - 3,
              one!.length - 4,
              one!.length - 5
            ],
          );
          _chartTwoSeriesController?.updateDataSource(
            updatedDataIndexes: <int>[
              two!.length - 1,
              two!.length - 2,
              two!.length - 3,
              one!.length - 4,
              two!.length - 5
            ],
          );
        } else {
          _chartOneSeriesController?.updateDataSource(
            addedDataIndexes: <int>[one!.length - 1],
          );
          _chartTwoSeriesController?.updateDataSource(
            addedDataIndexes: <int>[two!.length - 1],
          );
        }
        _messageBuffer = '';
      });
    } else {
      _messageBuffer += dataString;
    }
  }

  void _sendMessage(String text) async {
    text = text.trim();
    textEditingController.clear();

    if (text.length > 0) {
      try {
        connection!.output.add(Uint8List.fromList(utf8.encode(text + "\r\n")));
        await connection!.output.allSent;

        setState(() {
          //messages.add(_Message(clientID, text));
        });

        Future.delayed(Duration(milliseconds: 333)).then((_) {
          listScrollController.animateTo(
              listScrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 333),
              curve: Curves.easeOut);
        });
      } catch (e) {
        // Ignore error, but notify state
        setState(() {});
      }
    }
  }
}
