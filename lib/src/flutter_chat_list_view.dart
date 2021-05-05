import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_chat_list_view/src/lazy_load_scroll_view.dart';
import './base/scrollable_positioned_list.dart';
import 'base/item_positions_listener.dart';

typedef OnPageAtBottom = void Function(bool);

class ChatListView extends ScrollablePositionedList {
  const ChatListView.builder({
    @required this.messageIds,
    @required int itemCount,
    @required IndexedWidgetBuilder itemBuilder,
    Key key,
    ItemScrollController itemScrollController,
    ItemPositionsListener itemPositionsListener,
    ScrollPhysics physics,
    int semanticChildCount,
    EdgeInsets padding,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    double minCacheExtent,
    this.onStartOfPage,
    this.onEndOfPage,
    this.onPageScrollStart,
    this.onPageScrollEnd,
    this.onPageAtBottom,
  })  : assert(messageIds != null),
        assert(itemCount != null),
        assert(itemBuilder != null),
        super.builder(
          key: key,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: 0,
          initialAlignment: 0,
          scrollDirection: Axis.vertical,
          reverse: true,
          physics: physics,
          semanticChildCount: semanticChildCount,
          padding: padding,
          addSemanticIndexes: addSemanticIndexes,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
        );

  ChatListView.separated({
    @required this.messageIds,
    @required int itemCount,
    @required IndexedWidgetBuilder itemBuilder,
    @required IndexedWidgetBuilder separatorBuilder,
    Key key,
    ItemScrollController itemScrollController,
    ItemPositionsListener itemPositionsListener,
    ScrollPhysics physics,
    int semanticChildCount,
    EdgeInsets padding,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    double minCacheExtent,
    this.onStartOfPage,
    this.onEndOfPage,
    this.onPageScrollStart,
    this.onPageScrollEnd,
    this.onPageAtBottom,
  })  : assert(messageIds != null),
        assert(itemCount != null),
        assert(itemBuilder != null),
        assert(separatorBuilder != null),
        super.separated(
          key: key,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: separatorBuilder,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: 0,
          initialAlignment: 0,
          scrollDirection: Axis.vertical,
          reverse: true,
          physics: physics,
          semanticChildCount: semanticChildCount,
          padding: padding,
          addSemanticIndexes: addSemanticIndexes,
          addAutomaticKeepAlives: addAutomaticKeepAlives,
          addRepaintBoundaries: addRepaintBoundaries,
          minCacheExtent: minCacheExtent,
        );

  /// all the message Ids in your list, the latest message is from position 0
  final List<String> messageIds;

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

class _ChatListViewState extends ScrollablePositionedListState<ChatListView> {
  bool _isUserScrolling = false;
  int _len = 0;
  String _oldFirstId;
  bool _isAtBottom;

  VoidCallback _listener;

  @override
  void initState() {
    widget.itemPositionsNotifier?.itemPositions?.addListener(_onItemPositionsListener);
    widget.itemPositionsNotifier?.itemPositions?.addListener(_listener = () {
      setState(() {});
      if (_listener != null) {
        widget.itemPositionsNotifier?.itemPositions?.removeListener(_listener);
      }
    });
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _updateIndexAndAlignment();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _updateIndexAndAlignment();
    return Listener(
      onPointerDown: (_) {
        _isUserScrolling = true;
      },
      onPointerUp: (_) {
        _isUserScrolling = false;
      },
      child: NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) {
          if (scrollInfo is UserScrollNotification) {
            _isUserScrolling = scrollInfo.direction != ScrollDirection.idle;
          }
          return false;
        },
        child: LazyLoadScrollView(
          onStartOfPage: widget.onStartOfPage,
          onEndOfPage: widget.onEndOfPage,
          onPageScrollStart: widget.onPageScrollStart,
          onPageScrollEnd: widget.onPageScrollEnd,
          child: super.build(context),
        ),
      ),
    );
  }

  @override
  void dispose() {
    widget.itemPositionsNotifier?.itemPositions?.removeListener(_onItemPositionsListener);
    super.dispose();
  }

  void _onItemPositionsListener() {
    final itemPositionsNotifier = widget.itemPositionsNotifier;
    final bool isAtBottom = itemPositionsNotifier != null &&
        itemPositionsNotifier.itemPositions.value.isNotEmpty &&
        itemPositionsNotifier.itemPositions.value.any((element) => element.index == 0);
    if (isAtBottom != _isAtBottom) {
      widget.onPageAtBottom?.call(isAtBottom);
    }
    _isAtBottom = isAtBottom;
  }

  void _updateIndexAndAlignment() {
    if (isTransitioning) return;
    final int newLen = widget.itemCount;
    final itemPositionsNotifier = widget.itemPositionsNotifier;
    if (itemPositionsNotifier != null && itemPositionsNotifier.itemPositions.value.isNotEmpty) {
      final positions = itemPositionsNotifier.itemPositions.value.toList()..sort((a, b) => (a.index - b.index));
      final first = positions.first;
      final last = positions.last;
      final bool hasFirst = positions.any((element) => element.index == 0);
      final bool hasLast =
          positions.any((element) => element.index == (_len - 1) || element.index == (widget.itemCount - 1));
      if (hasFirst && hasLast) {
        primary.target = 0;
        secondary.target = 0;
        if (first.itemLeadingEdge == 0 && last.itemTrailingEdge < 0.7) {
          if (last.itemTrailingEdge != 1) {
            primary.alignment = 1 - last.itemTrailingEdge;
            secondary.alignment = 1 - last.itemTrailingEdge;
          }
        } else if (last.itemTrailingEdge == 1) {
          if (first.itemLeadingEdge < 0.3) {
            primary.alignment = 0;
            secondary.alignment = 0;
          }
        } else {
          primary.alignment = 0;
          secondary.alignment = 0;
        }
      } else if (hasFirst) {
        if (!_isUserScrolling) {
          if (first.itemLeadingEdge == 0) {
            primary.target = 0;
            primary.alignment = 0;
            secondary.target = 0;
            secondary.alignment = 0;
          } else {
            jumpTo(index: 0, alignment: 0);
          }
        } else {
          final int diff = newLen - _len;
          final int frontDiff = widget.messageIds.indexOf(_oldFirstId ?? '');
          if (frontDiff > 0) {
            primary.target = primary.target + diff;
            secondary.target = secondary.target + diff;
          }
        }
      } else {
        final int diff = newLen - _len;
        final int frontDiff = widget.messageIds.indexOf(_oldFirstId ?? '');
        if (frontDiff > 0) {
          primary.target = primary.target + diff;
          secondary.target = secondary.target + diff;
        }
      }
      if (opacity.value != 0) {
        opacity.parent = Tween<double>(begin: 0.0, end: 0.0)
            .animate(AnimationController(vsync: this, duration: Duration())..forward());
      }
    } else {
      if (opacity.value != 1) {
        opacity.parent = Tween<double>(begin: 1.0, end: 1.0)
            .animate(AnimationController(vsync: this, duration: Duration())..forward());
      }
    }
    _oldFirstId = widget.messageIds.first;
    _len = newLen;
  }
}
