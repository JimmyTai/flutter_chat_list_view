// Copyright 2019 The Fuchsia Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'element_registry.dart';
import 'item_positions_listener.dart';
import 'item_positions_notifier.dart';
import 'scroll_view.dart';

/// A list of widgets similar to [ListView], except scroll control
/// and position reporting is based on index rather than pixel offset.
///
/// [PositionedList] lays out children in the same way as [ListView].
///
/// The list can be displayed with the item at [positionIndex] positioned at a
/// particular [alignment].  See [ItemScrollController.jumpTo] for an
/// explanation of alignment.
///
/// All other parameters are the same as specified in [ListView].
class PositionedList extends StatefulWidget {
  static const String TAG = 'PositionedList';

  /// Create a [PositionedList].
  const PositionedList({
    required this.itemCount,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.separatorBuilder,
    this.controller,
    this.itemPositionsNotifier,
    this.positionedIndex = 0,
    this.alignment = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.physics,
    this.padding,
    this.cacheExtent,
    this.semanticChildCount,
    this.addSemanticIndexes = true,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  })  : assert(itemCount != null),
        assert(itemBuilder != null),
        assert((positionedIndex == 0) || (positionedIndex < itemCount));

  /// Number of items the [itemBuilder] can produce.
  final int itemCount;

  /// Called to build children for the list with
  /// 0 <= index < itemCount.
  final IndexedWidgetBuilder itemBuilder;

  /// If not null, called to build separators for between each item in the list.
  /// Called with 0 <= index < itemCount - 1.
  final IndexedWidgetBuilder? separatorBuilder;

  final ChildIndexGetter? findChildIndexCallback;

  /// An object that can be used to control the position to which this scroll
  /// view is scrolled.
  final ScrollController? controller;

  /// Notifier that reports the items laid out in the list after each frame.
  final ItemPositionsNotifier? itemPositionsNotifier;

  /// Index of an item to initially align to a position within the viewport
  /// defined by [alignment].
  final int positionedIndex;

  /// Determines where the leading edge of the item at [positionedIndex]
  /// should be placed.
  ///
  /// See [ItemScrollController.jumpTo] for an explanation of alignment.
  final double? alignment;

  /// The axis along which the scroll view scrolls.
  ///
  /// Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Whether the view scrolls in the reading direction.
  ///
  /// Defaults to false.
  ///
  /// See [ScrollView.reverse].
  final bool reverse;

  /// How the scroll view should respond to user input.
  ///
  /// For example, determines how the scroll view continues to animate after the
  /// user stops dragging the scroll view.
  ///
  /// See [ScrollView.physics].
  final ScrollPhysics? physics;

  /// {@macro flutter.widgets.scrollable.cacheExtent}
  final double? cacheExtent;

  /// The number of children that will contribute semantic information.
  ///
  /// See [ScrollView.semanticChildCount] for more information.
  final int? semanticChildCount;

  /// Whether to wrap each child in an [IndexedSemantics].
  ///
  /// See [SliverChildBuilderDelegate.addSemanticIndexes].
  final bool addSemanticIndexes;

  /// The amount of space by which to inset the children.
  final EdgeInsets? padding;

  /// Whether to wrap each child in a [RepaintBoundary].
  ///
  /// See [SliverChildBuilderDelegate.addRepaintBoundaries].
  final bool addRepaintBoundaries;

  /// Whether to wrap each child in an [AutomaticKeepAlive].
  ///
  /// See [SliverChildBuilderDelegate.addAutomaticKeepAlives].
  final bool addAutomaticKeepAlives;

  @override
  State<StatefulWidget> createState() => _PositionedListState();
}

class _PositionedListState extends State<PositionedList> {
  final Key _centerKey = UniqueKey();

  final registeredElements = ValueNotifier<Set<Element>?>(null);
  ScrollController? scrollController;

  bool updateScheduled = false;

  @override
  void initState() {
    super.initState();
    scrollController = widget.controller ?? ScrollController();
    scrollController!.addListener(_schedulePositionNotificationUpdate);
    _schedulePositionNotificationUpdate();
  }

  @override
  void dispose() {
    scrollController!.removeListener(_schedulePositionNotificationUpdate);
    super.dispose();
  }

  @override
  void didUpdateWidget(PositionedList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedulePositionNotificationUpdate();
  }

