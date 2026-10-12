import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/widgets.dart';
import 'package:sliver_refresher/sliver_refresher.dart';

export 'refresh_state.dart';

/// header indicator display style
enum RefreshStyle {
  /// Moves with the content.
  follow,

  /// Stops moving once the indicator is fully visible.
  unFollow,

  /// Appears behind the content as the overscroll grows.
  behind,

  /// Appears over the content.
  front,
}

/// footer indicator display style
enum LoadStyle {
  /// Always occupies layout space.
  showAlways,

  /// Never occupies layout space.
  hideAlways,

  /// Occupies layout space only while loading.
  showWhenLoading,
}

/// Pull-to-refresh and load-more for scrollable content.
/// The caller owns [state]; [controller] optionally requests UI operations.
class SliverRefresher extends StatefulWidget {
  const SliverRefresher({
    super.key,
    required this.state,
    this.controller,
    this.enablePullDown = true,
    this.enablePullUp = false,
    this.headerTriggerDistance = 80.0,
    this.footerTriggerDistance = 15.0,
    this.initialRefresh = false,
    this.hideFooterWhenNotFull = false,
    this.scrollController,
    this.scrollDirection,
    this.reverse,
    this.primary,
    this.physics,
    this.dragStartBehavior,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.scrollCacheExtent,
    this.semanticChildCount,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.onRefresh,
    this.onLoading,
    this.header,
    this.footer,
    required this.slivers,
  })  : assert(
          headerTriggerDistance > 0 && headerTriggerDistance < double.infinity,
        ),
        assert(
          footerTriggerDistance > double.negativeInfinity &&
              footerTriggerDistance < double.infinity,
        );

  /// Externally owned refresh and loading state.
  final RefreshState state;

  /// Optional controller for requesting UI operations.
  final RefreshController? controller;

  final bool enablePullDown;

  final bool enablePullUp;

  /// Pull distance required to arm refresh before release.
  final double headerTriggerDistance;

  /// Remaining scroll distance at which loading can be triggered.
  final double footerTriggerDistance;

  /// Request a refresh after the first layout.
  final bool initialRefresh;

  /// Hides the footer for short content, except in the noMore state.
  final bool hideFooterWhenNotFull;

  final ScrollController? scrollController;

  final Axis? scrollDirection;

  final bool? reverse;

  final bool? primary;

  /// Defaults to BouncingScrollPhysics with AlwaysScrollableScrollPhysics.
  /// Supplied physics are respected; clamping physics prevent pull overscroll.
  final ScrollPhysics? physics;

  final DragStartBehavior? dragStartBehavior;

  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  final ScrollCacheExtent? scrollCacheExtent;

  final int? semanticChildCount;

  final String? restorationId;

  final Clip clipBehavior;

  /// Complete or fail the refresh through [RefreshState] after this callback.
  final VoidCallback? onRefresh;

  /// Complete or fail loading through [RefreshState] after this callback.
  final VoidCallback? onLoading;

  /// Indicator before the content. Use [CustomHeader] for custom content.
  final SliverRefreshIndicator? header;

  /// Indicator after the content. Use [CustomFooter] for custom content.
  final SliverLoadIndicator? footer;

  /// Body slivers, placed between the optional refresh and loading indicators.
  /// May be empty. Use SliverToBoxAdapter for box widgets and SliverPadding
  /// for body padding. This list is never modified by the refresher.
  final List<Widget> slivers;

  static SliverRefresher? of(BuildContext? context) {
    return context
        ?.dependOnInheritedWidgetOfExactType<_RefreshScope>()
        ?.refresher;
  }

  static SliverRefresherState? ofState(BuildContext? context) {
    return context
        ?.dependOnInheritedWidgetOfExactType<_RefreshScope>()
        ?.refresherState;
  }

  @override
  State<StatefulWidget> createState() {
    return SliverRefresherState();
  }
}

class SliverRefresherState extends State<SliverRefresher> {
  bool _canDrag = true;

  final SliverRefreshIndicator defaultHeader = ClassicHeader();

  final SliverLoadIndicator defaultFooter = ClassicFooter();

  static final Expando<SliverRefresherState> _bindings =
      Expando<SliverRefresherState>('RefreshState binding');

  ScrollPosition? _position;

  int _bindingVersion = 0;

  final Set<String> _requests = <String>{};

  final Set<VoidCallback> _scrollListeners = <VoidCallback>{};

