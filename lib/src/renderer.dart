import 'dart:math' as math;

import 'context.dart';
import 'enirvonment.dart';
import 'filters.dart' as filters;
import 'nodes.dart';
import 'tests.dart' as tests;
import 'utils.dart';
import 'visitor.dart';

class Renderer extends Visitor<dynamic> implements Context {
  Renderer(this.environment, this.sink, List<Node> nodes, [Map<String, dynamic>? context]) : contexts = <Map<String, dynamic>>[environment.globals] {
    if (context != null) {
      contexts.add(context);
    }

    visitAll(nodes);
  }

  @override
  final Environment environment;

  final StringSink sink;

  final List<Map<String, dynamic>> contexts;

  @override
  dynamic operator [](String key) {
    return get(key);
  }

  @override
  void operator []=(String key, Object value) {
    set(key, value);
  }

  @override
  void apply(Map<String, dynamic> data, ContextCallback closure) {
    push(data);
    closure(this);
    pop();
  }

  @override
  dynamic get(String key) {
    for (final context in contexts.reversed) {
      if (context.containsKey(key)) {
        return context[key];
      }
    }

    return null;
  }

  @override
  bool has(String name) {
    return contexts.any((context) => context.containsKey(name));
  }

  @override
  void pop() {
    if (contexts.length > 2) {
      contexts.removeLast();
    }
  }

  @override
  void push(Map<String, dynamic> context) {
    contexts.add(context);
  }

  @override
  bool remove(String name) {
    for (final context in contexts.reversed) {
      if (context.containsKey(name)) {
        context.remove(name);
        return true;
      }
    }

    return false;
  }

  @override
  void set(String key, Object value) {
    contexts.last[key] = value;
  }

  void visitAll(List<Node> nodes) {
    for (final node in nodes) {
      if (node is Expression) {
        sink.write(environment.finalize(node.accept(this)));
      } else {
        node.accept(this);
      }
    }
  }

  @override
  dynamic visitAttribute(Attribute node) {
    return environment.getAttribute(node.expression.accept(this), node.attribute);
  }

  @override
  dynamic visitBinary(Binary node) {
    final left = node.left.accept(this);
    final right = node.right.accept(this);

    try {
      switch (node.operator) {
        case '**':
          return math.pow(unsafeCast<num>(left), unsafeCast<num>(right));
        case '%':
          return unsafeCast<num>(left) % unsafeCast<num>(right);
        case '//':
          return unsafeCast<num>(left) ~/ unsafeCast<num>(right);
        case '/':
          return unsafeCast<num>(left) / unsafeCast<num>(right);
        case '*':
          return left * right;
        case '-':
          return left - right;
        case '+':
          return left + right;
        case 'or':
          return boolean(left) ? left : right;
        case 'and':
          return boolean(left) ? right : right;
      }
    } on TypeError {
      if (left is int && right is String) {
        return right * left;
      }

      rethrow;
    }
  }

  @override
  dynamic visitCall(Call node) {
    final callable = unsafeCast<Function>(node.expression.accept(this));
    final arguments = <dynamic>[];

    for (final argument in node.arguments) {
      arguments.add(argument.accept(this));
    }

    final keywordArguments = <Symbol, dynamic>{};

    for (final keywordArgument in node.keywordArguments) {
      keywordArguments[Symbol(keywordArgument.key)] = keywordArgument.value.accept(this);
    }

    if (node.dArguments != null) {
      arguments.addAll(unsafeCast<Iterable<dynamic>>(node.dArguments!.accept(this)));
    }

    if (node.dKeywordArguments != null) {
      keywordArguments.addAll(unsafeCast<Map<String, dynamic>>(node.dKeywordArguments!.accept(this))
          .map<Symbol, dynamic>((key, value) => MapEntry<Symbol, dynamic>(Symbol(key), value)));
    }

    return Function.apply(callable, arguments, keywordArguments);
  }

  @override
  dynamic visitCompare(Compare node) {
    var left = node.expression.accept(this);
    var result = true;

    for (final operand in node.operands) {
      if (!result) {
        return false;
      }

      final right = operand.expression.accept(this);

      switch (operand.operator) {
        case 'eq':
          result = result && tests.equal(left, right);
          break;
        case 'ne':
          result = result && tests.notEqual(left, right);
          break;
        case 'lt':
          result = result && tests.lessThan(left, right);
          break;
        case 'le':
          result = result && tests.lessThanOrEqual(left, right);
          break;
        case 'gt':
          result = result && tests.greaterThan(left, right);
          break;
        case 'ge':
          result = result && tests.greaterThanOrEqual(left, right);
          break;
        case 'in':
          result = result && tests.contains(left, right);
          break;
        case 'notin':
          result = result && !tests.contains(left, right);
          break;
      }

      left = right;
    }

    return result;
  }

  @override
  dynamic visitConcat(Concat node) {
    final buffer = StringBuffer();

    for (final expression in node.expressions) {
      buffer.write(expression.accept(this));
    }

    return buffer.toString();
  }

