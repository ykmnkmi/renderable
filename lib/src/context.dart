import 'enirvonment.dart';

typedef ContextCallback<C extends Context> = void Function(C context);

class Context {
  Context.from(this.environment, this.contexts);

  Context(this.environment, [Map<String, dynamic>? data]) : contexts = <Map<String, dynamic>>[environment.globals] {
    if (data != null) {
      contexts.add(data);
    }

    minimal = contexts.length;
  }

  final Environment environment;

  final List<Map<String, dynamic>> contexts;

  late int minimal;

  dynamic operator [](String key) {
    return get(key);
  }

  void operator []=(String key, dynamic value) {
    set(key, value);
  }

  void apply<C extends Context>(Map<String, dynamic> data, ContextCallback<C> closure) {
    push(data);
    closure(this as C);
    pop();
  }

  dynamic get(String key) {
    for (final context in contexts.reversed) {
      if (context.containsKey(key)) {
        return context[key];
      }
    }

    return null;
  }

  bool has(String name) {
    return contexts.any((context) => context.containsKey(name));
  }

  void pop() {
    if (contexts.length > minimal) {
      contexts.removeLast();
    }
  }

  void push(Map<String, dynamic> context) {
    contexts.add(context);
  }

  bool remove(String name) {
    for (final context in contexts.reversed) {
      if (context.containsKey(name)) {
        context.remove(name);
        return true;
      }
    }

    return false;
  }

  void set(String key, dynamic value) {
    contexts.last[key] = value;
  }
}
