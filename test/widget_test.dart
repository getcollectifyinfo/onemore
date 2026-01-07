import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onemore/main.dart';

void main() {
  testWidgets('Game loads smoke test', (WidgetTester tester) async {
    // Build our game and trigger a frame.
    await tester.pumpWidget(GameWidget(game: OneMoreGame()));

    // Verify that game is running (basic check)
    expect(find.byType(GameWidget<OneMoreGame>), findsOneWidget);
  });
}
