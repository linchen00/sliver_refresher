import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../sliver_refresher.dart';

/// One committed layout result shared by state, physics and UI requests.
class IndicatorLayoutResult {
  const IndicatorLayoutResult({
    required this.contentExtent,
    required this.effectiveExtent,
    required this.occupiedExtent,
    required this.hidden,
    required this.expanded,
  });
  final double contentExtent;
  final double effectiveExtent;
  final double occupiedExtent;
  final bool hidden;
  final bool expanded;
}

mixin IndicatorExtentLayout on RenderSliverSingleBoxAdapter {
  double? _configuredExtent;
  double _contentExtent = 0;
  IndicatorLayoutResult? layoutResult;
  bool layoutPending = true;

  double? get configuredExtent => _configuredExtent;
  set configuredExtent(double? value) {
    validateExtent(value);
    if (_configuredExtent == value) return;
    _configuredExtent = value;
    markNeedsLayout();
  }

  static void validateExtent(double? value) {
    if (value != null && (!value.isFinite || value < 0)) {
      throw FlutterError(
        'Indicator extent must be finite and non-negative, or null.',
      );
    }
  }

  double get effectiveExtent => _configuredExtent ?? _contentExtent;

  double measureContent() {
    layoutPending = true;
    final currentChild = child;
    currentChild?.layout(constraints.asBoxConstraints(), parentUsesSize: true);
    _contentExtent = currentChild == null
        ? 0
        : constraints.axis == Axis.vertical
            ? currentChild.size.height
            : currentChild.size.width;
    validateExtent(_contentExtent);
    return _contentExtent;
  }

  void commitLayout(
    double occupiedExtent, {
    bool hidden = false,
    required bool expanded,
  }) {
    if (layoutResult?.hidden != hidden || layoutResult?.expanded != expanded) {
      markNeedsSemanticsUpdate();
    }
    layoutPending = false;
    layoutResult = IndicatorLayoutResult(
      contentExtent: _contentExtent,
      effectiveExtent: effectiveExtent,
      occupiedExtent: occupiedExtent,
      hidden: hidden,
      expanded: expanded,
    );
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (layoutResult?.hidden == false && geometry?.visible == true) {
      super.visitChildrenForSemantics(visitor);
    }
  }
}

///  Render header sliver widget
class SliverRefresh extends SingleChildRenderObjectWidget {
  const SliverRefresh({
    super.key,
    this.paintOffsetY = 0.0,
    this.refreshIndicatorLayoutExtent = 0.0,
    this.floating = false,
    super.child,
    this.refreshStyle = RefreshStyle.follow,
  }) : assert(
          refreshIndicatorLayoutExtent == null ||
              (refreshIndicatorLayoutExtent >= 0.0 &&
                  refreshIndicatorLayoutExtent < double.infinity),
        );

  /// The amount of space the indicator should occupy in the sliver in a
  /// resting state when in the refreshing mode.
  final double? refreshIndicatorLayoutExtent;

  /// _RenderSliverRefresh will paint the child in the available
  /// space either way but this instructs the _RenderSliverRefresh
  /// on whether to also occupy any layoutExtent space or not.
  final bool floating;

  /// header indicator display style
  final RefreshStyle refreshStyle;

  /// headerOffset	Head indicator layout deviation Y coordinates, mostly for FrontStyle
  final double paintOffsetY;

