import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Откладывает [setState] на следующий кадр — избегает ошибок mouse_tracker
/// и gesture arena при навигации / hover во время rebuild.
void deferSetState(State state, VoidCallback fn) {
  if (!state.mounted) return;
  SchedulerBinding.instance.addPostFrameCallback((_) {
    if (state.mounted) state.setState(fn);
  });
}
