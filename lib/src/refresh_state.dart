import 'package:flutter/foundation.dart';

/// header state
enum RefreshStatus {
  /// Initial state, when not being overscrolled into, or after the overscroll
  /// is canceled or after done and the sliver retracted away.
  idle,

  /// Dragged far enough that the onRefresh callback will callback
  canRefresh,

  /// the indicator is refreshing,waiting for the finish callback
  refreshing,

  /// the indicator refresh completed
  completed,

  /// the indicator refresh failed
  failed,
}

///  footer state
enum LoadStatus {
  /// Initial state, which can be triggered loading more by gesture pull up
  idle,

  canLoading,

  /// indicator is loading more data
  loading,

  /// indicator is no more data to loading,this state doesn't allow to load more whatever
  noMore,

  /// Loading failed; subsequent scrolling may retry loading.
  failed
}

/// Refresh and loading state that can be used without a mounted UI.
/// The caller owns and disposes this object.
///
/// Mounted indicators listen to both notifiers and render their current values,
/// including values set before mounting. State changes do not request scrolling
/// or invoke business callbacks. A mounted header handles completion animations
/// and returns completed or failed refreshes to idle when it retracts.
class RefreshState {
  RefreshState({
    RefreshStatus initialRefreshStatus = RefreshStatus.idle,
    LoadStatus initialLoadStatus = LoadStatus.idle,
  })  : headerMode = RefreshNotifier(initialRefreshStatus),
        footerMode = RefreshNotifier(initialLoadStatus);

  RefreshNotifier<RefreshStatus> headerMode;

  RefreshNotifier<LoadStatus> footerMode;

  RefreshStatus get headerStatus => headerMode.value;

  LoadStatus get footerStatus => footerMode.value;

  bool get isRefresh => headerStatus == RefreshStatus.refreshing;

  bool get isLoading => footerStatus == LoadStatus.loading;

  /// Updates the indicator without calling onRefresh or requesting scrolling.
  void startRefresh() {
    headerMode.value = RefreshStatus.refreshing;
  }

  /// Updates the indicator without calling onLoading or requesting scrolling.
  void startLoading() {
    footerMode.value = LoadStatus.loading;
  }

  void refreshCompleted({bool resetFooterState = false}) {
    headerMode.value = RefreshStatus.completed;
    if (resetFooterState) resetNoData();
  }

  void refreshFailed() {
    headerMode.value = RefreshStatus.failed;
  }

  void refreshToIdle() {
    headerMode.value = RefreshStatus.idle;
  }

  void loadComplete() {
    footerMode.value = LoadStatus.idle;
  }

  void loadFailed() {
    footerMode.value = LoadStatus.failed;
  }

  void loadNoData() {
    footerMode.value = LoadStatus.noMore;
  }

  void resetNoData() {
    if (footerStatus == LoadStatus.noMore) footerMode.value = LoadStatus.idle;
  }

  void dispose() {
    headerMode.dispose();
    footerMode.dispose();
  }
}

class RefreshNotifier<T> extends ChangeNotifier implements ValueListenable<T> {
  /// Creates a [ChangeNotifier] that wraps this value.
  RefreshNotifier(this._value);
  T _value;

  @override
  T get value => _value;

  set value(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
    notifyListeners();
  }

  void setValueWithNoNotify(T newValue) {
    if (_value == newValue) return;
    _value = newValue;
  }

  @override
  String toString() => '${describeIdentity(this)}($value)';
}
