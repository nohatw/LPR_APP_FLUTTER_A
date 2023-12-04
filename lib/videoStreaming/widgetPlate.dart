import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_test_app/styles/styles.dart';

class WidgetPlateSection extends StatelessWidget {
  final List<Map> plateData;
  final String plateShowMode;
  const WidgetPlateSection({required this.plateData, required this.plateShowMode, super.key});

  String plateShowModeString() {
    String returnString = '';
    if (plateShowMode == 'matched') {
      returnString = '配對 MATCHED';
    } else if (plateShowMode == 'today matched') {
      returnString = '今日配對\nTODAY MATCHED';
    } else if (plateShowMode == 'today record') {
      returnString = '今日紀錄\nTODAY RECORD';
    }

    return returnString;
  }

  List<Widget> listViewChildrenParse() {
    List<Widget> listViewTemp = [];
    listViewTemp.add(
      Container(
        // color: Colors.white,
        decoration: BoxDecoration(
          color: plateShowMode.contains("matched") ? Styles.colorRed : Styles.colorBlue, // Colors.red
          borderRadius: const BorderRadius.all(Radius.circular(5)),
        ),
        margin: const EdgeInsets.only(left: 20, right: 20, top: 5),
        child: Column(
          children: [
            Row(children: [
              Expanded(
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 10),
                      child: Text(
                        plateShowModeString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ],
        ),
      ),
    );

    for (int i = 0; i < plateData.length; i++) {
      // print(plateData[i]['time']);
      // print(plateData[i]['time'].runtimeType);
      listViewTemp.add(WidgetPlate(
        plate: plateData[i]['plate'],
        time: DateFormat('yyyy/MM/dd, hh:mm a')
            .format(DateTime.fromMillisecondsSinceEpoch(((plateData[i]['time'] as double) * 1000).toInt())),
        matched: plateData[i]['matched'],
      ));
    }

    // temp.add(ListView(
    //   children: tempList,
    // ));

    return listViewTemp;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        constraints:
            plateShowMode == 'matched' ? const BoxConstraints(maxHeight: 200) : const BoxConstraints(maxHeight: 400),
        child: ListView(padding: const EdgeInsets.all(0), children: listViewChildrenParse()));
  }
}

class WidgetPlate extends StatelessWidget {
  final String plate;
  final String time;
  final bool matched;
  const WidgetPlate({required this.matched, required this.plate, required this.time, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // color: Colors.white,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.all(Radius.circular(5)),
      ),
      margin: const EdgeInsets.only(left: 20, right: 20, top: 10),
      child: Column(
        children: [
          Row(children: [
            Expanded(
              child: Column(
                children: [
                  const SizedBox(
                    height: 5,
                  ),
                  Text(
                    plate,
                    style: TextStyle(
                      color: matched ? Styles.colorRed : Styles.colorBlue, // Colors.red : Colors.blue,
                      fontSize: 25,
                    ),
                  ),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(
                    height: 5,
                  ),
                ],
              ),
            )
          ]),
        ],
      ),
    );
  }
}
