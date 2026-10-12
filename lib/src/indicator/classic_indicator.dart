import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sliver_refresher/sliver_refresher.dart';

/// direction that icon should place to the text
enum IconPosition { left, right, top, bottom }

/// wrap child in outside,mostly use in add background color and padding
typedef OuterBuilder = Widget Function(Widget child);

/// Refresh indicator with a label and icon.
class ClassicHeader extends SliverRefreshIndicator {
  const ClassicHeader({
    super.key,
    super.refreshStyle,
    double super.height,
    super.completeDuration = const Duration(milliseconds: 600),
    this.outerBuilder,
    this.textStyle = const TextStyle(color: Colors.grey),
    this.releaseText,
    this.refreshingText,
    this.completeText,
    this.failedText,
    this.idleText,
    this.iconPos = IconPosition.left,
    this.spacing = 15.0,
    this.refreshingIcon,
    this.failedIcon = const Icon(Icons.error, color: Colors.grey),
    this.completeIcon = const Icon(Icons.done, color: Colors.grey),
    this.idleIcon = const Icon(Icons.arrow_downward, color: Colors.grey),
    this.releaseIcon = const Icon(Icons.refresh, color: Colors.grey),
  });

  /// Wraps the indicator content, for example with padding or a background.
  final OuterBuilder? outerBuilder;

  final String? releaseText, idleText, refreshingText, completeText, failedText;

  final Widget? releaseIcon, idleIcon, refreshingIcon, completeIcon, failedIcon;

  /// icon and text middle margin
  final double spacing;

  final IconPosition iconPos;

  final TextStyle textStyle;

  /// Wraps the classic content while retaining one refresh lifecycle.
  @protected
  Widget wrapContent(BuildContext context, Widget child, RefreshStatus mode) {
    return outerBuilder?.call(child) ??
        SizedBox(
          height: height,
          child: Center(child: child),
        );
  }

  @override
  State createState() {
    return _ClassicHeaderState();
  }
}

class _ClassicHeaderState extends SliverRefreshIndicatorState<ClassicHeader> {
  Widget _buildText(RefreshStatus mode) {
    RefreshString strings =
        RefreshLocalizations.of(context)?.currentLocalization ??
            EnRefreshString();
    return Text(
      switch (mode) {
        RefreshStatus.canRefresh =>
          widget.releaseText ?? strings.canRefreshText,
        RefreshStatus.completed =>
          widget.completeText ?? strings.refreshCompleteText,
        RefreshStatus.failed => widget.failedText ?? strings.refreshFailedText,
        RefreshStatus.refreshing =>
          widget.refreshingText ?? strings.refreshingText,
        RefreshStatus.idle => widget.idleText ?? strings.idleRefreshText,
      },
      style: widget.textStyle,
    );
  }

  Widget _buildIcon(RefreshStatus mode) {
    final icon = switch (mode) {
      RefreshStatus.canRefresh => widget.releaseIcon,
      RefreshStatus.completed => widget.completeIcon,
      RefreshStatus.failed => widget.failedIcon,
      RefreshStatus.refreshing => widget.refreshingIcon ??
          SizedBox(
            width: 25.0,
            height: 25.0,
            child: defaultTargetPlatform == TargetPlatform.iOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(strokeWidth: 2.0),
          ),
      RefreshStatus.idle => widget.idleIcon,
    };
    return icon ?? Container();
  }

  @override
  bool needReverseAll() {
    return false;
  }

  @override
  Widget buildContent(BuildContext context, RefreshStatus mode) {
    Widget textWidget = _buildText(mode);
    Widget iconWidget = _buildIcon(mode);
    List<Widget> children = <Widget>[iconWidget, textWidget];
    final Widget container = Wrap(
      spacing: widget.spacing,
      textDirection: widget.iconPos == IconPosition.left
          ? TextDirection.ltr
          : TextDirection.rtl,
      direction: switch (widget.iconPos) {
        IconPosition.bottom || IconPosition.top => Axis.vertical,
        IconPosition.left || IconPosition.right => Axis.horizontal,
      },
      crossAxisAlignment: WrapCrossAlignment.center,
      verticalDirection: widget.iconPos == IconPosition.bottom
          ? VerticalDirection.up
          : VerticalDirection.down,
      alignment: WrapAlignment.center,
      children: children,
    );
    return widget.wrapContent(context, container, mode);
  }
}