  _ScrollPhase _scrollPhase = _ScrollPhase.idle;

  int interactionVersion = 0;

  ScrollPhysics _getScrollPhysics() {
    final physics = widget.physics ??
        const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
    return _canDrag ? physics : NeverScrollableScrollPhysics(parent: physics);
  }

  void setCanDrag(bool canDrag) {
    if (_canDrag == canDrag) {
      return;
    }
    setState(() {
      _canDrag = canDrag;
    });
  }

  ScrollPosition? get position => _position;

  int get bindingVersion => _bindingVersion;

  void _bindRefreshState() {
    final owner = _bindings[widget.state];
    if (owner != null && owner != this) {
      throw StateError('A RefreshState can only bind one SliverRefresher.');
    }
    _bindings[widget.state] = this;
  }

  bool get isDragging => _scrollPhase == _ScrollPhase.drag;

  bool get isDriven => _scrollPhase == _ScrollPhase.driven;

  bool get isBallistic => _scrollPhase == _ScrollPhase.ballistic;

  bool get isIdle => _scrollPhase == _ScrollPhase.idle;

  void onPositionUpdated(ScrollPosition newPosition) {
    if (identical(_position, newPosition)) return;
    _position = newPosition;
    _scrollPhase = _ScrollPhase.idle;
  }

  void addScrollListener(VoidCallback listener) =>
      _scrollListeners.add(listener);

