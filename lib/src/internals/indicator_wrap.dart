import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../sliver_refresher.dart';
import 'slivers.dart';

typedef VoidFutureCallBack = Future<void> Function();

typedef OffsetCallBack = void Function(double offset);

typedef ModeChangeCallBack<T> = void Function(T mode);

/// Sliver-based header supporting pull-to-refresh display styles.
abstract class SliverRefreshIndicator extends StatefulWidget {
  const SliverRefreshIndicator({
    super.key,
    this.height = 60.0,
    this.offset = 0.0,
    this.completeDuration = const Duration(milliseconds: 500),
    this.refreshStyle = RefreshStyle.follow,
  }) : assert(height == null || (height >= 0 && height < double.infinity));

  /// refresh display style
  final RefreshStyle refreshStyle;

  /// Main-axis extent override; null uses the content layout size.
  final double? height;

  final double offset;

  /// the stopped time when refresh complete or fail
  final Duration completeDuration;
}

/// a widget  implements  pull up load
abstract class SliverLoadIndicator extends StatefulWidget {
  const SliverLoadIndicator({
    super.key,
    this.onClick,
    this.loadStyle = LoadStyle.showAlways,
    this.height = 60.0,
  }) : assert(height == null || (height >= 0 && height < double.infinity));

  /// load more display style
  final LoadStyle loadStyle;

  /// Main-axis extent override; null uses the content layout size.
  final double? height;

  /// callback when user click footer
  final VoidCallback? onClick;
}

