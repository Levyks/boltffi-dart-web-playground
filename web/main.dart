import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'generated/playground.dart';

typedef Pattern = ({
  String group,
  String name,
  FutureOr<String> Function() run,
});

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<T> catches<T>(FutureOr<void> Function() action) async {
  try {
    await action();
  } catch (error) {
    if (error is T) return error as T;
    rethrow;
  }
  throw StateError('Expected $T');
}

final class DartCalculator implements Calculator {
  @override
  int calculate(int value) {
    if (value < 0) throw Failure(code: 9, message: 'Dart rejected value');
    return value * 3;
  }
}

final class DartStartSignal implements StartSignal {
  DartStartSignal(this.callback);
  final void Function() callback;
  @override
  void started() => callback();
}

final class DartAsyncCalculator implements AsyncCalculator {
  @override
  Future<int> calculate(int value) async {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    return value * 4;
  }
}

final patterns = <Pattern>[
  (
    group: 'Sync & values',
    name: 'Sync integers',
    run: () {
      final value = add(20, 22);
      check(value == 42, 'sum');
      return '20 + 22 = $value';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Strings & defaults',
    run: () {
      check(greeting() == 'Hello, world!', 'default argument');
      final value = greeting(name: 'Dart 🦀');
      check(value == 'Hello, Dart 🦀!', 'UTF-8');
      return 'Hello, world! / $value';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Optional some / none',
    run: () {
      check(
        optionalValue(true) == 42 && optionalValue(false) == null,
        'options',
      );
      return 'Some(42) / None';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Record & typed vector',
    run: () {
      final input = Message(
        text: 'Dart → Rust → Dart',
        values: Int32List.fromList([1, -2, 3]),
      );
      final output = echoMessage(input);
      check(
        input == output && input.hashCode == output.hashCode,
        'record round trip',
      );
      return '${output.text}: ${output.values}';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Mutable record',
    run: () {
      final value = Point(x: 1, y: 2);
      updatePoint(value);
      check(value.x == 11 && value.y == 22, 'writeback');
      return 'Point(1, 2) → Point(${value.x}, ${value.y})';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Mutation before exception',
    run: () async {
      final value = Point(x: 1, y: 2);
      final error = await catches<Failure>(() {
        updateThenFail(value);
      });
      check(value.x == 2 && error.code == 8, 'writeback after exception');
      return 'Caught Failure(8) / Point.x updated to ${value.x}';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Data enum variants',
    run: () {
      final values = [
        const Choice.empty(),
        const Choice.number(value0: 42),
        const Choice.text(value0: 'hello'),
      ];
      for (final value in values) {
        check(echoChoice(value) == value, 'enum $value');
      }
      return 'Empty / Number(42) / Text(hello)';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Bytes & empty buffers',
    run: () {
      check(echoBytes(Uint8List(0)).isEmpty, 'empty buffer');
      final value = echoBytes(Uint8List.fromList([0, 127, 128, 255]));
      check(value.join(',') == '0,127,128,255', 'bytes');
      return '$value / empty []';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Bool & int64 vectors',
    run: () {
      final bools = echoBools($$BoltBoolList.fromList([true, false, true]));
      final longs = echoLongs([9007199254740991, -9007199254740991, 42]);
      check(bools[0] && !bools[1] && bools[2], 'bool vector');
      check(
        longs.join(',') == '9007199254740991,-9007199254740991,42',
        'int64 boundary',
      );
      return '[true, false, true] / $longs';
    },
  ),
  (
    group: 'Sync & values',
    name: 'Class factories & dispose',
    run: () {
      final first = Counter(41);
      final second = Counter.fromValue(9);
      try {
        check(
          first.increment() == 42 && second.increment() == 10,
          'class state',
        );
        return 'Counter(41) → 42 / Counter.fromValue(9) → 10';
      } finally {
        first.dispose$();
        second.dispose$();
      }
    },
  ),
  (
    group: 'Errors',
    name: 'Result success',
    run: () {
      check(divide(84, 2) == 42 && validate(42) == 42, 'successful results');
      return 'Ok(42) / Ok(42)';
    },
  ),
  (
    group: 'Errors',
    name: 'String exception',
    run: () async {
      final error = await catches<$$BoltException>(() {
        divide(1, 0);
      });
      check(error.message == 'invalid division', 'error message');
      return 'Caught: ${error.message}';
    },
  ),
  (
    group: 'Errors',
    name: 'Typed exception',
    run: () async {
      final error = await catches<Failure>(() {
        validate(-1);
      });
      check(
        error.code == 7 && error.message == 'negative value',
        'typed payload',
      );
      return 'Caught Failure(${error.code}): ${error.message}';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Async result',
    run: () async {
      final value = await asyncAdd(20, 22);
      check(value == 42, 'async sum');
      return 'Future → $value';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Concurrent futures',
    run: () async {
      final values = await Future.wait(
        List.generate(20, (i) => asyncAdd(i, 1)),
      );
      check(
        values.join(',') == List.generate(20, (i) => i + 1).join(','),
        'concurrent handles',
      );
      return '20 futures → $values';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Async typed exception',
    run: () async {
      check(await asyncValidate(42) == 42, 'async success');
      final error = await catches<Failure>(() async {
        await asyncValidate(-1);
      });
      check(error.code == 7, 'async error payload');
      return 'Ok(42) / caught Failure(${error.code})';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Async optional',
    run: () async {
      check(
        await asyncOptional(true) == 42 && await asyncOptional(false) == null,
        'async options',
      );
      return 'Future → Some(42) / None';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Cancel before call',
    run: () async {
      final token = $$BoltCancellationToken()..cancel();
      await catches<$$BoltCancelledException>(() async {
        await asyncAdd(1, 2, cancellationToken: token);
      });
      check(token.isCancelled, 'token state');
      return 'Caught cancellation before Rust starts';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Cancel pending future',
    run: () async {
      final token = $$BoltCancellationToken();
      final started = Completer<void>();
      final future = waitForever(
        DartStartSignal(started.complete),
        cancellationToken: token,
      );
      final caught = catches<$$BoltCancelledException>(() async {
        await future;
      });
      await started.future;
      token.cancel();
      token.cancel();
      await caught;
      return 'Rust started → cancelled / repeated cancel is safe';
    },
  ),
  (
    group: 'Async & cancellation',
    name: 'Cancel inside first poll',
    run: () async {
      final token = $$BoltCancellationToken();
      await catches<$$BoltCancelledException>(() async {
        await waitForever(
          DartStartSignal(token.cancel),
          cancellationToken: token,
        );
      });
      return 'Rust → Dart callback → cancel during first poll';
    },
  ),
  (
    group: 'Callbacks',
    name: 'Closure callback',
    run: () {
      final value = transform(14, (value) => value * 3);
      check(value == 42, 'closure');
      return 'Rust → Dart closure → Rust → $value';
    },
  ),
  (
    group: 'Callbacks',
    name: 'Trait callback',
    run: () {
      final value = callCalculator(DartCalculator(), 14);
      check(value == 42, 'callback');
      return 'Rust → Dart Calculator → $value';
    },
  ),
  (
    group: 'Callbacks',
    name: 'Callback typed exception',
    run: () async {
      final error = await catches<Failure>(() {
        callCalculator(DartCalculator(), -1);
      });
      check(
        error.code == 9 && error.message == 'Dart rejected value',
        'callback error round trip',
      );
      return 'Dart throw → Rust Err → Dart Failure(${error.code})';
    },
  ),
  (
    group: 'Callbacks',
    name: 'Async trait callback',
    run: () async {
      final value = await callAsyncCalculator(DartAsyncCalculator(), 10);
      check(value == 40, 'async callback');
      return 'Rust awaits Dart Future → $value';
    },
  ),
  (
    group: 'Streams',
    name: 'Async stream',
    run: () async {
      final bus = EventBus();
      final values = <int>[];
      final done = Completer<void>();
      final subscription = bus.subscribe().listen((value) {
        values.add(value);
        if (values.length == 3) done.complete();
      });
      try {
        for (final value in [1, 2, 3]) {
          bus.emit(value);
        }
        await done.future;
        check(values.join(',') == '1,2,3', 'stream order');
        return 'Stream<int> → $values';
      } finally {
        await subscription.cancel();
        bus.dispose$();
      }
    },
  ),
  (
    group: 'Streams',
    name: 'Pause & resume',
    run: () async {
      final bus = EventBus();
      final values = <int>[];
      final done = Completer<void>();
      final subscription = bus.subscribe().listen((value) {
        values.add(value);
        if (values.length == 3) done.complete();
      });
      try {
        subscription.pause();
        for (final value in [1, 2, 3]) {
          bus.emit(value);
        }
        await Future<void>.delayed(const Duration(milliseconds: 30));
        check(values.isEmpty, 'paused delivery');
        subscription.resume();
        await done.future;
        check(values.join(',') == '1,2,3', 'resumed order');
        return 'Paused → [] / resumed → $values';
      } finally {
        await subscription.cancel();
        bus.dispose$();
      }
    },
  ),
  (
    group: 'Streams',
    name: 'Batch stream',
    run: () {
      final bus = EventBus();
      final handle = bus.batches();
      try {
        for (final value in [1, 2, 3]) {
          bus.emit(value);
        }
        final first = handle.popBatch(2);
        final second = handle.popBatch(2);
        check(
          first.join(',') == '1,2' &&
              second.join(',') == '3' &&
              handle.popBatch(2).isEmpty,
          'batch limits',
        );
        return 'popBatch(2) → $first / $second / []';
      } finally {
        handle.cancel();
        bus.dispose$();
      }
    },
  ),
  (
    group: 'Streams',
    name: 'Callback stream',
    run: () async {
      final bus = EventBus();
      final values = <int>[];
      final done = Completer<void>();
      final subscription = bus.notifications((value) {
        values.add(value);
        if (values.length == 2) done.complete();
      });
      try {
        bus.emit(7);
        bus.emit(8);
        await done.future;
        check(values.join(',') == '7,8', 'notifications');
        return 'Notifications → $values';
      } finally {
        await subscription.cancel();
        bus.dispose$();
      }
    },
  ),
  (
    group: 'Streams',
    name: 'Record stream',
    run: () async {
      final bus = EventBus();
      final received = Completer<Message>();
      final subscription = bus.subscribeMessages().listen(received.complete);
      try {
        final message = Message(
          text: 'stream 🦀',
          values: Int32List.fromList([4, 5]),
        );
        bus.emitMessage(message);
        final value = await received.future;
        check(value == message, 'encoded stream item');
        return '${value.text}: ${value.values}';
      } finally {
        await subscription.cancel();
        bus.dispose$();
      }
    },
  ),
  (
    group: 'Streams',
    name: 'Cancel idle stream',
    run: () async {
      final bus = EventBus();
      var delivered = 0;
      final subscription = bus.subscribe().listen((_) {
        delivered++;
      });
      try {
        await subscription.cancel();
        bus.emit(42);
        await Future<void>.delayed(const Duration(milliseconds: 20));
        check(delivered == 0, 'delivery after cancel');
        return 'Cancelled pending poll / no events after cancel';
      } finally {
        bus.dispose$();
      }
    },
  ),
];

final buttons = <web.HTMLButtonElement>[];
var passed = 0;
var failed = 0;

web.HTMLElement element(String id) =>
    web.document.getElementById(id)! as web.HTMLElement;
web.HTMLElement tag(String name) =>
    web.document.createElement(name) as web.HTMLElement;

void setBusy(bool busy) {
  for (final button in buttons) {
    button.disabled = busy;
  }
}

Future<void> runPattern(Pattern pattern) async {
  element('status').textContent = 'Running ${pattern.name}…';
  final timer = Stopwatch()..start();
  var success = true;
  String detail;
  try {
    detail = await Future<String>.sync(
      pattern.run,
    ).timeout(const Duration(seconds: 5));
    passed++;
  } catch (error, stack) {
    success = false;
    detail = '$error\n$stack';
    failed++;
  }
  element('results').querySelector('.empty')?.remove();
  final row = web.HTMLDivElement()
    ..className = 'result ${success ? "pass" : "fail"}';
  row.append(
    tag('strong')
      ..textContent =
          '${success ? "PASS" : "FAIL"} · ${pattern.name} · ${timer.elapsedMilliseconds} ms',
  );
  row.append(tag('pre')..textContent = detail);
  element('results').prepend(row);
  element('counts').textContent = '$passed passed · $failed failed';
  element('status').textContent = 'Ready';
}

Future<void> runPatterns(Iterable<Pattern> selection) async {
  setBusy(true);
  try {
    for (final pattern in selection) {
      await runPattern(pattern);
    }
  } finally {
    setBusy(false);
  }
}

Future<void> main() async {
  final runAll = element('run-all') as web.HTMLButtonElement;
  final clear = element('clear') as web.HTMLButtonElement;
  buttons.addAll([runAll, clear]);
  String? group;
  late web.HTMLDivElement container;
  for (final pattern in patterns) {
    if (group != pattern.group) {
      group = pattern.group;
      final section = tag('section')..className = 'group';
      section.append(tag('h2')..textContent = group);
      container = web.HTMLDivElement()..className = 'buttons';
      section.append(container);
      element('patterns').append(section);
    }
    final button = web.HTMLButtonElement()
      ..textContent = pattern.name
      ..disabled = true;
    button.addEventListener(
      'click',
      (() {
        unawaited(runPatterns([pattern]));
      }).toJS,
    );
    buttons.add(button);
    container.append(button);
  }
  runAll.addEventListener(
    'click',
    (() {
      unawaited(runPatterns(patterns));
    }).toJS,
  );
  clear.addEventListener(
    'click',
    (() {
      element('results').textContent = '';
      passed = failed = 0;
      element('counts').textContent = '0 passed · 0 failed';
    }).toJS,
  );
  try {
    await boltffiInit().timeout(const Duration(seconds: 15));
    element('status').textContent = 'Ready';
    setBusy(false);
  } catch (error) {
    element('status').textContent = 'WASM initialization failed: $error';
  }
}
