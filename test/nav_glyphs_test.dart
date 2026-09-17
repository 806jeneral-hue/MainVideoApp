import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:main_video/ui/shell/nav_glyphs.dart';

void main() {
  testWidgets('every navigation glyph parses and paints', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            for (final kind in NavGlyphKind.values)
              NavGlyph(kind: kind, color: Colors.black, size: 28),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(NavGlyph), findsNWidgets(NavGlyphKind.values.length));
  });
}
