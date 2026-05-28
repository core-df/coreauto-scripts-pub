// Copyright Core DF — Apache License 2.0
import 'dart:convert';
import 'dart:io';
import 'package:cawbs/cawbs.dart' as cawbs;

Future<void> main() async {
  final init = await cawbs.init();
  if (init.statusCode != 200) exit(1);

  final event = await cawbs.getEventPayload();
  if (event.statusCode != 200) exit(1);

  var orderId = 'unknown';
  if (event.payload is Map) {
    final p = event.payload as Map;
    orderId = (p['orderId'] ?? p['id'] ?? orderId).toString();
  }

  final ackDir = Platform.environment['EXAMPLE_ACK_DIR'] ?? '/tmp/coreauto-example';
  final ackPath = '$ackDir/$orderId.json';
  final out = {'orderId': orderId, 'ackPath': ackPath};
  final put = await cawbs.putStepPayload(out);
  if (put.statusCode != 200) exit(1);

  print(jsonEncode({'status_code': 200, 'result': out}));
}
