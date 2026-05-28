// Copyright Core DF — Apache License 2.0
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'result.dart';

class Notifyclient {
  static String _env(String key) => Platform.environment[key] ?? '';

  static Future<Map<String, dynamic>> _postJson(String url, Map<String, dynamic> payload) async {
    try {
      final resp = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      if (resp.statusCode >= 400) {
        return {'status_code': resp.statusCode, 'error': resp.body};
      }
      if (resp.body.isEmpty) return {'status_code': 200};
      try {
        return {'status_code': 200, 'body': jsonDecode(resp.body)};
      } catch (_) {
        return {'status_code': 200, 'body': resp.body};
      }
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }

  static Future<Map<String, dynamic>> Slack(String text, {String? webhookUrl}) async {
    final url = (webhookUrl != null && webhookUrl.isNotEmpty) ? webhookUrl : _env('SLACK_WEBHOOK_URL');
    if (url.isEmpty) return CoreautoResult.missingEnv('SLACK_WEBHOOK_URL');
    return _postJson(url, {'text': text});
  }

  static Future<Map<String, dynamic>> Teams(String text, {String? webhookUrl}) async {
    final url = (webhookUrl != null && webhookUrl.isNotEmpty) ? webhookUrl : _env('TEAMS_WEBHOOK_URL');
    if (url.isEmpty) return CoreautoResult.missingEnv('TEAMS_WEBHOOK_URL');
    return _postJson(url, {
      '@type': 'MessageCard',
      '@context': 'http://schema.org/extensions',
      'text': text,
    });
  }

  static Future<Map<String, dynamic>> PagerDuty(
    String summary, {
    String? routingKey,
    String severity = 'error',
  }) async {
    final key = (routingKey != null && routingKey.isNotEmpty) ? routingKey : _env('PAGERDUTY_ROUTING_KEY');
    if (key.isEmpty) return CoreautoResult.missingEnv('PAGERDUTY_ROUTING_KEY');
    return _postJson('https://events.pagerduty.com/v2/enqueue', {
      'routing_key': key,
      'event_action': 'trigger',
      'payload': {
        'summary': summary,
        'severity': severity,
        'source': 'coreauto-step',
      },
    });
  }

  static Future<Map<String, dynamic>> Email(
    String subject,
    String body,
    String toAddrs, {
    String? fromAddr,
  }) async {
    final host = _env('SMTP_HOST');
    final port = int.tryParse(_env('SMTP_PORT')) ?? 587;
    final user = _env('SMTP_USER');
    final password = _env('SMTP_PASSWORD');
    final sender = (fromAddr != null && fromAddr.isNotEmpty) ? fromAddr : (_env('SMTP_FROM').isNotEmpty ? _env('SMTP_FROM') : user);
    if (host.isEmpty || sender.isEmpty) {
      return CoreautoResult.missingEnv('SMTP_HOST and SMTP_FROM (or from_addr)');
    }
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 60));
      Future<bool> readOk() async {
        final data = await socket.first.timeout(const Duration(seconds: 30));
        return data.isNotEmpty && (data[0] == 50 || data[0] == 51);
      }
      void sendLine(String line) => socket.write('$line\r\n');
      await socket.first;
      sendLine('EHLO coreauto.local');
      if (!await readOk()) return CoreautoResult.transportError('smtp handshake failed');
      if (user.isNotEmpty && password.isNotEmpty) {
        sendLine('STARTTLS');
        await readOk();
      }
      sendLine('MAIL FROM:<$sender>');
      if (!await readOk()) return CoreautoResult.transportError('smtp mail from failed');
      for (final to in toAddrs.split(',')) {
        final addr = to.trim();
        if (addr.isEmpty) continue;
        sendLine('RCPT TO:<$addr>');
        if (!await readOk()) return CoreautoResult.transportError('smtp rcpt failed');
      }
      sendLine('DATA');
      if (!await readOk()) return CoreautoResult.transportError('smtp data failed');
      socket.write('From: $sender\r\nTo: $toAddrs\r\nSubject: $subject\r\n\r\n$body\r\n.');
      if (!await readOk()) return CoreautoResult.transportError('smtp send failed');
      sendLine('QUIT');
      await socket.close();
      return {'status_code': 200};
    } catch (e) {
      return CoreautoResult.transportError(e.toString());
    }
  }
}