/// Refresh indicator lifecycle and scroll coordination.
abstract class SliverRefreshIndicatorState<T extends SliverRefreshIndicator>
    extends State<T>
    with IndicatorStateMixin<T, RefreshStatus>, RefreshProcessor {
  bool _needsRefreshSettlement = false;

  @override
  bool get _isRefreshIndicator => true;

  @override
  bool get _isActiveMode => mode == RefreshStatus.refreshing;

  @override
  RefreshNotifier<RefreshStatus> _resolveModeNotifier(
          SliverRefresher refresher) =>
      refresher.state.headerMode;

  @override
  void _prepareActiveMode() {
    readyToRefresh();
  }

  void _enterRefresh() {
    _needsRefreshSettlement = true;
    floating = true;
    update();
    final isCurrent = captureOperation();
    readyToRefresh().then((_) {
      if (!isCurrent()) return;
      mode = RefreshStatus.refreshing;
      if (!mounted || mode != RefreshStatus.refreshing) return;
      refresher.onRefresh?.call();
      _settleRefresh();
    });
  }

  void _settleRefresh() {
    if (!_needsRefreshSettlement ||
        settling ||
        mode != RefreshStatus.refreshing ||
        refresherState.isDragging) {
      return;
    }
    _needsRefreshSettlement = false;
    settleToEdge(leading: true, isCurrent: captureOperation());
  }

  @override
  void _handleScrollNotification() {
    super._handleScrollNotification();
    if (mode == RefreshStatus.refreshing) _settleRefresh();
  }

  bool _inVisual() {
    final position = _scrollPosition;
    return position.pixels < 0.0;
  }

  @override
  double _calculateScrollOffset(IndicatorLayoutResult layout) {
    final position = _scrollPosition;
    if (!floating) return -position.pixels;
    final extent = layout.effectiveExtent;
    return extent - position.pixels;
  }

  @override
  void _onOffsetChanged(double offset) {
    if (!floating &&
        (mode == RefreshStatus.completed || mode == RefreshStatus.failed) &&
        !_inVisual()) {
      mode = RefreshStatus.idle;
    }
    onOffsetChange(offset);
  }

  @override
  void _dispatchModeByOffset(double offset) {
    final position = _scrollPosition;
    if (floating) return;
    if (offset == 0.0) {
      mode = RefreshStatus.idle;
    }

    // If FrontStyle overScroll,it shouldn't disable gesture in scrollable
    if (position.extentBefore == 0.0 &&
        widget.refreshStyle == RefreshStyle.front) {
      position.context.setIgnorePointer(false);
    }
    if (mode == RefreshStatus.completed || mode == RefreshStatus.failed) return;
    final scroll = refresherState;
    if (scroll.isDragging) {
      if (refresher.enablePullDown &&
          offset >= refresher.headerTriggerDistance) {
        mode = RefreshStatus.canRefresh;
      } else if (refresher.enablePullDown) {
        mode = RefreshStatus.idle;
      }
    } else if ((scroll.isBallistic || scroll.isIdle) &&
        mode == RefreshStatus.canRefresh) {
      _enterRefresh();
    }
  }

  @override
  void _handleModeChange() {
    if (!mounted) {
      return;
    }
    update();
    if (mode != RefreshStatus.refreshing && mode != RefreshStatus.canRefresh) {
      _needsRefreshSettlement = false;
    }
    if (mode == RefreshStatus.idle || mode == RefreshStatus.canRefresh) {
      floating = false;

      resetValue();

      if (mode == RefreshStatus.idle) refresherState.setCanDrag(true);
    }
    if (mode == RefreshStatus.completed || mode == RefreshStatus.failed) {
      final isCurrent = captureOperation();
      endRefresh().then((_) {
        if (!isCurrent()) return;
        floating = false;
        refresherState.setCanDrag(false);
        update();
        settleToEdge(leading: true, isCurrent: isCurrent, onlyOutOfRange: true)
            .then((settled) {
          if (settled && isCurrent() && !_inVisual()) {
            mode = RefreshStatus.idle;
          }
        });
      });
    } else if (mode == RefreshStatus.refreshing) {
      if (!refresherState.isRequestingIndicator(true)) {
        refresherState.setCanDrag(true);
      }
      if (!floating) {
        floating = true;
        readyToRefresh();
      }
    }
    onModeChange(mode);
  }

  @override
  void onOffsetChange(double offset) {}

  @override
  void onModeChange(RefreshStatus mode) {}

  @override
  Future<void> readyToRefresh() {
    return Future.value();
  }

  @override
  Future<void> endRefresh() {
    return Future.delayed(widget.completeDuration);
  }

  bool needReverseAll() {
    return true;
  }

  @override
  void resetValue() {}

  @override
  Widget build(BuildContext context) {
    return SliverRefresh(
      paintOffsetY: widget.offset,
      floating: floating,
      refreshIndicatorLayoutExtent: widget.height,
      refreshStyle: widget.refreshStyle,
      child: RotatedBox(
        quarterTurns: needReverseAll() &&
                Scrollable.of(context).axisDirection == AxisDirection.up
            ? 10
            : 0,
        child: RepaintBoundary(
          child: buildContent(context, mode),
        ),
      ),
    );
  }
}

