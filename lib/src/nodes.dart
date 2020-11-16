library ast;

import 'exceptions.dart';
import 'visitor.dart';

abstract class Node {
  void accept(Visitor visitor);
}

abstract class Expression extends Node {}

class Name extends Expression {
  Name({this.name, this.type = 'dynamic'});

  String name;

  String type;

  @override
  void accept(Visitor visitor) {
    return visitor.visitName(this);
  }

  @override
  String toString() {
    return 'Name($name, $type)';
  }
}

abstract class Literal extends Expression {
  @override
  String toString() {
    return 'Literal()';
  }
}

class Data extends Literal {
  Data({this.data});

  String data;

  @override
  void accept(Visitor visitor) {
    return visitor.visitData(this);
  }

  @override
  String toString() {
    return 'Data("${data.replaceAll('"', r'\"').replaceAll('\r\n', r'\n').replaceAll('\n', r'\n')}")';
  }
}

class Constant<T> extends Literal {
  Constant({this.value});

  T value;

  @override
  void accept(Visitor visitor) {
    return visitor.visitLiteral(this);
  }

  @override
  String toString() {
    return 'Constant<$T>($value)';
  }
}

class TupleLiteral extends Literal {
  TupleLiteral({this.items, this.save = false});

  List<Expression> items;

  bool save;

  @override
  void accept(Visitor visitor) {
    visitor.visitTupleLiteral(this);
  }

  @override
  String toString() {
    return 'TupleLiteral($items)';
  }
}

class ListLiteral extends Literal {
  ListLiteral({this.items});

  List<Expression> items;

  @override
  void accept(Visitor visitor) {
    visitor.visitListLiteral(this);
  }

  @override
  String toString() {
    return 'ListLiteral($items)';
  }
}

class DictLiteral extends Literal {
  DictLiteral({this.items});

  List<Pair> items;

  @override
  void accept(Visitor visitor) {
    visitor.visitDictLiteral(this);
  }

  @override
  String toString() {
    return 'DictLiteral($items)';
  }
}

class Test extends Expression {
  Test({this.name, this.expression});

  String name;

  Expression expression;

  @override
  void accept(Visitor visitor) {
    visitor.visitTest(this);
  }

  @override
  String toString() {
    return 'Test($name, $expression)';
  }
}

class Call extends Expression {
  Call({this.expression, this.arguments, this.keywordArguments});

  Expression expression;

  List<Expression> arguments;

  List<Keyword> keywordArguments;

  @override
  void accept(Visitor visitor) {
    visitor.visitCall(this);
  }

  @override
  String toString() {
    return 'Call($expression, $arguments, $keywordArguments)';
  }
}

class Item extends Expression {
  Item({this.key, this.expression});

  Expression key;

  Expression expression;

  @override
  void accept(Visitor visitor) {
    visitor.visitItem(this);
  }

  @override
  String toString() {
    return 'Item($key, $expression)';
  }
}

class Attribute extends Expression {
  Attribute({this.attribute, this.expression});

  String attribute;

  Expression expression;

  @override
  void accept(Visitor visitor) {
    visitor.visitAttribute(this);
  }

  @override
  String toString() {
    return 'Attribute($attribute, $expression)';
  }
}

class Slice extends Expression {
  factory Slice.fromList(List<Expression> expressions, {Expression expression}) {
    assert(expressions.isNotEmpty);
    assert(expressions.length <= 3);

    switch (expressions.length) {
      case 1:
        return Slice(expression: expression, start: expressions[0]);
      case 2:
        return Slice(expression: expression, start: expressions[0], stop: expressions[1]);
      case 3:
        return Slice(expression: expression, start: expressions[0], stop: expressions[1], step: expressions[2]);
      default:
        throw TemplateRuntimeError();
    }
  }

  Slice({this.expression, this.start, this.stop, this.step});

  Expression expression;

  Expression start;

  Expression stop;

  Expression step;

  @override
  void accept(Visitor visitor) {
    visitor.visitSlice(this);
  }

  @override
  String toString() {
    return 'Slice($expression, $start, $stop, $step)';
  }
}

abstract class Unary extends Expression {
  Unary({this.operator, this.expression});

  String operator;

  Expression expression;

  @override
  void accept(Visitor visitor) {
    visitor.visitUnary(this);
  }

  @override
  String toString() {
    return 'Unary(\'$operator\', $expression)';
  }
}

class Not extends Unary {
  Not({Expression expression}) : super(operator: 'not', expression: expression);

  @override
  String toString() {
    return 'Not($expression)';
  }
}

class Negative extends Unary {
  Negative({Expression expression}) : super(operator: '-', expression: expression);

  @override
  String toString() {
    return 'Negative($expression)';
  }
}

class Positive extends Unary {
  Positive({Expression expression}) : super(operator: '+', expression: expression);

  @override
  String toString() {
    return 'Positive($expression)';
  }
}

abstract class Statement extends Node {}

class Output extends Statement {
  Output({this.items});

  List<Node> items;

  @override
  void accept(Visitor visitor) {
    visitor.visitOutput(this);
  }

  @override
  String toString() {
    return 'Output($items)';
  }
}

class If extends Statement {
  If({this.test, this.body, this.elseIf, this.$else});

  Expression test;

  List<Node> body;

  List<Node> elseIf;

  List<Node> $else;

  @override
  void accept(Visitor visitor) {
    return visitor.visitIf(this);
  }

  @override
  String toString() {
    return 'If($test, $body, $elseIf, ${$else})';
  }
}

abstract class Helper extends Node {}

class Pair extends Helper {
  Pair({this.key, this.value});

  Expression key;

  Expression value;

  @override
  void accept(Visitor visitor) {
    visitor.visitPair(this);
  }

  @override
  String toString() {
    return 'Pair($key, $value)';
  }
}

class Keyword extends Helper {
  Keyword({this.key, this.value});

  String key;

  Expression value;

  @override
  void accept(Visitor visitor) {
    visitor.visitKeyword(this);
  }

  @override
  String toString() {
    return 'Keyword($key, $value)';
  }
}
