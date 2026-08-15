import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/screens/designer/codegen/json_arduino_generator.dart';

void main() {
  test('generate RADIOKIT.h for RC_UI design', () {
    final src = File('/tmp/rc_ui_design.json');
    if (!src.existsSync()) return;
    final outDir = Directory('/tmp/opencode/RCUITest');
    outDir.createSync(recursive: true);

    final design = jsonDecode(src.readAsStringSync()) as Map<String, dynamic>;

    final features = design['features'] as Map<String, dynamic>? ?? {};
    features['ota'] = false;
    features['filesystem'] = false;
    design['features'] = features;

    final code = JsonArduinoGenerator.generate(design);

    final jsonBlock = const JsonEncoder.withIndent('  ')
        .convert(design)
        .replaceAll(RegExp(r'^', multiLine: true), '  ');

    final header = StringBuffer()
      ..writeln('/*__RADIOKIT_Designer_Config__')
      ..write(jsonBlock)
      ..writeln()
      ..writeln('RADIOKIT_Designer_Config__*/')
      ..writeln()
      ..write(code);

    final out = File('${outDir.path}/RADIOKIT.h');
    out.writeAsStringSync(header.toString());
    // ignore: avoid_print
    print('WROTE ${out.path} (${out.lengthSync()} bytes)');
    // ignore: avoid_print
    print('----- GENERATED CODE -----');
    // ignore: avoid_print
    print(code);
  });
}