abstract class SliverLoadIndicatorState<T extends SliverLoadIndicator>
    extends State<T> with IndicatorStateMixin<T, LoadStatus>, LoadingProcessor {
  bool _enableLoading = false;

  LoadStatus _lastMode = LoadStatus.idle;

  bool _pendingLoading = false;

  @override
  bool get _isRefreshIndicator => false;

  @override
  bool get _isActiveMode => mode == LoadStatus.loading;

  @override
  RefreshNotifier<LoadStatus> _resolveModeNotifier(SliverRefresher refresher) =>
      refresher.state.footerMode;

  @override
  void _prepareActiveMode() {
    readyToLoad();
  }

  bool get _isHide {
    final render = context.findRenderObject();
    return render is! RenderSliverLoading || render.hiddenByContent;
  }

  @override
  double _calculateScrollOffset(IndicatorLayoutResult layout) {
    final position = _scrollPosition;
    final double overScrollPastEnd = math.max(
      position.pixels - position.maxScrollExtent,
      0.0,
    );
    return overScrollPastEnd;
  }

  void enterLoading() {
    if (_pendingLoading || mode == LoadStatus.loading) return;
    _pendingLoading = true;
    setState(() {
      floating = true;
    });
    _enableLoading = false;
    final isCurrent = captureOperation();
    readyToLoad().then((_) {
      if (!isCurrent()) return;
      _pendingLoading = false;
      mode = LoadStatus.loading;
      if (!mounted || mode != LoadStatus.loading) return;
      refresher.onLoading?.call();
    });
  }

  @override
  void onOffsetChange(double offset) {}

  @override
  void onModeChange(LoadStatus mode) {}

  @override
  Future<void> readyToLoad() => Future<void>.value();

  @override
  void resetValue() {}

  @override
  Future endLoading() {
    return Future.delayed(Duration(milliseconds: 0));
  }

  void finishLoading() {
    if (!floating) {
      return;
    }
    final isCurrent = captureOperation();
    endLoading().then((_) {
      if (!isCurrent()) return;

      settleToEdge(leading: false, isCurrent: isCurrent, onlyOutOfRange: true);
      setState(() {
        floating = false;
      });
    });
  }

  bool _checkIfCanLoading() {
    final position = _scrollPosition;
    if (position.maxScrollExtent - position.pixels <=
            refresher.footerTriggerDistance &&
        position.extentBefore > 2.0 &&
        _enableLoading) {
      if (mode == LoadStatus.noMore) {
        return false;
      }
      if (mode != LoadStatus.canLoading &&
          position.userScrollDirection == ScrollDirection.forward) {
        return false;
      }
      return true;
    }
    return false;
  }

  @override
  void _handleModeChange() {
    if (!mounted) return;

    update();
    if (mode == LoadStatus.idle ||
        mode == LoadStatus.failed ||
        mode == LoadStatus.noMore) {
      _enableLoading = false;
      _pendingLoading = false;
      finishLoading();
    }
    if (mode == LoadStatus.loading) {
      _enableLoading = false;
      if (!floating) {
        floating = true;
        readyToLoad();
      }
      if (widget.loadStyle == LoadStyle.showWhenLoading) {
        floating = true;
      }
    } else {
      if (!refresherState.isDragging) _enableLoading = false;
    }
    if (mode != LoadStatus.canLoading) _lastMode = mode;
    onModeChange(mode);
  }

  @override
  void _dispatchModeByOffset(double offset) {
    if (!mounted || _isHide || LoadStatus.loading == mode || floating) {
      return;
    }
    if (refresherState.isDragging) {
      if (_checkIfCanLoading()) {
        mode = LoadStatus.canLoading;
      } else {
        mode = _lastMode;
      }
    }
    if (refresherState.isBallistic || refresherState.isDriven) {
      if ((mode == LoadStatus.canLoading && _enableLoading) ||
          _checkIfCanLoading()) {
        enterLoading();
      }
    }
  }

  @override
  void _handleOffsetChange() {
    if (_isHide) {
      return;
    }
    super._handleOffsetChange();
  }

  @override
  void _onOffsetChanged(double offset) => onOffsetChange(offset);

  @override
  void _handleScrollNotification() {
    if (settling || _isHide) return;
    final scroll = refresherState;
    if ((scroll.isDragging || scroll.isDriven) &&
        !floating &&
        mode != LoadStatus.loading) {
      _enableLoading = true;
    }
    super._handleScrollNotification();
    if (scroll.isIdle &&
        !floating &&
        mode != LoadStatus.loading &&
        mode != LoadStatus.noMore &&
        ((mode == LoadStatus.canLoading && _enableLoading) ||
            _checkIfCanLoading())) {
      enterLoading();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mode != LoadStatus.canLoading) _lastMode = mode;
  }

  @override
  Widget build(BuildContext context) {
    return SliverLoading(
      hideWhenNotFull: refresher.hideFooterWhenNotFull,
      floating: switch (widget.loadStyle) {
        LoadStyle.showAlways => true,
        LoadStyle.hideAlways => false,
        LoadStyle.showWhenLoading => mode == LoadStatus.loading,
      },
      layoutExtent: widget.height,
      mode: mode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onClick,
        child: RepaintBoundary(
          child: buildContent(context, mode),
        ),
      ),
    );
  }
}

