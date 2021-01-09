// ignore_for_file: avoid_print, invalid_use_of_protected_member

import 'package:renderable/src/enirvonment.dart';
import 'package:renderable/src/lexer.dart';
import 'package:renderable/src/parser.dart';
import 'package:renderable/src/reader.dart';
import 'package:stack_trace/stack_trace.dart';

void main(List<String> arguments) {
  final source = '{% set ns = namespace(d, self=37) %}{% set ns.b = 42 %}{{ ns.a }}|{{ ns.self }}|{{ ns.b }}';

  try {
    final environment = Environment();

    print('source:');
    print(source);

    final lexer = Lexer(environment);
    final tokens = lexer.tokenize(source);

    print('\ntokens:');
    tokens.forEach(print);

    final reader = TokenReader(tokens);
    final parser = Parser(environment);
    final nodes = parser.scan(reader);

    print('\nnodes:');
    nodes.forEach(print);

    final template = Template.parsed(environment, nodes);
    print('\ntemplate nodes:');
    template.nodes.forEach(print);

    print('\nrender:');
    print(template.render({'d': {'a': 13}}));
  } catch (error, trace) {
    print(error);
    print(Trace.from(trace));
  }
}
