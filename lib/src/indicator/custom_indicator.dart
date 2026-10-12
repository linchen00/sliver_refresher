import 'package:flutter/widgets.dart';

import '../internals/indicator_wrap.dart';
import '../sliver_refresher.dart';

/// custom header builder,you can use second paramter to know what header state is
typedef HeaderBuilder = Widget Function(
    BuildContext context, RefreshStatus mode);

/// custom footer builder,you can use second paramter to know what footerr state is
typedef FooterBuilder = Widget Function(BuildContext context, LoadStatus mode);

/// Refresh indicator with custom content and lifecycle callbacks.
class CustomHeader extends SliverRefreshIndicator {
  const CustomHeader({
    super.key,
    required this.builder,
    this.readyToRefresh,
    this.endRefresh,
    this.onOffsetChange,
    this.onModeChange,
    this.onResetValue,
    super.height = null,
    super.completeDuration = const Duration(milliseconds: 600),
    super.refreshStyle,
  });

  /// Builds content whose main-axis size is used when height is omitted.
  final HeaderBuilder builder;

  final VoidFutureCallBack? readyToRefresh;

  final VoidFutureCallBack? endRefresh;

  final OffsetCallBack? onOffsetChange;

  final ModeChangeCallBack<RefreshStatus>? onModeChange;

  final VoidCallback? onResetValue;

  @override
  State<StatefulWidget> createState() {
    return _CustomHeaderState();
  }
}

class _CustomHeaderState extends SliverRefreshIndicatorState<CustomHeader> {
  @override
  void onOffsetChange(double offset) {
    widget.onOffsetChange?.call(offset);
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(RefreshStatus mode) {
    widget.onModeChange?.call(mode);
    super.onModeChange(mode);
  }

  @override
  Future<void> readyToRefresh() {
    return widget.readyToRefresh?.call() ?? super.readyToRefresh();
  }

  @override
  Future<void> endRefresh() {
    return widget.endRefresh?.call() ?? super.endRefresh();
  }

  @override
  void resetValue() {
    widget.onResetValue?.call();
    super.resetValue();
  }

  @override
  Widget buildContent(BuildContext context, RefreshStatus mode) {
    return widget.builder(context, mode);
  }
}

/// Load-more indicator with custom content and lifecycle callbacks.
class CustomFooter extends SliverLoadIndicator {
  const CustomFooter({
    super.key,
    super.height = null,
    this.onModeChange,
    this.onOffsetChange,
    this.readyLoading,
    this.endLoading,
    super.loadStyle,
    required this.builder,
    super.onClick,
  });

  /// Builds content whose main-axis size is used when height is omitted.
  final FooterBuilder builder;

  final OffsetCallBack? onOffsetChange;

  final ModeChangeCallBack<LoadStatus>? onModeChange;

  final VoidFutureCallBack? readyLoading;

  final VoidFutureCallBack? endLoading;

  @override
  State<StatefulWidget> createState() {
    return _CustomFooterState();
  }
}

class _CustomFooterState extends SliverLoadIndicatorState<CustomFooter> {
  @override
  void onOffsetChange(double offset) {
    widget.onOffsetChange?.call(offset);
    super.onOffsetChange(offset);
  }

  @override
  void onModeChange(LoadStatus mode) {
    widget.onModeChange?.call(mode);
    super.onModeChange(mode);
  }

  @override
  Future readyToLoad() {
    return widget.readyLoading?.call() ?? super.readyToLoad();
  }

  @override
  Future endLoading() {
    return widget.endLoading?.call() ?? super.endLoading();
  }

  @override
  Widget buildContent(BuildContext context, LoadStatus mode) {
    return widget.builder(context, mode);
  }
}
