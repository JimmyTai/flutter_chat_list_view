import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'extended_scrollable_positioned_list.dart';
import 'lazy_load_scroll_view.dart';
import 'base/item_positions_listener.dart';
import './base/scrollable_positioned_list.dart';

typedef FirstLoadedBuilder = bool Function();
typedef OnPageAtBottom = void Function(bool);
typedef LatestMessageIdBuilder = String Function();

class ChatListView extends StatefulWidget {
  const ChatListView.builder({
    Key key,
    @required this.firstLoadedBuilder,
    @required this.latestMessageIdBuilder,
    @required this.messageIds,
    @required this.itemCount,
    @required this.itemBuilder,
    this.listViewKey,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0.0,
    this.itemScrollController,
    this.itemPositionsListener,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
    this.onStartOfPage,
    this.onEndOfPage,
    this.onPageScrollStart,
    this.onPageScrollEnd,
    this.onPageAtBottom,
  })  : assert(messageIds != null),
        assert(itemCount != null),
        assert(itemBuilder != null),
        separatorBuilder = null,
        super(key: key);

  ChatListView.separated({
    Key key,
    @required this.firstLoadedBuilder,
    @required this.latestMessageIdBuilder,
    @required this.messageIds,
    @required this.itemCount,
    @required this.itemBuilder,
    @required this.separatorBuilder,
    this.listViewKey,
    this.initialScrollIndex = 0,
    this.initialAlignment = 0.0,
    this.itemScrollController,
    this.itemPositionsListener,
    this.physics,
    this.semanticChildCount,
    this.padding,
    this.addSemanticIndexes = true,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.minCacheExtent,
    this.onStartOfPage,
    this.onEndOfPage,
    this.onPageScrollStart,
    this.onPageScrollEnd,
    this.onPageAtBottom,
  })  : assert(messageIds != null),
        assert(itemCount != null),
        assert(itemBuilder != null),
        assert(separatorBuilder != null),
        super(key: key);

  final Key listViewKey;

  /// all the message Ids in your list, the latest message is from position 0
  final List<String> messageIds;

  final FirstLoadedBuilder firstLoadedBuilder;

  final LatestMessageIdBuilder latestMessageIdBuilder;

  /// Number of items the [itemBuilder] can produce.
  final int itemCount;

  /// Called to build children for the list with
  /// 0 <= index < itemCount.
  final IndexedWidgetBuilder itemBuilder;

  /// Called to build separators for between each item in the list.
  /// Called with 0 <= index < itemCount - 1.
  final IndexedWidgetBuilder separatorBuilder;

  /// Controller for jumping or scrolling to an item.
  final ItemScrollController itemScrollController;

  /// Notifier that reports the items laid out in the list after each frame.
  final ItemPositionsListener itemPositionsListener;

  /// Index of an item to initially align within the viewport.
  final int initialScrollIndex;

  /// Determines where the leading edge of the item at [initialScrollIndex]
  /// should be placed.
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  final double initialAlignment;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics physics;

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int semanticChildCount;

  /// The amount of space by which to inset the children.
  final EdgeInsets padding;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// The minimum cache extent used by the underlying scroll lists.
  /// See [ScrollView.cacheExtent].
  ///
  /// Note that the [ScrollablePositionedList] uses two lists to simulate long
  /// scrolls, so using the [ScrollController.scrollTo] method may result
  /// in builds of widgets that would otherwise already be built in the
  /// cache extent.
  final double minCacheExtent;

  /// Called when the [child] reaches the start of the list
  final AsyncCallback onStartOfPage;

  /// Called when the [child] reaches the end of the list
  final AsyncCallback onEndOfPage;

  /// Called when the list scrolling starts
  final VoidCallback onPageScrollStart;

  /// Called when the list scrolling ends
  final VoidCallback onPageScrollEnd;

  final OnPageAtBottom onPageAtBottom;

  @override
  _ChatListViewState createState() => _ChatListViewState();
}

class _ChatListViewState extends State<ChatListView> {
  LazyLoadScrollController _lazyLoadController;

  @override
  void initState() {
    _lazyLoadController = LazyLoadScrollController();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return LazyLoadScrollView(
      controller: _lazyLoadController,
      onStartOfPage: widget.onStartOfPage,
      onEndOfPage: widget.onEndOfPage,
      onPageScrollStart: widget.onPageScrollStart,
      onPageScrollEnd: widget.onPageScrollEnd,
      child: ExtendedScrollablePositionedList(
        key: widget.listViewKey,
        firstLoadedBuilder: widget.firstLoadedBuilder,
        latestMessageIdBuilder: widget.latestMessageIdBuilder,
        messageIds: widget.messageIds,
        loadingMoreStatusBuilder: () {
          return _lazyLoadController?.loadMoreStatus == LoadingStatus.loading;
        },
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
        separatorBuilder: widget.separatorBuilder,
        findChildIndexCallback: (key) {
          print('Chat list key: $key');
          final int index = widget.messageIds?.indexWhere((id) => key.toString().contains('$id')) ?? -1;
          print('Chat list index: $index');
          return index >= 0 ? index : null;
        },
        initialScrollIndex: widget.initialScrollIndex,
        initialAlignment: widget.initialAlignment,
        itemScrollController: widget.itemScrollController,
        itemPositionsListener: widget.itemPositionsListener,
        physics: widget.physics,
        semanticChildCount: widget.semanticChildCount,
        padding: widget.padding,
        addSemanticIndexes: widget.addSemanticIndexes,
        addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
        addRepaintBoundaries: widget.addRepaintBoundaries,
        minCacheExtent: widget.minCacheExtent,
        onPageAtBottom: widget.onPageAtBottom,
      ),
    );
  }

  @override
  void dispose() {
    _lazyLoadController?.dispose();
    super.dispose();
  }
}
