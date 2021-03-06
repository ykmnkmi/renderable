import 'package:meta/meta.dart';

import 'enirvonment.dart';
import 'nodes.dart';
import 'resolver.dart';
import 'runtime.dart';
import 'utils.dart';
import 'visitor.dart';

class Impossible implements Exception {}

class Optimizer extends Visitor<Context, Node> {
  @literal
  const Optimizer();

  @protected
  Expression constant(Expression expression, [Context? context]) {
    try {
      final value = resolve(expression, context);

      if (value == null) {
        throw Impossible();
      }

      if (value is bool) {
        return Constant<bool>(value);
      }

      if (value is int) {
        return Constant<int>(value);
      }

      if (value is double) {
        return Constant<double>(value);
      }

      if (value is String) {
        return Constant<String>(value);
      }

      return Constant(value);
    } catch (_) {
      return expression;
    }
  }

  @protected
  Expression optimize(Expression expression, [Context? context]) {
    expression = expression.accept(this, context) as Expression;
    return constant(expression, context);
  }

  @protected
  Expression optimizeSafe(Expression expression, [Context? context]) {
    try {
      expression = expression.accept(this, context) as Expression;
      return constant(expression, context);
    } on Impossible {
      return expression;
    }
  }

  @override
  void visitAll(List<Node> nodes, [Context? context]) {
    for (var i = 0; i < nodes.length; i += 1) {
      try {
        if (nodes[i] is Data) {
          continue;
        }

        nodes[i] = nodes[i].accept(this, context);
      } on Impossible {
        // pass
      }
    }
  }

  void visitAllNotSafe(List<Node> nodes, [Context? context]) {
    for (var i = 0; i < nodes.length; i += 1) {
      nodes[i] = nodes[i].accept(this, context);
    }
  }

  @override
  Assign visitAssign(Assign node, [Context? context]) {
    return node;
  }

  @override
  AssignBlock visitAssignBlock(AssignBlock node, [Context? context]) {
    return node;
  }

  @override
  Expression visitAttribute(Attribute node, [Context? context]) {
    node.expression = optimize(node.expression, context);
    return constant(node, context);
  }

  @override
  Expression visitBinary(Binary node, [Context? context]) {
    node.left = optimize(node.left, context);
    node.right = optimize(node.right, context);
    return constant(node, context);
  }

  @override
  Expression visitCall(Call node, [Context? context]) {
    if (node.expression != null) {
      node.expression = optimize(node.expression!, context);
    }

    if (node.arguments != null) {
      visitAll(node.arguments!, context);
    }

    if (node.keywordArguments != null) {
      visitAll(node.keywordArguments!, context);
    }

    if (node.dArguments != null) {
      node.dArguments = optimize(node.dArguments!, context);
    }

    if (node.dKeywordArguments != null) {
      node.dKeywordArguments = optimize(node.dKeywordArguments!, context);
    }

    return constant(node, context);
  }

  @override
  Expression visitCompare(Compare node, [Context? context]) {
    node.expression = optimize(node.expression, context);
    visitAllNotSafe(node.operands, context);
    return constant(node, context);
  }

  @override
  Expression visitConcat(Concat node, [Context? context]) {
    visitAllNotSafe(node.expressions);
    return constant(node, context);
  }

  @override
  Expression visitCondition(Condition node, [Context? context]) {
    node.expression1 = optimize(node.expression1, context);

    if (node.expression2 != null) {
      node.expression2 = optimize(node.expression2!, context);
    }

    node.test = optimize(node.test, context);

    if (boolean(resolve(node.test, context))) {
      return node.expression1;
    }

    if (node.expression2 == null) {
      throw Impossible();
    }

    return node.expression2!;
  }

  @override
  Constant<Object?> visitConstant(Constant<Object?> node, [Context? context]) {
    return node;
  }

  @override
  Node visitContextModifier(ScopedContextModifier node, [Context? context]) {
    visitAll(node.body, context);
    return node;
  }

  @override
  Data visitData(Data node, [Context? context]) {
    return node;
  }

  @override
  Expression visitDictLiteral(DictLiteral node, [Context? context]) {
    visitAllNotSafe(node.pairs, context);
    return constant(node, context);
  }

