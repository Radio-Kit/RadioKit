import '../models/designer_element.dart';
import '../models/designer_state.dart';
import 'widget_templates.dart';

class ArduinoGenerator {
  static String generate(DesignerState state) {
    final buf = StringBuffer();
    final elements = state.elements;
    final orient = state.isLandscape ? 'landscape' : 'portrait';
    final cw = state.canvasWidth;
    final ch = state.canvasHeight;

    buf.writeln('#include <RadioKit.h>');
    buf.writeln();
    buf.writeln('// UI Layout: ${cw}x$ch ($orient)');
    buf.writeln('// Widget positions use the virtual canvas coordinate system');
    buf.writeln('// (x: 0-$cw, y: 0-$ch)');
    buf.writeln('//');
    buf.writeln('// NOTE: Pins must be assigned manually based on your hardware wiring.');
    buf.writeln('// Widget constructors below do NOT include pin parameters.');
    buf.writeln();

    if (elements.isEmpty) {
      buf.writeln('// No widgets placed on canvas');
      buf.writeln();
    } else {
      buf.writeln('// ─── Widget Declarations ───');
      for (final el in elements) {
        final template = templates[el.type];
        if (template != null) {
          buf.writeln(template(el, 0));
          buf.writeln();
        }
      }
    }

    buf.writeln('void setup() {');
    buf.writeln('  Serial.begin(115200);');
    buf.writeln();
    buf.writeln('  // TODO: Initialize RadioKit with your transport');
    buf.writeln('  // RadioKit.begin(bleTransport);');
    buf.writeln();

    if (elements.isNotEmpty) {
      buf.writeln('  // Widget configuration');
      for (final el in elements) {
        final template = templates[el.type];
        if (template != null) {
          final code = template(el, 0);
          final lines = code.split('\n');
          for (int i = 1; i < lines.length; i++) {
            buf.writeln(lines[i]);
          }
        }
      }
      buf.writeln();
    }

    buf.writeln('}');
    buf.writeln();
    buf.writeln('void loop() {');
    buf.writeln('  RadioKit.update();');
    buf.writeln();

    if (elements.isNotEmpty) {
      buf.writeln('  // Read widget states');
      for (final el in elements) {
        final name = _widgetName(el);
        switch (el.type) {
          case DesignerElementType.button:
            buf.writeln('  if ($name.clicked()) {');
            buf.writeln('    // Button was pressed');
            buf.writeln('  }');
            buf.writeln('  bool ${name}State = $name.get();');
            break;
          case DesignerElementType.slideSwitch:
            buf.writeln('  bool ${name}State = $name.get();');
            break;
          case DesignerElementType.rockerSwitch:
            buf.writeln('  bool ${name}State = $name.get();');
            break;
          case DesignerElementType.slider:
            buf.writeln('  int8_t ${name}Val = $name.get();  // -100 to +100');
            break;
          case DesignerElementType.knob:
            buf.writeln('  int8_t ${name}Val = $name.get();  // -100 to +100');
            break;
          case DesignerElementType.steeringWheel:
            buf.writeln('  int8_t ${name}Val = $name.get();  // -100 to +100');
            break;
          case DesignerElementType.joystick:
            buf.writeln('  int8_t ${name}X = $name.getX();  // -100 to +100');
            buf.writeln('  int8_t ${name}Y = $name.getY();  // -100 to +100');
            break;
          case DesignerElementType.multiButton:
            buf.writeln('  int8_t ${name}Idx = $name.get();  // selected index');
            break;
          case DesignerElementType.multiSelect:
            buf.writeln('  uint8_t ${name}Mask = $name.get();  // bitmask');
            break;
          case DesignerElementType.gasPedal:
            buf.writeln('  int8_t ${name}Val = $name.get();  // -100 to +100');
            break;
          case DesignerElementType.led:
            break;
          case DesignerElementType.display:
            break;
          case DesignerElementType.serialMonitor:
            break;
        }
      }
      buf.writeln();
      buf.writeln('  delay(16);');
    }

    buf.writeln('}');

    return buf.toString();
  }
}

String _widgetName(DesignerElement el) {
  final base = el.type.name;
  return '${base[0].toLowerCase()}${base.substring(1)}_${el.id.hashCode.abs() % 10000}';
}