  @override
  RenderSliverRefresh createRenderObject(BuildContext context) {
    return RenderSliverRefresh(
      refreshIndicatorExtent: refreshIndicatorLayoutExtent,
      hasLayoutExtent: floating,
      paintOffsetY: paintOffsetY,
      refreshStyle: refreshStyle,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSliverRefresh renderObject,
  ) {
    renderObject
      ..configuredExtent = refreshIndicatorLayoutExtent
      ..hasLayoutExtent = floating
      ..refreshStyle = refreshStyle
      ..paintOffsetY = paintOffsetY;
  }
}

class RenderSliverRefresh extends RenderSliverSingleBoxAdapter
    with IndicatorExtentLayout {
  RenderSliverRefresh({
    required double? refreshIndicatorExtent,
    required bool hasLayoutExtent,
    RenderBox? child,
    double paintOffsetY = 0.0,
    RefreshStyle refreshStyle = RefreshStyle.follow,
  })  : _paintOffsetY = paintOffsetY,
        _refreshStyle = refreshStyle,
        _hasLayoutExtent = hasLayoutExtent {
    configuredExtent = refreshIndicatorExtent;
    this.child = child;
  }

  RefreshStyle _refreshStyle;

  double _paintOffsetY;

  bool _hasLayoutExtent;

  double _previousLayoutExtent = 0.0;

  RefreshStyle get refreshStyle => _refreshStyle;

  set refreshStyle(RefreshStyle value) {
    if (_refreshStyle == value) return;
    _refreshStyle = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  // The amount of layout space the indicator should occupy in the sliver in a
  // resting state when in the refreshing mode.
  double get refreshIndicatorLayoutExtent => effectiveExtent;

  double get paintOffsetY => _paintOffsetY;

  set paintOffsetY(double value) {
    if (_paintOffsetY == value) return;
    _paintOffsetY = value;
    markNeedsPaint();
    markNeedsSemanticsUpdate();
  }

  // The child box will be laid out and painted in the available space either
  // way but this determines whether to also occupy any
  // [SliverGeometry.layoutExtent] space or not.
  bool get hasLayoutExtent => _hasLayoutExtent;

  set hasLayoutExtent(bool value) {
    if (value == _hasLayoutExtent) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  /// Space occupied by the header in the current layout pass.
  double get occupiedExtent => _previousLayoutExtent;

  // Preserve the body anchor during overscroll or body scrolling, and the
  // relative position inside the header while the viewport displays it.
  // A collapsed header's leading edge maps to the expanded header's leading
  // edge, so publishing refreshing at rest reveals it without scrolling.
  double _scrollOffsetCorrection(double layoutExtent) {
    final pixels = (parent as RenderViewportBase).offset.pixels;
    final layoutExtentChange = layoutExtent - _previousLayoutExtent;
    if (pixels < 0.0 || pixels > _previousLayoutExtent) {
      return layoutExtentChange;
    }

    final headerFraction =
        _previousLayoutExtent > 0.0 ? pixels / _previousLayoutExtent : 0.0;
    return headerFraction * layoutExtent - pixels;
  }

  @override
  double get centerOffsetAdjustment {
    if (refreshStyle == RefreshStyle.front) {
      final RenderViewportBase renderViewport =
          parent as RenderViewportBase<ContainerParentDataMixin<RenderSliver>>;
      return math.max(0.0, -renderViewport.offset.pixels);
    }
    return 0.0;
  }

  @override
  void layout(Constraints constraints, {bool parentUsesSize = false}) {
    if (refreshStyle == RefreshStyle.front) {
      final RenderViewportBase renderViewport =
          parent as RenderViewportBase<ContainerParentDataMixin<RenderSliver>>;
      super.layout(
        (constraints as SliverConstraints).copyWith(
          overlap: math.min(0.0, renderViewport.offset.pixels),
        ),
        parentUsesSize: true,
      );
    } else {
      super.layout(constraints, parentUsesSize: parentUsesSize);
    }
  }

  @override
  void debugAssertDoesMeetConstraints() {
    final currentGeometry = geometry;
    if (currentGeometry == null) {
      throw FlutterError('A laid-out indicator must have SliverGeometry.');
    }
    assert(
      currentGeometry.debugAssertIsValid(
        informationCollector: () sync* {
          yield describeForError(
            'The RenderSliver that returned the offending geometry was',
          );
        },
      ),
    );
    assert(() {
      if (currentGeometry.paintExtent > constraints.remainingPaintExtent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'SliverGeometry has a paintOffset that exceeds the remainingPaintExtent from the constraints.',
          ),
          describeForError(
            'The render object whose geometry violates the constraints is the following',
          ),
          ErrorDescription(
            'The paintExtent must cause the child sliver to paint within the viewport, and so '
            'cannot exceed the remainingPaintExtent.',
          ),
        ]);
      }
      return true;
    }());
  }

