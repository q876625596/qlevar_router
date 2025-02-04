import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qlevar_router/qlevar_router.dart';

import '../helpers.dart';
import '../test_widgets/test_widgets.dart';

List<String> tabs = [
  "test1",
  "test2",
  "test3",
];
const Key _goToDetailskey = Key("GoToDetails");

int counter = 0;
void main() {
  testWidgets('Switch to, ensure page saves the state', (tester) async {
    QR.reset();
    await tester.pumpWidget(AppWrapper([
      QRoute.withChild(
          path: '/home',
          initRoute: '/test1',
          builderChild: (router) => HomeScreen(router: router),
          children: [
            PostRoute().routes(tabs[0]),
            PostRoute().routes(tabs[1]),
            PostRoute().routes(tabs[2]),
          ])
    ], initPath: '/home'));
    await tester.pumpAndSettle();
    expectedPath('/home/test1/grid');
    final indexs = <int>[];
    Future<void> _goToDetails() async {
      final detailsButton = find.byKey(_goToDetailskey);
      await tester.tap(detailsButton);
      await tester.pumpAndSettle();
      indexs.add(QR.params['index']!.asInt!);
    }

    await _goToDetails();
    expect(counter, 1); // First page created
    await tester.tap(find.text('test2'));
    await tester.pumpAndSettle();
    await _goToDetails();
    expect(counter, 2); // second page created
    await tester.tap(find.text('test3'));
    await tester.pumpAndSettle();
    await _goToDetails();
    expect(counter, 3); // third page created
    expect(indexs.length, 3);
    await tester.tap(find.text('test1'));
    await tester.pumpAndSettle();
    expect(counter, 3); // no new page created
    expect(indexs.length, 3);
    expect(indexs[0], QR.params['index']!.asInt!);
    await tester.tap(find.text('test2'));
    await tester.pumpAndSettle();
    expect(counter, 3); // no new page created
    expect(indexs.length, 3);
    expect(indexs[1], QR.params['index']!.asInt!);
    await tester.tap(find.text('test3'));
    await tester.pumpAndSettle();
    expect(counter, 3); // no new page created
    expect(indexs.length, 3);
    expect(indexs[2], QR.params['index']!.asInt!);
  });
}

class PostRoute {
  QRoute routes(String name) => QRoute.withChild(
        path: '/$name',
        initRoute: '/grid',
        name: name,
        middleware: [QMiddlewareBuilder(onEnterFunc: () async => counter++)],
        builderChild: (child) => PostRouteWrapper(child, name),
        children: [
          QRoute(
            name: '$name-grid',
            path: '/grid',
            builder: () => const Text('grid page'),
          ),
          QRoute(
            name: '$name-detail',
            path: '/detail/:index',
            builder: () => const Text('detail page'),
          )
        ],
      );
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key, required this.router}) : super(key: key);
  final QRouter router;
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    widget.router.navigator.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.router,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex:
            tabs.indexWhere((element) => element == widget.router.routeName),
        onTap: (value) => QR.toName(tabs[value],
            pageAlreadyExistAction: PageAlreadyExistAction.BringToTop),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.collections),
            label: 'test1',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: 'test2',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.recommend),
            label: 'test3',
          ),
        ],
      ),
    );
  }
}

class PostRouteWrapper extends StatelessWidget {
  final QRouter router;
  final String name;
  PostRouteWrapper(this.router, this.name);
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text(name),
            TextButton(
                key: _goToDetailskey,
                onPressed: () =>
                    router.navigator.push('/detail/${Random().nextInt(1000)}'),
                child: Text('GoToDetails')),
            Container(
              width: size.width * 0.7,
              height: size.height * 0.7,
              child: router,
            )
          ],
        ),
      ),
    );
  }
}