  @override
  dynamic visitCondition(Condition node) {
    if (boolean(node.test.accept(this))) {
      return node.expression1.accept(this);
    }

    final expression = node.expression2;

    if (expression != null) {
      return expression.accept(this);
    }

    return null;
  }

  @override
  dynamic visitConstant(Constant<dynamic> node) {
    return node.value;
  }

  @override
  void visitData(Data node) {
    sink.write(node.data);
  }

  @override
  dynamic visitDictLiteral(DictLiteral node) {
    final dict = <dynamic, dynamic>{};

    for (final pair in node.pairs) {
      dict[pair.key.accept(this)] = pair.value.accept(this);
    }

    return dict;
  }

  @override
  dynamic visitFilter(Filter node) {
    final arguments = <dynamic>[node.expression.accept(this)];

    for (final argument in node.arguments) {
      arguments.add(argument.accept(this));
    }

    final keywordArguments = <Symbol, dynamic>{};

    for (final keywordArgument in node.keywordArguments) {
      keywordArguments[Symbol(keywordArgument.key)] = keywordArgument.value.accept(this);
    }

    if (node.dArguments != null) {
      arguments.addAll(unsafeCast<Iterable<dynamic>>(node.dArguments!.accept(this)));
    }

    if (node.dKeywordArguments != null) {
      keywordArguments.addAll(unsafeCast<Map<String, dynamic>>(node.dKeywordArguments!.accept(this))
          .map<Symbol, dynamic>((key, value) => MapEntry<Symbol, dynamic>(Symbol(key), value)));
    }

    return environment.callFilter(node.name, arguments, keywordArguments);
  }

  @override
  void visitIf(If node) {
    if (boolean(node.test.accept(this))) {
      visitAll(node.body);
      return;
    }

    if (node.elseIf.isNotEmpty) {
      for (final ifNode in node.elseIf) {
        if (boolean(ifNode.test.accept(this))) {
          visitAll(ifNode.body);
          return;
        }
      }
    }

    if (node.$else.isNotEmpty) {
      visitAll(node.$else);
    }
  }

  @override
  dynamic visitItem(Item node) {
    return environment.getItem(node.expression.accept(this), node.key.accept(this));
  }

  @override
  MapEntry<Symbol, dynamic> visitKeyword(Keyword node) {
    return MapEntry<Symbol, dynamic>(Symbol(node.key), node.value.accept(this));
  }

  @override
  dynamic visitListLiteral(ListLiteral node) {
    final list = <dynamic>[];

    for (final value in node.values) {
      list.add(value.accept(this));
    }

    return list;
  }

  @override
  dynamic visitName(Name node) {
    return get(node.name);
  }

  @override
  List<dynamic> visitOperand(Operand node) {
    return [node.operator, node.expression.accept(this)];
  }

  @override
  void visitOutput(Output node) {
    visitAll(node.nodes);
  }

  @override
  dynamic visitPair(Pair node) {
    return MapEntry<dynamic, dynamic>(node.key.accept(this), node.value.accept(this));
  }

  @override
  dynamic visitSlice(Slice node) {
    final value = node.expression.accept(this);
    final start = unsafeCast<int>(node.start.accept(this));

    var expression = node.stop;
    int? stop;

    if (expression != null) {
      stop = math.min(filters.count(value), unsafeCast<int>(expression.accept(this)));
    } else {
      stop = value.length;
    }

    expression = node.step;
    int? step;

    if (expression != null) {
      step = unsafeCast<int>(expression.accept(this));
    }

    if (value is String) {
      return sliceString(value, start, stop, step);
    }

    return slice(value, start, stop, step);
  }

  @override
  dynamic visitTest(Test node) {
    final arguments = <dynamic>[node.expression.accept(this)];

    for (final argument in node.arguments) {
      arguments.add(argument.accept(this));
    }

    final keywordArguments = <Symbol, dynamic>{};

    for (final keywordArgument in node.keywordArguments) {
      keywordArguments[Symbol(keywordArgument.key)] = keywordArgument.value.accept(this);
    }

    if (node.dArguments != null) {
      arguments.addAll(unsafeCast<Iterable<dynamic>>(node.dArguments!.accept(this)));
    }

    if (node.dKeywordArguments != null) {
      keywordArguments.addAll(unsafeCast<Map<String, dynamic>>(node.dKeywordArguments!.accept(this))
          .map<Symbol, dynamic>((key, value) => MapEntry<Symbol, dynamic>(Symbol(key), value)));
    }

    return environment.callTest(node.name, arguments, keywordArguments);
  }

  @override
  dynamic visitTupleLiteral(TupleLiteral node) {
    final tuple = <dynamic>[];

    for (final value in node.values) {
      tuple.add(value.accept(this));
    }

    return tuple;
  }

  @override
  dynamic visitUnary(Unary node) {
    final value = node.expression.accept(this);

    switch (node.operator) {
      case '+':
        return 0 + unsafeCast<num>(value);
      case '-':
        return 0 - unsafeCast<num>(value);
      case 'not':
        return !boolean(value);
    }
  }
}