  @override
  Widget build(BuildContext context) {
    final int leadingItemCount = widget.separatorBuilder == null ? widget.positionedIndex : 2 * widget.positionedIndex;
    final int centerItemCount = widget.itemCount != 0 ? 1 : 0;
    final int trailingItemCount = widget.separatorBuilder == null
        ? widget.itemCount - widget.positionedIndex - 1
        : 2 * (widget.itemCount - widget.positionedIndex - 1);
    return RegistryWidget(
      elementNotifier: registeredElements,
      child: UnboundedCustomScrollView(
        anchor: widget.alignment,
        center: _centerKey,
        controller: scrollController,
        scrollDirection: widget.scrollDirection,
        reverse: widget.reverse,
        cacheExtent: widget.cacheExtent,
        physics: widget.physics,
        semanticChildCount: widget.semanticChildCount ?? widget.itemCount,
        slivers: <Widget>[
          if (widget.positionedIndex > 0)
            SliverPadding(
              padding: _leadingSliverPadding,
              sliver: SliverList(
                key: ValueKey('leading_sliver_list'),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => widget.separatorBuilder == null
                      ? _buildItem(widget.positionedIndex - (index + 1))
                      : _buildSeparatedListElement(2 * widget.positionedIndex - (index + 1)),
                  childCount: widget.separatorBuilder == null ? widget.positionedIndex : 2 * widget.positionedIndex,
                  findChildIndexCallback: (key) {
                    int? rawIndex;
                    if (widget.findChildIndexCallback != null) {
                      final int? index = widget.findChildIndexCallback!(key);
                      if (index != null) {
                        if (key.toString().contains('root')) {
                          rawIndex = index * 2;
                        } else {
                          rawIndex = index * 2 + 1;
                        }
                        rawIndex = rawIndex >= leadingItemCount ? null : rawIndex;
                      }
                    }
                    return rawIndex;
                  },
                  addSemanticIndexes: false,
                  addRepaintBoundaries: widget.addRepaintBoundaries,
                  addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                ),
              ),
            ),
          SliverPadding(
            key: _centerKey,
            padding: _centerSliverPadding,
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => widget.separatorBuilder == null
                    ? _buildItem(index + widget.positionedIndex)
                    : _buildSeparatedListElement(index + 2 * widget.positionedIndex),
                childCount: widget.itemCount != 0 ? 1 : 0,
                findChildIndexCallback: (key) {
                  int? rawIndex;
                  if (widget.findChildIndexCallback != null) {
                    final int? index = widget.findChildIndexCallback!(key);
                    if (index != null) {
                      rawIndex = (index * 2) - (2 * widget.positionedIndex);
                      rawIndex = rawIndex >= centerItemCount ? null : rawIndex;
                    }
                  }
                  return rawIndex;
                },
                addSemanticIndexes: false,
                addRepaintBoundaries: widget.addRepaintBoundaries,
                addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
              ),
            ),
          ),
          if (widget.positionedIndex >= 0 && widget.positionedIndex < widget.itemCount - 1)
            SliverPadding(
              key: ValueKey('trailing_sliver_list'),
              padding: _trailingSliverPadding,
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => widget.separatorBuilder == null
                      ? _buildItem(index + widget.positionedIndex + 1)
                      : _buildSeparatedListElement(index + 2 * widget.positionedIndex + 1),
                  childCount: widget.separatorBuilder == null
                      ? widget.itemCount - widget.positionedIndex - 1
                      : 2 * (widget.itemCount - widget.positionedIndex - 1),
                  findChildIndexCallback: (key) {
                    int? rawIndex;
                    if (widget.findChildIndexCallback != null) {
                      final int? index = widget.findChildIndexCallback!(key);
                      if (index != null) {
                        if (key.toString().contains('root')) {
                          rawIndex = (index * 2) - (2 * widget.positionedIndex) - 1;
                        } else {
                          rawIndex = (index * 2) - (2 * widget.positionedIndex);
                        }
                        rawIndex = rawIndex >= trailingItemCount ? null : rawIndex;
                      }
                    }
                    return rawIndex;
                  },
                  addSemanticIndexes: false,
                  addRepaintBoundaries: widget.addRepaintBoundaries,
                  addAutomaticKeepAlives: widget.addAutomaticKeepAlives,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSeparatedListElement(int index) {
    if (index.isEven) {
      return _buildItem(index ~/ 2);
    } else {
      return widget.separatorBuilder!(context, index ~/ 2);
    }
  }

  Widget _buildItem(int index) {
    return Container(
      key: widget.itemBuilder(context, index).key,
      child: RegisteredElementWidget(
        index: index,
        key: widget.itemBuilder(context, index)?.key,
        child: widget.addSemanticIndexes
            ? IndexedSemantics(index: index, child: widget.itemBuilder(context, index))
            : widget.itemBuilder(context, index),
      ),
    );
  }

  EdgeInsets get _leadingSliverPadding =>
      (widget.scrollDirection == Axis.vertical
          ? widget.reverse
              ? widget.padding?.copyWith(top: 0)
              : widget.padding?.copyWith(bottom: 0)
          : widget.reverse
              ? widget.padding?.copyWith(left: 0)
              : widget.padding?.copyWith(right: 0)) ??
      EdgeInsets.all(0);

  EdgeInsets get _centerSliverPadding => widget.scrollDirection == Axis.vertical
      ? widget.reverse
          ? widget.padding?.copyWith(
                  top: widget.positionedIndex == widget.itemCount - 1 ? widget.padding!.top : 0,
                  bottom: widget.positionedIndex == 0 ? widget.padding!.bottom : 0) ??
              EdgeInsets.all(0)
          : widget.padding?.copyWith(
                  top: widget.positionedIndex == 0 ? widget.padding!.top : 0,
                  bottom: widget.positionedIndex == widget.itemCount - 1 ? widget.padding!.bottom : 0) ??
              EdgeInsets.all(0)
      : widget.reverse
          ? widget.padding?.copyWith(
                  left: widget.positionedIndex == widget.itemCount - 1 ? widget.padding!.left : 0,
                  right: widget.positionedIndex == 0 ? widget.padding!.right : 0) ??
              EdgeInsets.all(0)
          : widget.padding?.copyWith(
                left: widget.positionedIndex == 0 ? widget.padding!.left : 0,
                right: widget.positionedIndex == widget.itemCount - 1 ? widget.padding!.right : 0,
              ) ??
              EdgeInsets.all(0);

  EdgeInsets get _trailingSliverPadding => widget.scrollDirection == Axis.vertical
      ? widget.reverse
          ? widget.padding?.copyWith(bottom: 0) ?? EdgeInsets.all(0)
          : widget.padding?.copyWith(top: 0) ?? EdgeInsets.all(0)
      : widget.reverse
          ? widget.padding?.copyWith(right: 0) ?? EdgeInsets.all(0)
          : widget.padding?.copyWith(left: 0) ?? EdgeInsets.all(0);

  void _schedulePositionNotificationUpdate() {
    if (!updateScheduled) {
      updateScheduled = true;
      SchedulerBinding.instance!.addPostFrameCallback((_) {
        if (registeredElements.value == null) {
          updateScheduled = false;
          return;
        }
        final positions = <ItemPosition>[];
        RenderViewport? viewport;
        for (var element in registeredElements.value!) {
          try {
            final RenderBox? box = element.renderObject as RenderBox?;
            if (box == null) continue;
            if (!box.attached) continue;
            viewport ??= RenderAbstractViewport.of(box);
            if (viewport == null) continue;
            final ValueKey<String> key = element.widget.key;
            int index;
            if (element is RegisteredElement) {
              index = element.index;
            }
            if (index == null) continue;
            if (widget.scrollDirection == Axis.vertical) {
              final reveal = viewport.getOffsetToReveal(box, 0).offset;
              final itemOffset = reveal - viewport.offset.pixels + viewport.anchor * viewport.size.height;
              positions.add(ItemPosition(
                  // index: key.value,
                  index: index,
                  itemLeadingEdge: itemOffset.round() / scrollController!.position.viewportDimension,
                  itemTrailingEdge:
                      (itemOffset + box.size.height).round() / scrollController.position.viewportDimension));
            } else {
              final itemOffset = box.localToGlobal(Offset.zero, ancestor: viewport).dx;
              positions.add(ItemPosition(
                  // index: key.value,
                  index: index,
                  itemLeadingEdge: (widget.reverse
                              ? scrollController.position.viewportDimension - (itemOffset + box.size.width)
                              : itemOffset)
                          .round() /
                      scrollController.position.viewportDimension,
                  itemTrailingEdge: (widget.reverse
                              ? scrollController.position.viewportDimension - itemOffset
                              : (itemOffset + box.size.width))
                          .round() /
                      scrollController.position.viewportDimension));
            }
          } catch (e, stackTrace) {
            print(
                '[ChatListView] PositionedList _schedulePositionNotificationUpdate with error: $e, stackTrace: $stackTrace');
          }
        }
        widget.itemPositionsNotifier?.itemPositions?.value = positions;
        updateScheduled = false;
      });
    }
  }
}