  @override
  void performLayout() {
    final double contentExtent = measureContent();
    final currentChild = child;
    final double layoutExtent = currentChild != null &&
            _hasLayoutExtent &&
            refreshStyle != RefreshStyle.front
        ? effectiveExtent
        : 0.0;
    // Changing display style and changing size use the same body anchor rule.
    if (layoutExtent != _previousLayoutExtent) {
      final scrollOffsetCorrection = _scrollOffsetCorrection(layoutExtent);
      _previousLayoutExtent = layoutExtent;
      if (scrollOffsetCorrection != 0.0) {
        geometry =
            SliverGeometry(scrollOffsetCorrection: scrollOffsetCorrection);
        return;
      }
    }
    if (currentChild == null) {
      geometry = SliverGeometry.zero;
      commitLayout(0, hidden: true, expanded: hasLayoutExtent);
      return;
    }
    final isIndicatorVisible = constraints.overlap < 0.0 || _hasLayoutExtent;
    final double overscrolledExtent =
        -(parent as RenderViewportBase).offset.pixels;

    if (isIndicatorVisible) {
      double visiblePaintExtent = math.min(
        math.max(
          math.max(
                contentExtent,
                refreshStyle == RefreshStyle.front && _hasLayoutExtent
                    ? effectiveExtent
                    : layoutExtent,
              ) -
              constraints.scrollOffset,
          0.0,
        ),
        constraints.remainingPaintExtent,
      );
      if (refreshStyle == RefreshStyle.behind) {
        visiblePaintExtent = math.min(
          visiblePaintExtent,
          math.max(0.0, overscrolledExtent + layoutExtent),
        );
      }
      final SliverGeometry currentGeometry;
      switch (refreshStyle) {
        case RefreshStyle.follow:
          currentGeometry = SliverGeometry(
            scrollExtent: layoutExtent,
            paintOrigin:
                -contentExtent - constraints.scrollOffset + layoutExtent,
            paintExtent: visiblePaintExtent,
            hitTestExtent: visiblePaintExtent,
            hasVisualOverflow: overscrolledExtent < contentExtent,
            maxPaintExtent: visiblePaintExtent,
            layoutExtent: math.min(
              visiblePaintExtent,
              math.max(layoutExtent - constraints.scrollOffset, 0.0),
            ),
          );

          break;
        case RefreshStyle.behind:
          currentGeometry = SliverGeometry(
            scrollExtent: layoutExtent,
            paintOrigin: -overscrolledExtent - constraints.scrollOffset,
            paintExtent: visiblePaintExtent,
            maxPaintExtent: visiblePaintExtent,
            layoutExtent: math.min(
              visiblePaintExtent,
              math.max(layoutExtent - constraints.scrollOffset, 0.0),
            ),
          );
          break;
        case RefreshStyle.unFollow:
          currentGeometry = SliverGeometry(
            scrollExtent: layoutExtent,
            paintOrigin: math.min(
              -overscrolledExtent - constraints.scrollOffset,
              -contentExtent - constraints.scrollOffset + layoutExtent,
            ),
            paintExtent: visiblePaintExtent,
            hasVisualOverflow: overscrolledExtent < contentExtent,
            maxPaintExtent: visiblePaintExtent,
            layoutExtent: math.min(
              visiblePaintExtent,
              math.max(layoutExtent - constraints.scrollOffset, 0.0),
            ),
          );

          break;
        case RefreshStyle.front:
          currentGeometry = SliverGeometry(
            paintExtent: visiblePaintExtent,
            layoutExtent: 0,
            maxPaintExtent: visiblePaintExtent,
            hitTestExtent: visiblePaintExtent,
            visible: visiblePaintExtent > 0,
            hasVisualOverflow: true,
          );
          break;
      }
      // The viewport already positions this sliver by its paint origin.
      geometry = currentGeometry;
      final childParentData =
          currentChild.parentData as SliverPhysicalParentData;
      final isReversed = constraints.axisDirection == AxisDirection.up ||
          constraints.axisDirection == AxisDirection.left;
      final childPaintShift =
          isReversed ? currentGeometry.paintExtent - contentExtent : 0.0;
      childParentData.paintOffset = constraints.axis == Axis.vertical
          ? Offset(0, childPaintShift)
          : Offset(childPaintShift, 0);
    } else {
      geometry = SliverGeometry.zero;
    }
    commitLayout(
      refreshStyle == RefreshStyle.front ? 0 : layoutExtent,
      hidden: !isIndicatorVisible,
      expanded: hasLayoutExtent,
    );
  }

