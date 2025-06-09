import 'dart:convert';
import 'package:pocketbase/pocketbase.dart';

enum RivalResult { win, draw, lose }

class RivalDayResult {
  final RivalResult result;
  final double myRatio;
  final double enemyRatio;
  final int myDone;
  final int enemyDone;

  RivalDayResult(
      {required this.result,
      required this.myRatio,
      required this.enemyRatio,
      required this.myDone,
      required this.enemyDone});
}

class RivalRequest {
  String id;
  DateTime start;
  DateTime end;

  String friendID;
  bool isAccepted;
  String senderID;
  Map<String, dynamic> metadata;
  DateTime? created;

  RivalRequest({
    required this.id,
    required this.start,
    required this.end,
    required this.friendID,
    required this.senderID,
    required this.metadata,
    this.isAccepted = false,
    this.created,
  });

  @override
  String toString() {
    return jsonEncode({
      "id": id,
      "start": start.toIso8601String(),
      "end": end.toIso8601String(),
      "friendID": friendID,
      "isAccepted": isAccepted,
      "senderID": senderID,
      "metadata": metadata,
      "created": created?.toIso8601String(),
    });
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "start": start.toIso8601String(),
      "end": end.toIso8601String(),
      "friendID": friendID,
      "isAccepted": isAccepted,
      "senderID": senderID,
      "metadata": metadata,
      "created": created?.toIso8601String(),
    };
  }

  factory RivalRequest.fromRecord(RecordModel record) {
    return RivalRequest(
      id: record.data["id"],
      start: DateTime.parse(record.data["start"]),
      end: DateTime.parse(record.data["end"]),
      friendID: record.data["friend"],
      isAccepted: record.data["isAccepted"],
      senderID: record.data["sender"],
      metadata: record.data["metadata"] as Map<String, dynamic>,
      created: DateTime.parse(record.data["created"]),
    );
  }
}
