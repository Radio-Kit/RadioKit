import '../../models/widget_registry.dart';
import 'button_definitions.dart';
import 'slider_definitions.dart';
import 'display_definitions.dart';

void registerDefaultWidgets() {
  final registry = WidgetRegistry.instance;

  // Buttons
  registry.register(ButtonWidgetDefinition());
  registry.register(SlideSwitchWidgetDefinition());
  registry.register(RockerSwitchWidgetDefinition());

  // Sliders & Controls
  registry.register(SliderWidgetDefinition());
  registry.register(KnobWidgetDefinition());
  registry.register(SteeringWheelWidgetDefinition());
  registry.register(GasPedalWidgetDefinition());

  // Display & Multi
  registry.register(JoystickWidgetDefinition());
  registry.register(MultiButtonWidgetDefinition());
  registry.register(MultiSelectWidgetDefinition());
  registry.register(LedWidgetDefinition());
  registry.register(TextWidgetDefinition());
  registry.register(SerialMonitorWidgetDefinition());
}