  @override
  double childMainAxisPosition(RenderBox child) {
    final isReversed = constraints.axisDirection == AxisDirection.up ||
        constraints.axisDirection == AxisDirection.left;
    return isReversed ? -paintOffsetY : paintOffsetY;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final currentGeometry = geometry;
    if (layoutResult?.hidden != false ||
        currentGeometry == null ||
        !currentGeometry.visible) {
      return;
    }
    final indicatorPaintOffset = offset +
        (constraints.axis == Axis.vertical
            ? Offset(0, paintOffsetY)
            : Offset(paintOffsetY, 0));
    if (refreshStyle == RefreshStyle.behind) {
      final clip = constraints.axis == Axis.vertical
          ? Rect.fromLTWH(
              0,
              0,
              constraints.crossAxisExtent,
              currentGeometry.paintExtent,
            )
          : Rect.fromLTWH(
              0,
              0,
              currentGeometry.paintExtent,
              constraints.crossAxisExtent,
            );
      context.pushClipRect(
        needsCompositing,
        indicatorPaintOffset,
        clip,
        (context, offset) => super.paint(context, offset),
      );
    } else {
      super.paint(context, indicatorPaintOffset);
    }
  }

  @override
  Rect? describeApproximatePaintClip(RenderObject child) {
    final currentGeometry = geometry;
    if (refreshStyle != RefreshStyle.behind || currentGeometry == null) {
      return null;
    }
    return constraints.axis == Axis.vertical
        ? Rect.fromLTWH(
            0,
            0,
            constraints.crossAxisExtent,
            currentGeometry.paintExtent,
          )
        : Rect.fromLTWH(
            0,
            0,
            currentGeometry.paintExtent,
            constraints.crossAxisExtent,
          );
  }

  @override
  void applyPaintTransform(RenderObject child, Matrix4 transform) {
    super.applyPaintTransform(child, transform);
    if (constraints.axis == Axis.vertical) {
      transform.translateByDouble(0.0, paintOffsetY, 0, 1);
    } else {
      transform.translateByDouble(paintOffsetY, 0.0, 0, 1);
    }
  }
}

/// Render footer sliver widget
class SliverLoading extends SingleChildRenderObjectWidget {
  const SliverLoading({
    super.key,
    this.mode = LoadStatus.idle,
    this.floating = false,
    this.layoutExtent,
    this.hideWhenNotFull = false,
    super.child,
  });

  /// Whether to hide the footer when content does not fill the viewport.
  final bool hideWhenNotFull;

  final bool floating;

  /// load state
  final LoadStatus mode;

  final double? layoutExtent;