  void removeScrollListener(VoidCallback listener) =>
      _scrollListeners.remove(listener);

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth != 0) return false;
    if (notification is ScrollStartNotification) {
      _scrollPhase = notification.dragDetails != null
          ? _ScrollPhase.drag
          : _ScrollPhase.driven;
      if (isDragging) interactionVersion++;
    } else if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification) {
      final dragging = notification is ScrollUpdateNotification
          ? notification.dragDetails != null
          : (notification as OverscrollNotification).dragDetails != null;
      if (dragging && !isDragging) interactionVersion++;
      if (dragging) {
        _scrollPhase = _ScrollPhase.drag;
      } else if (isDragging) {
        _scrollPhase = _ScrollPhase.ballistic;
      }
    } else if (notification is ScrollEndNotification) {
      _scrollPhase = _ScrollPhase.idle;
    } else {
      return false;
    }
    for (final listener in List<VoidCallback>.of(_scrollListeners)) {
      listener();
    }
    return false;
  }

  void _handleControllerDisposed() {
    _invalidateRequests();
    if (mounted) setState(() {});
  }

  void _invalidateRequests() {
    _bindingVersion++;
    _requests.clear();
    _canDrag = true;
  }

  bool _isCurrent(int bindingVersion, RefreshState state) =>
      mounted &&
      bindingVersion == _bindingVersion &&
      identical(widget.state, state);

  StatefulElement? _findIndicator(BuildContext context, Type indicatorType) {
    StatefulElement? indicatorElement;
    context.visitChildElements((childElement) {
      if ((indicatorType == SliverRefreshIndicator &&
              childElement.widget is SliverRefreshIndicator) ||
          (indicatorType == SliverLoadIndicator &&
              childElement.widget is SliverLoadIndicator)) {
        indicatorElement = childElement as StatefulElement;
      }
      indicatorElement ??= _findIndicator(childElement, indicatorType);
    });
    return indicatorElement;
  }

  bool isRequestingIndicator(bool isRefreshRequest) =>
      _requests.contains(isRefreshRequest ? 'refresh' : 'loading');

  Future<void> requestRefresh({
    bool needMove = true,
    bool needCallback = true,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
  }) =>
      _requestIndicator(true, needMove, needCallback, duration, curve);

  Future<void> requestLoading({
    bool needMove = true,
    bool needCallback = true,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.linear,
  }) =>
      _requestIndicator(false, needMove, needCallback, duration, curve);

  Future<void> _requestIndicator(
    bool isRefreshRequest,
    bool needMove,
    bool needCallback,
    Duration duration,
    Curve curve,
  ) async {
    final state = widget.state;
    final position = _position;
    final isIndicatorEnabled =
        isRefreshRequest ? widget.enablePullDown : widget.enablePullUp;
    if (!mounted || position == null || !isIndicatorEnabled) {
      throw StateError('The requested indicator is not mounted or enabled.');
    }
    final requestKey = isRefreshRequest ? 'refresh' : 'loading';
    if ((isRefreshRequest ? state.isRefresh : state.isLoading) ||
        _requests.contains(requestKey)) {
      return;
    }
    final indicatorElement = _findIndicator(
      position.context.storageContext,
      isRefreshRequest ? SliverRefreshIndicator : SliverLoadIndicator,
    );
    if (indicatorElement == null) {
      throw StateError('The requested indicator is unavailable.');
    }
    final indicator = indicatorElement.state as IndicatorStateMixin;
    final notifier = isRefreshRequest ? state.headerMode : state.footerMode;
    final bindingVersion = _bindingVersion;
    var hasModeChanged = false;
    var hasPublishedMode = false;
    var isPublishingMode = false;
    final initialInteractionVersion = interactionVersion;

    void handleModeChange() {
      // Only the transition owned by this request may change its notifier.
      // A synchronous mode hook can still cancel it with another transition.
      final isRequestedModeActive =
          isRefreshRequest ? state.isRefresh : state.isLoading;
      if (!isPublishingMode || !isRequestedModeActive) hasModeChanged = true;
    }

    notifier.addListener(handleModeChange);
    _requests.add(requestKey);
    indicator.floating = true;
    indicator.update();
    if (needMove) setCanDrag(false);
    try {
      if (needMove) {
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrent(bindingVersion, state) ||
            hasModeChanged ||
            initialInteractionVersion != interactionVersion ||
            !indicatorElement.state.mounted) {
          return;
        }
        final currentPosition = _position;
        if (currentPosition == null) return;
        if (indicator.indicatorLayout == null) {
          throw StateError('The requested indicator has not completed layout.');
        }
        await currentPosition.animateTo(
          isRefreshRequest
              ? currentPosition.minScrollExtent
              : currentPosition.maxScrollExtent,
          duration: duration,
          curve: curve,
        );
      } else {
        await Future<void>.value();
      }
      if (!_isCurrent(bindingVersion, state) ||
          hasModeChanged ||
          initialInteractionVersion != interactionVersion ||
          !indicatorElement.state.mounted) {
        return;
      }
      if (!identical(
          notifier, isRefreshRequest ? state.headerMode : state.footerMode)) {
        return;
      }
      if (isRefreshRequest) {
        await (indicatorElement.state as SliverRefreshIndicatorState)
            .readyToRefresh();
      } else {
        await (indicatorElement.state as SliverLoadIndicatorState)
            .readyToLoad();
      }
      if (!_isCurrent(bindingVersion, state) ||
          hasModeChanged ||
          initialInteractionVersion != interactionVersion ||
          !indicatorElement.state.mounted ||
          !identical(notifier,
              isRefreshRequest ? state.headerMode : state.footerMode)) {
        return;
      }
      hasPublishedMode = true;
      isPublishingMode = true;
      if (isRefreshRequest) {
        state.startRefresh();
      } else {
        state.startLoading();
      }
      isPublishingMode = false;
      if (needMove) {
        // Active content may have a different extent from the content used
        // during the reveal animation. Commit that layout before invoking the
        // business callback, which may complete the operation or add items.
        await WidgetsBinding.instance.endOfFrame;
        if (!_isCurrent(bindingVersion, state) ||
            hasModeChanged ||
            initialInteractionVersion != interactionVersion ||
            !indicatorElement.state.mounted) {
          return;
        }
        final currentPosition = _position;
        if (currentPosition == null) return;
        if (indicator.indicatorLayout == null) {
          throw StateError('The requested indicator has not completed layout.');
        }
        final targetScrollOffset = isRefreshRequest
            ? currentPosition.minScrollExtent
            : currentPosition.maxScrollExtent;
        if (currentPosition.pixels != targetScrollOffset) {
          currentPosition.jumpTo(targetScrollOffset);
        }
      }
      if (hasModeChanged ||
          initialInteractionVersion != interactionVersion ||
          !indicatorElement.state.mounted) {
        return;
      }
      if (needCallback && _isCurrent(bindingVersion, state)) {
        (isRefreshRequest ? widget.onRefresh : widget.onLoading)?.call();
      }
    } finally {
      notifier.removeListener(handleModeChange);
      if (_isCurrent(bindingVersion, state)) {
        _requests.remove(requestKey);
        if (needMove) setCanDrag(true);
        if (!hasPublishedMode &&
            !(isRefreshRequest ? state.isRefresh : state.isLoading)) {
          indicator.floating = false;
          indicator.update();
        }
      }
    }
  }

  @override
  void didUpdateWidget(SliverRefresher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enablePullDown &&
        (!widget.enablePullDown ||
            !Widget.canUpdate(oldWidget.header ?? defaultHeader,
                widget.header ?? defaultHeader))) {
      // A removed header cannot finish its retraction and restore dragging.
      _canDrag = true;
    }
    if (widget.state != oldWidget.state ||
        widget.controller != oldWidget.controller) {
      _invalidateRequests();
      if (widget.state != oldWidget.state) {
        if (_bindings[oldWidget.state] == this) {
          _bindings[oldWidget.state] = null;
        }
        _bindRefreshState();
      }
      if (widget.controller != oldWidget.controller) {
        oldWidget.controller?._detach(this);
        widget.controller?._bindState(this);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _bindRefreshState();
    widget.controller?._bindState(this);
    final version = _bindingVersion;
    if (widget.initialRefresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && version == _bindingVersion) requestRefresh();
      });
    }
  }

  @override
  void dispose() {
    _invalidateRequests();
    if (_bindings[widget.state] == this) _bindings[widget.state] = null;
    widget.controller?._detach(this);
    _scrollListeners.clear();
    _position = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _RefreshScope(
      refresher: widget,
      refresherState: this,
      bindingVersion: _bindingVersion,
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: CustomScrollView(
          controller: widget.scrollController,
          scrollDirection: widget.scrollDirection ?? Axis.vertical,
          reverse: widget.reverse ?? false,
          primary: widget.primary,
          scrollCacheExtent: widget.scrollCacheExtent,
          semanticChildCount: widget.semanticChildCount,
          dragStartBehavior:
              widget.dragStartBehavior ?? DragStartBehavior.start,
          keyboardDismissBehavior: widget.keyboardDismissBehavior,
          restorationId: widget.restorationId,
          clipBehavior: widget.clipBehavior,
          physics: _getScrollPhysics(),
          slivers: <Widget>[
            if (widget.enablePullDown) widget.header ?? defaultHeader,
            ...widget.slivers,
            if (widget.enablePullUp) widget.footer ?? defaultFooter,
          ],
        ),
      ),
    );
  }
}

