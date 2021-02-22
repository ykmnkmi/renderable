import 'package:meta/meta.dart';

import 'enirvonment.dart';
import 'exceptions.dart';
import 'markup.dart';
import 'nodes.dart';
import 'resolver.dart';
import 'runtime.dart';
import 'utils.dart';

abstract class RenderContext extends Context {
  RenderContext.from(Context context) : super.from(context);

  RenderContext(Environment environment, {Map<String, Object?>? data}) : super(environment, data);

  RenderContext derived();

  void write(Object? object);

  void writeFinalized(Object? object);
}

class StringBufferRenderContext extends RenderContext {
  StringBufferRenderContext(Environment environment, {Map<String, Object?>? data, StringBuffer? buffer})
      : buffer = buffer ?? StringBuffer(),
        super(environment, data: data);

  StringBufferRenderContext.from(Context context, {StringBuffer? buffer})
      : buffer = buffer ?? StringBuffer(),
        super.from(context);

  final StringBuffer buffer;

  @override
  RenderContext derived() {
    return StringBufferRenderContext(environment, buffer: buffer);
  }

  @override
  void write(Object? object) {
    buffer.write(object);
  }

  @override
  void writeFinalized(Object? object) {
    buffer.write(environment.finalize(this, object));
  }
}

const Renderer renderer = Renderer();

class Renderer extends ExpressionResolver<RenderContext> {
  @literal
  const Renderer();

  @override
  void visitAll(List<Node> nodes, [RenderContext? context]) {
    for (final node in nodes) {
      node.accept(this, context);
    }
  }

  @override
  void visitAssign(Assign assign, [RenderContext? context]) {
    final target = assign.target.accept(this, context);
    final values = assign.expression.accept(this, context);
    assignTargetsToContext(context!, target, values);
  }

  @override
  void visitAssignBlock(AssignBlock node, [RenderContext? context]) {
    context!;

    final target = node.target.accept(this, context);
    final derived = StringBufferRenderContext.from(context);
    visitAll(node.body, derived);
    Object? value = derived.buffer.toString();

    if (node.filters == null || node.filters!.isEmpty) {
      assignTargetsToContext(context, target, context.environment.autoEscape ? Markup(value.toString()) : value);
      return;
    }

    final filters = node.filters!;

    for (final filter in filters) {
      value = callFilter(filter, value, context);
    }

    assignTargetsToContext(context, target, context.environment.autoEscape ? Markup(value.toString()) : value);
  }

  @override
  void visitFor(For node, [RenderContext? context]) {
    context!;

    final target = node.target.accept(this, context);

    if (node.hasLoop && (target == 'loop' || (target is List<String> && target.contains('loop')) || (target is NSRef && target.name == 'loop'))) {
      throw StateError('can\'t assign to special loop variable in for-loop target');
    }

    final iterable = node.iterable.accept(this, context);
    final orElse = node.orElse;

    if (iterable == null) {
      throw TypeError();
    }

    void loop(Object? iterable) {
      var values = list(iterable);

      if (values.isEmpty) {
        if (orElse != null) {
          visitAll(orElse, context);
        }

        return;
      }

      Map<String, Object?> Function(List<Object?>, int) unpack;

      if (node.hasLoop) {
        unpack = (List<Object?> values, int index) {
          final data = getDataForTargets(target, values[index]);
          Object? previous, next;

          if (index > 0) {
            previous = values[index - 1];
          } else {
            previous = context.environment.undefined();
          }

          if (index < values.length - 1) {
            next = values[index + 1];
          } else {
            next = context.environment.undefined();
          }

          bool changed(Object? item) {
            if (index == 0) {
              return true;
            }

            if (item == previous) {
              return false;
            }

            return true;
          }

          data['loop'] = LoopContext(index, values.length, previous, next, changed, loop);
          return data;
        };
      } else {
        unpack = (List<Object?> values, int index) => getDataForTargets(target, values[index]);
      }

      if (node.test != null) {
        final test = node.test!;
        final filtered = <Object?>[];

        for (var i = 0; i < values.length; i += 1) {
          final data = unpack(values, i);
          context.push(data);

          if (test.accept(this, context) as bool) {
            filtered.add(values[i]);
          }

          context.pop();
        }

        values = filtered;
      }

      for (var i = 0; i < values.length; i += 1) {
        final data = unpack(values, i);
        context.push(data);
        visitAll(node.body, context);
        context.pop();
      }
    }

    loop(iterable);
  }