/// Load-more indicator with a label and icon.
class ClassicFooter extends SliverLoadIndicator {
  const ClassicFooter({
    super.key,
    super.onClick,
    super.loadStyle,
    double super.height,
    this.outerBuilder,
    this.textStyle = const TextStyle(color: Colors.grey),
    this.loadingText,
    this.noDataText,
    this.noMoreIcon,
    this.idleText,
    this.failedText,
    this.canLoadingText,
    this.failedIcon = const Icon(Icons.error, color: Colors.grey),
    this.iconPos = IconPosition.left,
    this.spacing = 15.0,
    this.completeDuration = const Duration(milliseconds: 300),
    this.loadingIcon,
    this.canLoadingIcon = const Icon(Icons.autorenew, color: Colors.grey),
    this.idleIcon = const Icon(Icons.arrow_upward, color: Colors.grey),
  });

  final String? idleText, loadingText, noDataText, failedText, canLoadingText;

  /// Wraps the indicator content, for example with padding or a background.
  final OuterBuilder? outerBuilder;

  final Widget? idleIcon, loadingIcon, noMoreIcon, failedIcon, canLoadingIcon;

  /// icon and text middle margin
  final double spacing;

  final IconPosition iconPos;

  final TextStyle textStyle;

  final Duration completeDuration;

  @override
  State<StatefulWidget> createState() {
    return _ClassicFooterState();
  }
}

class _ClassicFooterState extends SliverLoadIndicatorState<ClassicFooter> {
  Widget _buildText(LoadStatus mode) {
    RefreshString strings =
        RefreshLocalizations.of(context)?.currentLocalization ??
            EnRefreshString();
    return Text(
      switch (mode) {
        LoadStatus.loading => widget.loadingText ?? strings.loadingText,
        LoadStatus.noMore => widget.noDataText ?? strings.noMoreText,
        LoadStatus.failed => widget.failedText ?? strings.loadFailedText,
        LoadStatus.canLoading =>
          widget.canLoadingText ?? strings.canLoadingText,
        LoadStatus.idle => widget.idleText ?? strings.idleLoadingText,
      },
      style: widget.textStyle,
    );
  }

  Widget _buildIcon(LoadStatus mode) {
    final icon = switch (mode) {
      LoadStatus.loading => widget.loadingIcon ??
          SizedBox(
            width: 25.0,
            height: 25.0,
            child: defaultTargetPlatform == TargetPlatform.iOS
                ? const CupertinoActivityIndicator()
                : const CircularProgressIndicator(strokeWidth: 2.0),
          ),
      LoadStatus.noMore => widget.noMoreIcon,
      LoadStatus.failed => widget.failedIcon,
      LoadStatus.canLoading => widget.canLoadingIcon,
      LoadStatus.idle => widget.idleIcon,
    };
    return icon ?? Container();
  }

  @override
  Future endLoading() {
    return Future.delayed(widget.completeDuration);
  }

  @override
  Widget buildContent(BuildContext context, LoadStatus mode) {
    Widget textWidget = _buildText(mode);
    Widget iconWidget = _buildIcon(mode);
    List<Widget> children = <Widget>[iconWidget, textWidget];
    final Widget container = Wrap(
      spacing: widget.spacing,
      textDirection: widget.iconPos == IconPosition.left
          ? TextDirection.ltr
          : TextDirection.rtl,
      direction: switch (widget.iconPos) {
        IconPosition.bottom || IconPosition.top => Axis.vertical,
        IconPosition.left || IconPosition.right => Axis.horizontal,
      },
      crossAxisAlignment: WrapCrossAlignment.center,
      verticalDirection: widget.iconPos == IconPosition.bottom
          ? VerticalDirection.up
          : VerticalDirection.down,
      alignment: WrapAlignment.center,
      children: children,
    );
    return widget.outerBuilder?.call(container) ??
        SizedBox(
          height: widget.height,
          child: Center(child: container),
        );
  }
}
