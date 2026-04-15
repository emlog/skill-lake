// 基础 Widget 冒烟测试 - 验证应用能正常启动
import 'package:flutter_test/flutter_test.dart';

import 'package:skill_lake/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // 启动应用，验证不崩溃
    await tester.pumpWidget(const SkillLakeApp());
    expect(find.byType(SkillLakeApp), findsOneWidget);
  });
}
