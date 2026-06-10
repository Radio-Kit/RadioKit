import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets_example/main.dart';

void main() {
  testWidgets('App loads without errors', (WidgetTester tester) async {
    await tester.pumpWidget(const ExampleApp());
    expect(find.text('CONTROL_SYS_V1.0'), findsOneWidget);
  });
}