  @override
  Expression visitFilter(Filter node, [Context? context]) {
    if (node.name == 'random' || !context!.environment.filters.containsKey(node.name)) {
      throw Impossible();
    }

    if (node.expression != null) {
      node.expression = optimize(node.expression!, context);
    }

    if (node.arguments != null) {
      visitAll(node.arguments!, context);
    }

    if (node.keywordArguments != null) {
      visitAll(node.keywordArguments!, context);
    }

    if (node.dArguments != null) {
      node.dArguments = optimize(node.dArguments!, context);
    }

    if (node.dKeywordArguments != null) {
      node.dKeywordArguments = optimize(node.dKeywordArguments!, context);
    }

    return constant(node, context);
  }

  @override
  Node visitFor(For node, [Context? context]) {
    node.iterable = optimizeSafe(node.iterable, context);
    visitAll(node.body, context);
    return node;
  }

  @override
  Node visitIf(If node, [Context? context]) {
    node.test = optimizeSafe(node.test, context);
    visitAll(node.body, context);
    var next = node.nextIf;

    while (next != null) {
      next.test = optimizeSafe(next.test, context);
      visitAll(next.body, context);
      next = next.nextIf;
    }

    if (node.orElse != null) {
      visitAll(node.orElse!, context);
    }

    return node;
  }

  @override
  Include visitInclude(Include node, [Context? context]) {
    return node;
  }

  @override
  Expression visitItem(Item node, [Context? context]) {
    node.key = optimize(node.key, context);
    node.expression = optimize(node.expression, context);
    return constant(node, context);
  }

  @override
  Keyword visitKeyword(Keyword node, [Context? context]) {
    node.value = optimize(node.value, context);
    return node;
  }

  @override
  Expression visitListLiteral(ListLiteral node, [Context? context]) {
    visitAllNotSafe(node.expressions, context);
    return constant(node, context);
  }

  @override
  Name visitName(Name node, [Context? context]) {
    throw Impossible();
  }

  @override
  NamespaceReference visitNamespaceReference(NamespaceReference node, [Context? context]) {
    return node;
  }

  @override
  Operand visitOperand(Operand node, [Context? context]) {
    node.expression = optimize(node.expression, context);
    return node;
  }

  @override
  Output visitOutput(Output node, [Context? context]) {
    visitAll(node.nodes, context);
    return node;
  }

  @override
  Pair visitPair(Pair node, [Context? context]) {
    node.key = optimize(node.key, context);
    node.value = optimize(node.value, context);
    return node;
  }

  @override
  Scope visitScope(Scope node, [Context? context]) {
    node.modifier = node.modifier.accept(this) as ContextModifier;
    return node;
  }

  @override
  ScopedContextModifier visitScopedContextModifier(ScopedContextModifier node, [Context? context]) {
    node.options.updateAll((option, expression) => optimizeSafe(expression, context));
    visitAll(node.body, context);
    return node;
  }

  @override
  Slice visitSlice(Slice node, [Context? context]) {
    if (node.start != null) {
      node.start = optimize(node.start!, context);
    }

    if (node.stop != null) {
      node.stop = optimize(node.stop!, context);
    }

    if (node.step != null) {
      node.step = optimize(node.step!, context);
    }

    return node;
  }

  @override
  Template visitTemplate(Template node, [Context? context]) {
    visitAll(node.nodes, context);
    return node;
  }

  @override
  Expression visitTest(Test node, [Context? context]) {
    if (!context!.environment.tests.containsKey(node.name)) {
      throw Impossible();
    }

    if (node.expression != null) {
      node.expression = optimize(node.expression!, context);
    }

    if (node.arguments != null) {
      visitAll(node.arguments!, context);
    }

    if (node.keywordArguments != null) {
      visitAll(node.keywordArguments!, context);
    }

    if (node.dArguments != null) {
      node.dArguments = optimize(node.dArguments!, context);
    }

    if (node.dKeywordArguments != null) {
      node.dKeywordArguments = optimize(node.dKeywordArguments!, context);
    }

    return constant(node, context);
  }

  @override
  Expression visitTupleLiteral(TupleLiteral node, [Context? context]) {
    visitAllNotSafe(node.expressions, context);
    return constant(node, context);
  }

  @override
  Expression visitUnary(Unary node, [Context? context]) {
    node.expression = optimize(node.expression, context);
    return constant(node, context);
  }

  @override
  With visitWith(With node, [Context? context]) {
    visitAll(node.values, context);
    visitAll(node.body, context);
    return node;
  }

  @protected
  static Object? resolve(Expression expression, [Context? context]) {
    return expression.accept(const ExpressionResolver(), context);
  }
}