enum _ScrollPhase { idle, drag, driven, ballistic }

class _RefreshScope extends InheritedWidget {
  const _RefreshScope({
    required this.refresher,
    required this.refresherState,
    required this.bindingVersion,
    required super.child,
  });
  final SliverRefresher refresher;
  final SliverRefresherState refresherState;
  final int bindingVersion;

  @override
  bool updateShouldNotify(_RefreshScope oldWidget) =>
      oldWidget.refresher != refresher ||
      oldWidget.bindingVersion != bindingVersion;
}

/// Requests UI operations on one bound [SliverRefresher].
/// The caller owns this controller and its separate [RefreshState].
class RefreshController {
  RefreshController();

  SliverRefresherState? _refresherState;

  bool _disposed = false;

  ScrollPosition? get position => _refresherState?.position;

  SliverRefresherState get _boundState {
    final state = _refresherState;
    if (_disposed || state == null || !state.mounted) {
      throw StateError(
        'RefreshController is disposed or not bound to a SliverRefresher.',
      );
    }
    return state;
  }

  void _bindState(SliverRefresherState state) {
    if (_disposed) {
      throw StateError('Cannot bind a disposed RefreshController.');
    }
    if (_refresherState != null && _refresherState != state) {
      throw StateError(
          'A RefreshController can only bind one SliverRefresher.');
    }
    _refresherState = state;
  }

  void _detach(SliverRefresherState state) {
    if (_refresherState == state) _refresherState = null;
  }

  Future<void> requestRefresh({
    bool needMove = true,
    bool needCallback = true,
    Duration duration = const Duration(milliseconds: 500),
    Curve curve = Curves.linear,
  }) async =>
      _boundState.requestRefresh(
        needMove: needMove,
        needCallback: needCallback,
        duration: duration,
        curve: curve,
      );

  Future<void> requestLoading({
    bool needMove = true,
    bool needCallback = true,
    Duration duration = const Duration(milliseconds: 300),
    Curve curve = Curves.linear,
  }) async =>
      _boundState.requestLoading(
        needMove: needMove,
        needCallback: needCallback,
        duration: duration,
        curve: curve,
      );

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    final state = _refresherState;
    state?._handleControllerDisposed();
    _refresherState = null;
  }
}