  @override
  RenderSliverLoading createRenderObject(BuildContext context) {
    return RenderSliverLoading(
      hideWhenNotFull: hideWhenNotFull,
      mode: mode,
      hasLayoutExtent: floating,
      layoutExtent: layoutExtent,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderSliverLoading renderObject,
  ) {
    renderObject
      ..mode = mode
      ..hasLayoutExtent = floating
      ..configuredExtent = layoutExtent
      ..hideWhenNotFull = hideWhenNotFull;
  }
}

class RenderSliverLoading extends RenderSliverSingleBoxAdapter
    with IndicatorExtentLayout {
  RenderSliverLoading({
    RenderBox? child,
    LoadStatus mode = LoadStatus.idle,
    double? layoutExtent,
    bool hasLayoutExtent = false,
    bool hideWhenNotFull = false,
  })  : _mode = mode,
        _hideWhenNotFull = hideWhenNotFull,
        _hasLayoutExtent = hasLayoutExtent {
    configuredExtent = layoutExtent;
    this.child = child;
  }

  bool _hideWhenNotFull;

  LoadStatus _mode;

  bool _hasLayoutExtent;

  bool get hideWhenNotFull => _hideWhenNotFull;

  set hideWhenNotFull(bool value) {
    if (value == _hideWhenNotFull) return;
    _hideWhenNotFull = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  bool get hiddenByContent =>
      layoutResult == null ||
      (hideWhenNotFull &&
          mode != LoadStatus.noMore &&
          !_contentExceedsViewport(constraints));

  LoadStatus get mode => _mode;

  set mode(LoadStatus value) {
    if (value == _mode) return;
    _mode = value;
    markNeedsLayout();
    markNeedsSemanticsUpdate();
  }

  double get layoutExtent => effectiveExtent;

  bool get hasLayoutExtent => _hasLayoutExtent;

  set hasLayoutExtent(bool value) {
    if (value == _hasLayoutExtent) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  bool _contentExceedsViewport(SliverConstraints sliverConstraints) {
    final RenderViewport viewport = parent as RenderViewport;
    RenderSliver? precedingSliver = viewport.firstChild;
    double contentScrollExtent = sliverConstraints.precedingScrollExtent;
    while (precedingSliver != null && precedingSliver != this) {
      if (precedingSliver is RenderSliverRefresh) {
        contentScrollExtent -= precedingSliver.occupiedExtent;
        break;
      }
      precedingSliver = viewport.childAfter(precedingSliver);
    }

    return contentScrollExtent > sliverConstraints.viewportMainAxisExtent;
  }

  @override
  void debugAssertDoesMeetConstraints() {
    final currentGeometry = geometry;
    if (currentGeometry == null) {
      throw FlutterError('A laid-out indicator must have SliverGeometry.');
    }
    assert(
      currentGeometry.debugAssertIsValid(
        informationCollector: () sync* {
          yield describeForError(
            'The RenderSliver that returned the offending geometry was',
          );
        },
      ),
    );
    assert(() {
      if (currentGeometry.paintExtent > constraints.remainingPaintExtent) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'SliverGeometry has a paintOffset that exceeds the remainingPaintExtent from the constraints.',
          ),
          describeForError(
            'The render object whose geometry violates the constraints is the following',
          ),
          ErrorDescription(
            'The paintExtent must cause the child sliver to paint within the viewport, and so '
            'cannot exceed the remainingPaintExtent.',
          ),
        ]);
      }
      return true;
    }());
  }

  @override
  void performLayout() {
    assert(constraints.growthDirection == GrowthDirection.forward);
    final currentChild = child;
    if (currentChild == null) {
      measureContent();
      geometry = SliverGeometry.zero;
      commitLayout(0, hidden: true, expanded: hasLayoutExtent);
      return;
    }
    final contentExceedsViewport = _contentExceedsViewport(constraints);
    final isIndicatorVisible =
        !hideWhenNotFull || mode == LoadStatus.noMore || contentExceedsViewport;
    final childExtent = measureContent();
    final double paintedChildSize = calculatePaintOffset(
      constraints,
      from: 0.0,
      to: childExtent,
    );
    final double cacheExtent = calculateCacheOffset(
      constraints,
      from: 0.0,
      to: childExtent,
    );
    assert(paintedChildSize.isFinite);
    assert(paintedChildSize >= 0.0);
    final SliverGeometry currentGeometry;
    if (isIndicatorVisible) {
      currentGeometry = SliverGeometry(
        scrollExtent: _hasLayoutExtent ? layoutExtent : 0,
        paintExtent: paintedChildSize,
        paintOrigin: constraints.axisDirection == AxisDirection.up ||
                constraints.axisDirection == AxisDirection.left
            ? (_hasLayoutExtent ? 0.0 : layoutExtent)
            : 0.0,
        cacheExtent: cacheExtent,
        maxPaintExtent: childExtent,
        hitTestExtent: paintedChildSize,
        visible: true,
        hasVisualOverflow: true,
      );
      setChildParentData(currentChild, constraints, currentGeometry);
    } else {
      currentGeometry = SliverGeometry.zero;
    }
    geometry = currentGeometry;
    commitLayout(
      currentGeometry.scrollExtent,
      hidden: !isIndicatorVisible,
      expanded: hasLayoutExtent,
    );
  }
}
