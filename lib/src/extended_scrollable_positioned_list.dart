import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import './base/scrollable_positioned_list.dart';
import 'base/item_positions_listener.dart';

typedef FirstLoadedBuilder = bool Function();
typedef LoadingMoreStatusBuilder = bool Function();
typedef OnPageAtBottom = void Function(bool);
typedef LatestMessageIdBuilder = String Function();

class ExtendedScrollablePositionedList extends ScrollablePositionedList {
  ExtendedScrollablePositionedList({
    @required this.latestMessageIdBuilder,
    @required this.messageIds,
    @required this.loadingMoreStatusBuilder,
    @required int itemCount,
    @required IndexedWidgetBuilder itemBuilder,
    @required IndexedWidgetBuilder separatorBuilder,
    @required this.firstLoadedBuilder,
    this.findChildIndexCallback,
    Key key,
    int initialScrollIndex = 0,
    double initialAlignment = 0.0,
    ItemScrollController itemScrollController,
    ItemPositionsListener itemPositionsListener,
    ScrollPhysics physics,
    int semanticChildCount,
    EdgeInsets padding,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    double minCacheExtent,
    this.onPageAtBottom,
  })  : assert(latestMessageIdBuilder != null),
        assert(messageIds != null),
        assert(loadingMoreStatusBuilder != null),
        assert(itemCount != null),
        assert(itemBuilder != null),
        assert(separatorBuilder != null),
        super(
          key: key,
          itemCount: itemCount,
          itemBuilder: itemBuilder,
          separatorBuilder: separatorBuilder,
          findChildIndexCallback: findChildIndexCallback,
          itemScrollController: itemScrollController,
          itemPositionsListener: itemPositionsListener,
          initialScrollIndex: initialScrollIndex,
          initialAlignment: initialAlignment,
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

  final LatestMessageIdBuilder latestMessageIdBuilder;

  final ChildIndexGetter findChildIndexCallback;

  final LoadingMoreStatusBuilder loadingMoreStatusBuilder;

  final FirstLoadedBuilder firstLoadedBuilder;

  final OnPageAtBottom onPageAtBottom;

  @override
  _ExtendedScrollablePositionedListState createState() => _ExtendedScrollablePositionedListState();
}

class _ExtendedScrollablePositionedListState extends ScrollablePositionedListState<ExtendedScrollablePositionedList> {
  bool _isUserScrolling = false;
  int _len = 0;
  String _oldLastId;
  List<String> _oldMessageIds = [];
  bool _isAtBottom;
  bool _oldContainLatestMessage;

  VoidCallback _listener;

  bool get isFirstLoaded {
    if (widget.firstLoadedBuilder == null) return true;
    return widget.firstLoadedBuilder();
  }

  bool get containLatestMessage {
    if (widget.latestMessageIdBuilder == null) return true;
    if (widget.messageIds == null || widget.messageIds.length == 0) return true;
    return widget.messageIds.contains(widget.latestMessageIdBuilder());
  }

  bool get isLoadingMore => widget.loadingMoreStatusBuilder != null && widget.loadingMoreStatusBuilder();

  @override
  void initState() {
    _oldMessageIds
      ..clear()
      ..addAll(widget.messageIds);
    _oldContainLatestMessage =
        (widget.initialScrollIndex == 0 && widget.initialAlignment == 0) ? true : containLatestMessage;
    widget.itemPositionsNotifier?.itemPositions?.addListener(_onItemPositionsListener);
    widget.itemPositionsNotifier?.itemPositions?.addListener(_listener = () {
      if (mounted) {
        setState(() {});
      }
      if (_listener != null) {
        widget.itemPositionsNotifier?.itemPositions?.removeListener(_listener);
      }
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
        child: super.build(context),
      ),
    );
  }

  @override
  void dispose() {
    widget.itemPositionsNotifier?.itemPositions?.removeListener(_onItemPositionsListener);
    super.dispose();
  }

  @override
  void jumpTo({int index, double alignment}) {
    final itemPositionsNotifier = widget.itemPositionsNotifier;
    if (itemPositionsNotifier != null && itemPositionsNotifier.itemPositions.value.isNotEmpty) {
      final positions = itemPositionsNotifier.itemPositions.value.toList()..sort((a, b) => (a.index - b.index));
      final bool hasFirst = positions.any((element) => element.index == 0);
      final bool hasLast =
          positions.any((element) => element.index == (_len - 1) || element.index == (widget.itemCount - 1));
      if (hasFirst && hasLast) return;
    }
    super.jumpTo(index: index, alignment: alignment);
  }

  int _lastCallOnPageAtBottom = 0;

  void _onItemPositionsListener() {
    final itemPositionsNotifier = widget.itemPositionsNotifier;
    final bool isAtBottom = itemPositionsNotifier == null ||
        (containLatestMessage &&
            itemPositionsNotifier != null &&
            itemPositionsNotifier.itemPositions.value.isNotEmpty &&
            itemPositionsNotifier.itemPositions.value.any((element) => element.index == 0));
    if (isAtBottom != _isAtBottom || (DateTime.now().millisecondsSinceEpoch - _lastCallOnPageAtBottom > 500)) {
      widget.onPageAtBottom?.call(isAtBottom);
      _lastCallOnPageAtBottom = DateTime.now().millisecondsSinceEpoch;
    }
    _isAtBottom = isAtBottom;
  }

  void _updateIndexAndAlignment() {
    if (widget.messageIds == null || widget.messageIds.length == 0) return;
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
        if (_len != widget.itemCount) {
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
        }
      } else if (!isFirstLoaded) {
        primary.target = 0;
        primary.alignment = 0;
        secondary.target = 0;
        secondary.alignment = 0;
      } else if (hasFirst && _oldContainLatestMessage && containLatestMessage) {
        if (!_isUserScrolling) {
          if (first.itemLeadingEdge == 0 || !primary.scrollController.hasClients) {
            primary.target = 0;
            primary.alignment = 0;
            secondary.target = 0;
            secondary.alignment = 0;
          } else {
            jumpTo(index: 0, alignment: 0);
          }
        } else {
          final int diff = newLen - _len;
          final int oldLastNowIndex = widget.messageIds.indexOf(_oldLastId ?? '');
          final bool frontDiff = oldLastNowIndex > 0 && oldLastNowIndex > (_len - 1);
          if (frontDiff) {
            primary.target = primary.target + diff;
            secondary.target = secondary.target + diff;
          }
        }
      } else {
        final int diff = newLen - _len;
        final int oldLastNowIndex = widget.messageIds.indexOf(_oldLastId ?? '');
        final bool frontDiff = oldLastNowIndex > 0 && oldLastNowIndex > (_len - 1);
        if (frontDiff) {
          primary.target = primary.target + diff;
          secondary.target = secondary.target + diff;
        }
      }
      if (opacity.value != 0) {
        opacity.parent = Tween<double>(begin: 0.0, end: 0.0)
            .animate(AnimationController(vsync: this, duration: Duration())..forward());
      }
      _oldLastId = widget.messageIds.last;
      _len = newLen;
    } else {
      if (opacity.value != 1) {
        opacity.parent = Tween<double>(begin: 1.0, end: 1.0)
            .animate(AnimationController(vsync: this, duration: Duration())..forward());
      }
    }
    _oldContainLatestMessage = containLatestMessage;
    _oldMessageIds
      ..clear()
      ..addAll(widget.messageIds);
  }
}
