import 'dart:ui' as ui;
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
    required this.latestMessageIdBuilder,
    required this.messageIds,
    required this.loadingMoreStatusBuilder,
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
    required IndexedWidgetBuilder separatorBuilder,
    required this.firstLoadedBuilder,
    this.findChildIndexCallback,
    Key? key,
    int initialScrollIndex = 0,
    double initialAlignment = 0.0,
    ItemScrollController? itemScrollController,
    ItemPositionsListener? itemPositionsListener,
    ScrollPhysics? physics,
    int? semanticChildCount,
    EdgeInsets? padding,
    bool addSemanticIndexes = true,
    bool addAutomaticKeepAlives = true,
    bool addRepaintBoundaries = true,
    double? minCacheExtent,
    this.onPageAtBottom,
  }) : super(
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

  final ChildIndexGetter? findChildIndexCallback;

  final LoadingMoreStatusBuilder loadingMoreStatusBuilder;

  final FirstLoadedBuilder firstLoadedBuilder;

  final OnPageAtBottom? onPageAtBottom;

  @override
  _ExtendedScrollablePositionedListState createState() => _ExtendedScrollablePositionedListState();
}

class _ExtendedScrollablePositionedListState extends ScrollablePositionedListState<ExtendedScrollablePositionedList> {
  bool _isUserScrolling = false;
  int _len = 0;
  String? _oldLastId;
  List<String> _oldMessageIds = [];
  bool _oldContainLatestMessage = false;
  int primaryTarget = 0;
  double primaryAlign = 0;
  double _lastBottomPadding = 0;

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
    widget.itemPositionsNotifier?.itemPositions.addListener(_eventItemUpdated);
    super.initState();
  }

  void _eventItemUpdated() {
    _updateIndexAndAlignment();
    if (primaryAlign != primary.alignment || primary.target != primaryTarget) {
      primaryAlign = primary.alignment ?? 0;
      primaryTarget = primary.target;
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {}); // update screen
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = ui.window.viewInsets.bottom;
    if (_lastBottomPadding != bottom) {
      _lastBottomPadding = bottom;
      _updateIndexAndAlignment(refresh: true);
      primaryAlign = primary.alignment ?? 0;
      primaryTarget = primary.target;
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        setState(() {}); // update screen
      });
    }
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
    widget.itemPositionsNotifier?.itemPositions.removeListener(_eventItemUpdated);

    super.dispose();
  }

  @override
  void jumpTo({int? index, double? alignment, bool isOnlyFilledView = false}) {
    final itemPositions = widget.itemPositionsNotifier?.itemPositions.value;
    if (itemPositions != null && itemPositions.isNotEmpty) {
      final positions = itemPositions.toList()..sort((a, b) => (a.index - b.index));
      final bool hasFirst = positions.any((element) => element.index == 0);
      final bool hasLast =
          positions.any((element) => element.index == (_len - 1) || element.index == (widget.itemCount - 1));
      if (hasFirst && hasLast) return;
    }
    super.jumpTo(index: index!, alignment: alignment, isOnlyFilledView: isOnlyFilledView);
  }

  void _updateIndexAndAlignment({bool refresh = false}) {
    if (widget.messageIds.isEmpty) return;
    if (isTransitioning) return;
    final int newLen = widget.itemCount;
    final itemPositions = widget.itemPositionsNotifier?.itemPositions.value;
    if (itemPositions != null && itemPositions.isNotEmpty) {
      final positions = itemPositions.toList()..sort((a, b) => (a.index - b.index));
      final first = positions.first;
      final last = positions.last;
      final bool hasFirst = positions.any((element) => element.index == 0);
      final bool hasLast = (widget.itemCount == positions.length) ||
          positions.any((element) => element.index == (_len - 1) || element.index == (widget.itemCount - 1));
      final viewHeight =
          primary.scrollController.hasClients ? primary.scrollController.position.viewportDimension : 600;
      if (hasFirst && hasLast) {
        if (_len != widget.itemCount || refresh) {
          primary.target = 0;
          secondary.target = 0;

          if (((last.itemOffset - first.itemOffset) < viewHeight) && last.itemTrailingEdge < 1) {
            if (last.itemTrailingEdge != 1) {
              primary.alignment = 1 - (last.itemOffset + last.itemSize) / viewHeight;
              secondary.alignment = 1 - (last.itemOffset + last.itemSize) / viewHeight;
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
            if (first.itemLeadingEdge > -(first.itemSize / viewHeight) * 0.3) {
              jumpTo(index: 0, alignment: 0); // jump to 0, ensure first item in sight
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
