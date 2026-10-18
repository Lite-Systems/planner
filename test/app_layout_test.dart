import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:planner/core/utils/app_layout.dart';

void main() {
  setUp(() => _LayoutProbe.builds = 0);

  test('AppLayout breakpoints', () {
    expect(const AppLayout(390).isCompact, isTrue);
    expect(const AppLayout(768).isMedium, isTrue);
    expect(const AppLayout(768).isDesktop, isTrue);
    expect(const AppLayout(1280).isExpanded, isTrue);
    expect(const AppLayout(599).isDesktop, isFalse);
  });

  testWidgets('AppLayoutScope skips rebuilds within a breakpoint', (
    tester,
  ) async {
    await tester.pumpWidget(const _ResizeHost(width: 1280));
    expect(_LayoutProbe.builds, 1);

    final host = tester.state<_ResizeHostState>(find.byType(_ResizeHost));
    host.setWidth(1400);
    await tester.pump();
    expect(_LayoutProbe.builds, 1);

    host.setWidth(500);
    await tester.pump();
    expect(_LayoutProbe.builds, 2);
  });
}

class _ResizeHost extends StatefulWidget {
  const _ResizeHost({required this.width});

  final double width;

  @override
  State<_ResizeHost> createState() => _ResizeHostState();
}

class _ResizeHostState extends State<_ResizeHost> {
  late double width = widget.width;
  late final Widget probe = const _LayoutProbe();

  void setWidth(double value) => setState(() => width = value);

  @override
  Widget build(BuildContext context) {
    return MediaQuery(
      data: MediaQueryData(size: Size(width, 800)),
      child: AppLayoutHost(child: probe),
    );
  }
}

class _LayoutProbe extends StatelessWidget {
  const _LayoutProbe();

  static int builds = 0;

  @override
  Widget build(BuildContext context) {
    AppLayout.of(context);
    builds++;
    return const SizedBox.shrink();
  }
}
