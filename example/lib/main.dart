import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_chat_list_view/flutter_chat_list_view.dart';

const numberOfItems = 1;
const scrollDuration = Duration(milliseconds: 100);

const randomMax = 1 << 32;
final colorGenerator = Random(42490823);

void main() {
  runApp(ChatListViewExample());
}

class ChatListViewExample extends StatelessWidget {
  const ChatListViewExample({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ChatListView Example',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (context) => const ScrollablePositionedListPage()));
                },
                child: Text('Demo'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScrollablePositionedListPage extends StatefulWidget {
  const ScrollablePositionedListPage({Key? key}) : super(key: key);

  @override
  _ScrollablePositionedListPageState createState() => _ScrollablePositionedListPageState();
}

class ItemData {
  final int dataIndex;
  final Color color;
  const ItemData({required this.dataIndex, required this.color});
}

class _ScrollablePositionedListPageState extends State<ScrollablePositionedListPage> {
  final List<ItemData> data = List.generate(
      numberOfItems, (index) => ItemData(dataIndex: 0, color: Color(colorGenerator.nextInt(randomMax)).withOpacity(1)));

  /// Controller to scroll or jump to a particular item.
  final ItemScrollController itemScrollController = ItemScrollController();

  /// Listener that reports the position of items when the list is scrolled.
  final ItemPositionsListener itemPositionsListener = ItemPositionsListener.create();

  @override
  void initState() {
    super.initState();
  }

  Color get generateColor => Color(colorGenerator.nextInt(randomMax)).withOpacity(1);

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Material(
            child: OrientationBuilder(
              builder: (context, orientation) => Column(
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                    child: Row(
                      children: [
                        ElevatedButton(
                            onPressed: () {
                              setState(() {
                                final firstItem = data.first;
                                data.insert(0, ItemData(dataIndex: firstItem.dataIndex - 1, color: generateColor));
                              });
                            },
                            child: Text('New Message')),
                        ElevatedButton(
                            onPressed: () {
                              setState(() {
                                final lastItem = data.last;
                                data.add(ItemData(dataIndex: lastItem.dataIndex + 1, color: generateColor));
                              });
                            },
                            child: Text('Old Message')),
                      ],
                    ),
                  ),
                  Expanded(
                    child: list(orientation),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: positionsView,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: <Widget>[
                        Column(
                          children: <Widget>[
                            scrollControlButtons,
                            const SizedBox(height: 10),
                            jumpControlButtons,
                          ],
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      );

  Widget list(Orientation orientation) {
    return Container(
      color: Colors.grey.withOpacity(0.1),
      child: ChatListView.builder(
        onPageAtBottom: (atBottom) {
          print('is page at bottom: $atBottom');
        },
        messageIds: data.map((item) => item.dataIndex.toString()).toList(),
        itemCount: data.length,
        itemBuilder: (context, index) => item(index, orientation),
        itemScrollController: itemScrollController,
        itemPositionsListener: itemPositionsListener,
      ),
    );
  }

  Widget get positionsView => ValueListenableBuilder<Iterable<ItemPosition>>(
        valueListenable: itemPositionsListener.itemPositions,
        builder: (context, positions, child) {
          int? min;
          int? max;
          if (positions.isNotEmpty) {
            // Determine the first visible item by finding the item with the
            // smallest trailing edge that is greater than 0.  i.e. the first
            // item whose trailing edge in visible in the viewport.
            min = positions
                .where((ItemPosition position) => position.itemTrailingEdge > 0)
                .reduce((ItemPosition min, ItemPosition position) =>
                    position.itemTrailingEdge < min.itemTrailingEdge ? position : min)
                .index;
            // Determine the last visible item by finding the item with the
            // greatest leading edge that is less than 1.  i.e. the last
            // item whose leading edge in visible in the viewport.
            max = positions
                .where((ItemPosition position) => position.itemLeadingEdge < 1)
                .reduce((ItemPosition max, ItemPosition position) =>
                    position.itemLeadingEdge > max.itemLeadingEdge ? position : max)
                .index;
          }
          return Row(
            children: <Widget>[
              Expanded(child: Text('First Item: ${min ?? ''}')),
              Expanded(child: Text('Last Item: ${max ?? ''}')),
            ],
          );
        },
      );

  Widget get scrollControlButtons => Row(
        children: <Widget>[
          const Text('scroll to'),
          scrollButton(0, 0, 'Bottom'),
          Visibility(
            visible: data.length > 10,
            child: scrollButton(10, 0, '10'),
          ),
          Visibility(
            visible: data.length > 100,
            child: scrollButton(100, 0, '100'),
          ),
          Visibility(
            visible: data.length > 1,
            child: scrollButton(data.length - 1, 0.875, 'Top'),
          ),
        ],
      );

  Widget get jumpControlButtons => Row(
        children: <Widget>[
          const Text('jump to'),
          jumpButton(0, 0, 'Bottom'),
          Visibility(
            visible: data.length > 10,
            child: jumpButton(10, 0, '10'),
          ),
          Visibility(
            visible: data.length > 100,
            child: jumpButton(100, 0, '100'),
          ),
          Visibility(
            visible: data.length > 1,
            child: jumpButton(data.length, 0.875, 'Top'),
          ),
        ],
      );

  final _scrollButtonStyle = ButtonStyle(
    padding: MaterialStateProperty.all(
      const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
    ),
    minimumSize: MaterialStateProperty.all(Size.zero),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget scrollButton(int value, double alignment, String displayName) => TextButton(
        key: ValueKey<String>('Scroll$value'),
        onPressed: () => scrollTo(value, alignment),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text('$displayName'),
        ),
        style: _scrollButtonStyle,
      );

  Widget jumpButton(int value, double alignment, String displayName) => TextButton(
        key: ValueKey<String>('Jump$value'),
        onPressed: () => jumpTo(value, alignment),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Text('$displayName'),
        ),
        style: _scrollButtonStyle,
      );

  void scrollTo(int index, double alignment) => itemScrollController.scrollTo(
      index: index, duration: scrollDuration, curve: Curves.easeInOutCubic, alignment: alignment);

  void jumpTo(int index, double alignment) => itemScrollController.jumpTo(index: index, alignment: alignment);

  /// Generate item number [i].
  Widget item(int i, Orientation orientation) {
    return SizedBox(
      key: Key('index_${data[i].dataIndex}'),
      height: 90,
      child: Container(
        color: data[i].color,
        child: Center(
          child: Text('Item ${data[i].dataIndex}'),
        ),
      ),
    );
  }
}