/// Shares state and scroll-position listeners between indicators.
mixin IndicatorStateMixin<T extends StatefulWidget, Status extends Object>
    on State<T> {
  // All dependencies are initialized in didChangeDependencies before
  // listeners, mode synchronization, or build can consume them.
  late SliverRefresher _refresher;

  late SliverRefresherState _refresherState;

  late ScrollPosition _scrollPosition;

  late RefreshNotifier<Status> _modeNotifier;

  late int _boundBindingVersion;

  bool _hasBinding = false;

  int _modeVersion = 0;

  int _settlementVersion = 0;

  bool _settling = false;

  bool _floating = false;

  SliverRefresher get refresher => _refresher;

  SliverRefresherState get refresherState => _refresherState;

  set floating(bool floating) => _floating = floating;

  bool get floating => _floating;

  IndicatorLayoutResult? get indicatorLayout {
    final renderObject = context.findRenderObject();
    return renderObject is IndicatorExtentLayout && !renderObject.layoutPending
        ? renderObject.layoutResult
        : null;
  }

  set mode(Status mode) => _modeNotifier.value = mode;

  Status get mode => _modeNotifier.value;

  bool Function() captureOperation() {
    final modeNotifier = _modeNotifier;
    final modeVersion = _modeVersion;
    final boundRefresherState = refresherState;
    final bindingVersion = boundRefresherState.bindingVersion;
    return () =>
        mounted &&
        identical(_modeNotifier, modeNotifier) &&
        modeVersion == _modeVersion &&
        identical(refresherState, boundRefresherState) &&
        bindingVersion == boundRefresherState.bindingVersion;
  }

  void _handleNotifierChange() {
    _modeVersion++;
    _handleModeChange();
  }

  bool get settling => _settling;

  /// Moves to a committed layout edge using Flutter's public scroll API.
  /// A new drag, binding or mode transition invalidates the operation.
  Future<bool> settleToEdge({
    required bool leading,
    required bool Function() isCurrent,
    bool onlyOutOfRange = false,
  }) async {
    if (!mounted) return false;
    final scrollState = refresherState;
    if (scrollState.isDragging) return false;
    final settlementVersion = ++_settlementVersion;
    _settling = true;
    var position = _scrollPosition;
    final initialInteractionVersion = scrollState.interactionVersion;
    bool isSettlementCurrent() =>
        isCurrent() &&
        settlementVersion == _settlementVersion &&
        identical(_scrollPosition, position) &&
        initialInteractionVersion == scrollState.interactionVersion &&
        !scrollState.isDragging;
    try {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return false;
      final currentPosition = _scrollPosition;
      position = currentPosition;
      if (!isSettlementCurrent()) return false;
      if (onlyOutOfRange &&
          (leading
              ? currentPosition.pixels >= currentPosition.minScrollExtent
              : currentPosition.pixels <= currentPosition.maxScrollExtent)) {
        return true;
      }
      final targetScrollOffset = leading
          ? currentPosition.minScrollExtent
          : currentPosition.maxScrollExtent;
      if ((currentPosition.pixels - targetScrollOffset).abs() > 0.01) {
        await currentPosition.animateTo(
          targetScrollOffset,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
        );
      }
      return isSettlementCurrent();
    } finally {
      if (settlementVersion == _settlementVersion) _settling = false;
    }
  }

  void _handleScrollNotification() => _handleOffsetChange();

  void update() {
    if (mounted) setState(() {});
  }

  void _handleOffsetChange() {
    if (!mounted) return;
    final scrollState = refresherState;
    if (settling || scrollState.isRequestingIndicator(_isRefreshIndicator)) {
      return;
    }
    final layout = indicatorLayout;
    if (layout == null) return;
    final indicatorOffset = _calculateScrollOffset(layout);
    if (indicatorOffset >= 0.0) {
      _dispatchModeByOffset(indicatorOffset);
    }
    _onOffsetChanged(indicatorOffset);
  }

  void _unbindListeners() {
    if (!_hasBinding) return;
    _modeNotifier.removeListener(_handleNotifierChange);
    _refresherState.removeScrollListener(_handleScrollNotification);
    _scrollPosition.removeListener(_handleOffsetChange);
    _hasBinding = false;
  }

  void _synchronizeBoundMode({required bool prepareActiveMode}) {
    floating = _isActiveMode;
    final isCurrent = captureOperation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isCurrent()) return;
      if (prepareActiveMode && _isActiveMode) _prepareActiveMode();
      _handleModeChange();
    });
  }

  void _updateBindings() {
    final newRefresher = SliverRefresher.of(context);
    final newRefresherState = SliverRefresher.ofState(context);
    if (newRefresher == null || newRefresherState == null) {
      throw FlutterError('An indicator must be inside a SliverRefresher.');
    }
    final newPosition = Scrollable.of(context).position;
    final newModeNotifier = _resolveModeNotifier(newRefresher);
    final hasModeNotifierChanged =
        !_hasBinding || !identical(_modeNotifier, newModeNotifier);
    final hasBindingChanged = !_hasBinding ||
        !identical(_refresherState, newRefresherState) ||
        _boundBindingVersion != newRefresherState.bindingVersion;
    final hasPositionChanged =
        !_hasBinding || !identical(_scrollPosition, newPosition);
    if (_hasBinding &&
        identical(_refresher, newRefresher) &&
        !hasModeNotifierChanged &&
        !hasBindingChanged &&
        !hasPositionChanged) {
      return;
    }

    _unbindListeners();
    if (hasModeNotifierChanged || hasBindingChanged) _modeVersion++;
    // Initialize every dependency before enabling or registering listeners.
    _refresher = newRefresher;
    _refresherState = newRefresherState;
    _scrollPosition = newPosition;
    _modeNotifier = newModeNotifier;
    _boundBindingVersion = newRefresherState.bindingVersion;
    _hasBinding = true;
    _refresherState.onPositionUpdated(_scrollPosition);
    _modeNotifier.addListener(_handleNotifierChange);
    _refresherState.addScrollListener(_handleScrollNotification);
    _scrollPosition.addListener(_handleOffsetChange);
    if (hasModeNotifierChanged || hasBindingChanged) {
      _synchronizeBoundMode(prepareActiveMode: hasModeNotifierChanged);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateBindings();
  }

  @override
  void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    _updateBindings();
  }

  @override
  void dispose() {
    _unbindListeners();
    super.dispose();
  }

  bool get _isRefreshIndicator;

  bool get _isActiveMode;

  RefreshNotifier<Status> _resolveModeNotifier(SliverRefresher refresher);

  void _prepareActiveMode();

  void _handleModeChange();

  double _calculateScrollOffset(IndicatorLayoutResult layout);

  void _onOffsetChanged(double offset);

  void _dispatchModeByOffset(double offset);

  Widget buildContent(BuildContext context, Status mode);
}

/// head Indicator exposure interface
abstract mixin class RefreshProcessor {
  /// out of edge offset callback
  void onOffsetChange(double offset);

  /// mode change callback
  void onModeChange(RefreshStatus mode);

  /// Completes before entering the active state and invoking the business callback.
  Future readyToRefresh();

  // when indicator is ready to dismiss layout ,it will callback and then spring back after finish
  Future endRefresh();

  // when indicator has been spring back,it  need to reset value
  void resetValue();
}

/// footer Indicator exposure interface
abstract mixin class LoadingProcessor {
  void onOffsetChange(double offset);

  void onModeChange(LoadStatus mode);

  /// Completes before entering the active state and invoking the business callback.
  Future readyToLoad();

  // when indicator is ready to dismiss layout ,it will callback and then spring back after finish
  Future endLoading();

  // when indicator has been spring back,it  need to reset value
  void resetValue();
}