  @override
  void visitIf(If node, [RenderContext? context]) {
    context!;

    if (boolean(node.test.accept(this, context))) {
      visitAll(node.body, context);
      return;
    }

    var next = node.nextIf;

    while (next != null) {
      if (boolean(next.test.accept(this, context))) {
        visitAll(next.body, context);
        return;
      }

      next = next.nextIf;
    }

    if (node.orElse != null) {
      visitAll(node.orElse!, context);
    }
  }

  @override
  void visitInclude(Include node, [RenderContext? context]) {
    context!;

    try {
      final name = node.template.accept(this);
      Template template;

      if (name is List) {
        template = context.environment.selectTemplate(name);
      } else {
        template = context.environment.getTemplate(name);
      }

      if (node.withContext) {
        template.accept(this, context);
      } else {
        template.accept(this, context.derived());
      }
    } on TemplateNotFound {
      if (!node.ignoreMissing) {
        rethrow;
      }
    }
  }

  @override
  void visitOutput(Output node, [RenderContext? context]) {
    context!;

    for (final item in node.nodes) {
      if (item is Data) {
        context.write(item.accept(this, context));
      } else {
        var value = item.accept(this, context);

        if (context.environment.autoEscape && value is! Markup) {
          value = Markup.escape(value.toString());
        }

        context.writeFinalized(value);
      }
    }
  }

  @override
  void visitTemplate(Template node, [RenderContext? context]) {
    visitAll(node.nodes, context);
  }

  @override
  void visitWith(With node, [RenderContext? context]) {
    context!;

    final targets = node.targets.map((target) => target.accept(this, context)).toList();
    final values = node.values.map((value) => value.accept(this, context)).toList();

    context.push(getDataForTargets(targets, values));
    visitAll(node.body, context);
    context.pop();
  }

  @protected
  static void assignTargetsToContext(RenderContext context, Object? target, Object? current) {
    if (target is String) {
      context[target] = current;
      return;
    }

    if (target is List<String>) {
      List<Object?> list;

      if (current is List) {
        list = current;
      } else if (current is Iterable<Object?>) {
        list = current.toList();
      } else if (current is String) {
        list = current.split('');
      } else {
        throw TypeError();
      }

      if (list.length < target.length) {
        throw StateError('not enough values to unpack (expected ${target.length}, got ${list.length})');
      }

      if (list.length > target.length) {
        throw StateError('too many values to unpack (expected ${target.length})');
      }

      for (var i = 0; i < target.length; i++) {
        context[target[i]] = list[i];
      }

      return;
    }

    if (target is NSRef) {
      final namespace = context[target.name];

      if (namespace is! Namespace) {
        throw TemplateRuntimeError('non-namespace object');
      }

      namespace[target.attribute] = current;
      return;
    }

    throw ArgumentError.value(target, 'target');
  }

  @protected
  static Map<String, Object?> getDataForTargets(Object? target, Object? current) {
    if (target is String) {
      return <String, Object?>{target: current};
    }

    if (target is List) {
      final names = target.cast<String>();
      List<Object?> list;

      if (current is List) {
        list = current;
      } else if (current is Iterable) {
        list = current.toList();
      } else if (current is String) {
        list = current.split('');
      } else {
        throw TypeError();
      }

      if (list.length < names.length) {
        throw StateError('not enough values to unpack (expected ${names.length}, got ${list.length})');
      }

      if (list.length > names.length) {
        throw StateError('too many values to unpack (expected ${names.length})');
      }

      final data = <String, Object?>{};

      for (var i = 0; i < names.length; i++) {
        data[names[i]] = list[i];
      }

      return data;
    }

    throw ArgumentError.value(target, 'target');
  }
}
