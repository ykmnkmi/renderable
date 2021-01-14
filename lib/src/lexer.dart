library tokenizer;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:string_scanner/string_scanner.dart';

import 'configuration.dart';

part 'token.dart';

const Map<String, String> operators = <String, String>{
  '-': 'sub',
  ',': 'comma',
  ';': 'semicolon',
  ':': 'colon',
  '!=': 'ne',
  '.': 'dot',
  '(': 'lparen',
  ')': 'rparen',
  '[': 'lbracket',
  ']': 'rbracket',
  '{': 'lbrace',
  '}': 'rbrace',
  '*': 'mul',
  '**': 'pow',
  '/': 'div',
  '//': 'floordiv',
  '%': 'mod',
  '+': 'add',
  '<': 'lt',
  '<=': 'lteq',
  '=': 'assign',
  '==': 'eq',
  '>': 'gt',
  '>=': 'gteq',
  '|': 'pipe',
  '~': 'tilde',
};

const List<String> defaultIgnoredTokens = <String>[
  'whitespace',
  'comment_begin',
  'comment',
  'comment_end',
  'raw_begin',
  'raw_end',
  'linecomment_begin',
  'linecomment_end',
  'linecomment',
];

String escape(String pattern) {
  return RegExp.escape(pattern);
}

RegExp compile(String pattern) {
  return RegExp(pattern, dotAll: true, multiLine: true);
}

class Rule {
  Rule(this.regExp, this.parse);

  final RegExp regExp;

  final Iterable<Token> Function(StringScanner scanner) parse;
}

class Lexer {
  Lexer(Configuration configuration, {this.ignoredTokens = defaultIgnoredTokens})
      : newLineRe = RegExp(r'(\r\n|\r|\n)'),
        whitespaceRe = RegExp(r'\s+'),
        nameRe = RegExp(r'[a-zA-Z][a-zA-Z0-9]*'),
        stringRe = RegExp(r"('([^'\\]*(?:\\.[^'\\]*)*)'" r'|"([^"\\]*(?:\\.[^"\\]*)*)")', dotAll: true),
        integerRe = RegExp(r'(\d+_)*\d+'),
        floatRe = RegExp(r'\.(\d+_)*\d+[eE][+\-]?(\d+_)*\d+|\.(\d+_)*\d+'),
        operatorsRe = RegExp(r'\+|-|\/\/|\/|\*\*|\*|%|~|\[|\]|\(|\)|{|}|==|!=|<=|>=|=|<|>|\.|:|\||,|;'),
        lStripUnlessRe = configuration.lStripBlocks ? compile('[^ \t]') : null,
        newLine = configuration.newLine,
        keepTrailingNewLine = configuration.keepTrailingNewLine {
    final blockSuffixRe = configuration.trimBlocks ? r'\n?' : '';

    final commentBeginRe = escape(configuration.commentBegin);
    final commentEndRe = escape(configuration.commentEnd);
    final commentEnd = compile('(.*?)((?:\\+${commentEndRe}|-${commentEndRe}\\s*|${commentEndRe}${blockSuffixRe}))');

    final variableBeginRe = escape(configuration.variableBegin);
    final variableEndRe = escape(configuration.variableEnd);
    final variableEnd = compile('-${variableEndRe}\\s*|${variableEndRe}');

    final blockBeginRe = escape(configuration.blockBegin);
    final blockEndRe = escape(configuration.blockEnd);
    final blockEnd = compile('(?:\\+${blockEndRe}|-${blockEndRe}\\s*|${blockEndRe}${blockSuffixRe})');

    final rootTagRules = <List<String>>[
      ['comment_begin', configuration.commentBegin, commentBeginRe],
      ['variable_begin', configuration.variableBegin, variableBeginRe],
      ['block_begin', configuration.blockBegin, blockBeginRe],
    ];

    rootTagRules.sort((a, b) => b[1].length.compareTo(a[1].length));

    // 0 - full match
    // 1 - data
    // 2 - raw_being group
    // 3 - raw_being sign
    // n - *_begin group
    // n + 1 - *_begin sign

    final rawBegin = compile('(?<raw_begin>${blockBeginRe}(-|\\+|)\\s*raw\\s*(?:-${blockEndRe}\\s*|${blockEndRe}))');
    final rawEnd = compile('(.*?)((?:${blockBeginRe}(-|\\+|))\\s*endraw\\s*'
        '(?:\\+${blockEndRe}|-${blockEndRe}\\s*|${blockEndRe}${blockSuffixRe}))');

    final rootParts = <String>[
      rawBegin.pattern,
      for (final rule in rootTagRules) '(?<${rule.first}>${rule.last}(-|\\+|))',
    ];

    final rootPartsRe = rootParts.join('|');

    final dataRe = '(.*?)(?:${rootPartsRe})';

    rules = <String, List<Rule>>{
      'root': <Rule>[
        Rule(
          compile(dataRe),
          (scanner) sync* {
            final match = scanner.lastMatch as RegExpMatch;
            final names = match.groupNames.toList();
            final data = match[1]!;
            var state = '';
            var sign = '';

            final groups = match.groups([3, 5, 7, 9]);

            for (var i = 0; i < names.length; i += 1) {
              if (match.namedGroup(names[i]) == null) {
                continue;
              }

              state = names[i];
              sign = groups[i]!;
              break;
            }

            var stripped = data;

            if (sign == '-') {
              stripped = data.trimRight();
            } else if (sign != '+' && lStripUnlessRe != null && match.namedGroup('variable_begin') == null) {
              final position = data.lastIndexOf('\n') + 1;

              if (position > 0) {
                if (data.startsWith(' ', position) || data.startsWith('\t', position)) {
                  stripped = data.substring(0, position);
                }
              } else {
                stripped = data.trimRight();
              }
            }

            if (stripped.isNotEmpty) {
              yield Token(match.start, 'data', stripped);
            }

            if (data.isNotEmpty) {
              scanner.position = match.start + data.length;
            } else {
              scanner.position = match.start;
            }

            yield* scan(scanner, state);
          },
        ),
        Rule(
          compile('.+'),
          (scanner) sync* {
            yield Token(scanner.position, 'data', scanner.lastMatch![0]!);
          },
        ),
      ],
      'comment_begin': [
        Rule(
          compile('$commentBeginRe[\\+-]?\\s*'),
          (scanner) sync* {
            var match = scanner.lastMatch as RegExpMatch;
            yield Token.simple(match.start, 'comment_begin');

            if (!scanner.scan(commentEnd)) {
              throw 'comment end expected.';
            }

            match = scanner.lastMatch as RegExpMatch;
            final comment = match[1]!;
            yield Token(match.start, 'comment', comment.trim());
            yield Token.simple(match.start + comment.length, 'comment_end');
          },
        ),
      ],
      'variable_begin': [
        Rule(
          compile('$variableBeginRe[\\+-]?\\s*'),
          (scanner) sync* {
            final match = scanner.lastMatch as RegExpMatch;
            yield Token.simple(match.start, 'variable_begin');
            yield* expression(scanner, variableEnd);

            if (!scanner.scan(variableEnd)) {
              throw 'expression end expected.';
            }

            yield Token.simple(match.start, 'variable_end');
          },
        ),
      ],
      'block_begin': [
        Rule(
          compile('$blockBeginRe[\\+-]?\\s*'),
          (scanner) sync* {
            var match = scanner.lastMatch as RegExpMatch;
            yield Token.simple(match.start, 'block_begin');
            yield* expression(scanner, blockEnd);

            if (!scanner.scan(blockEnd)) {
              throw 'statement end expected.';
            }

            match = scanner.lastMatch as RegExpMatch;
            yield Token.simple(match.start, 'block_end');
          },
        ),
      ],
      'raw_begin': [
        Rule(
          rawBegin,
          (scanner) sync* {
            var match = scanner.lastMatch as RegExpMatch;
            yield Token.simple(match.start, 'raw_begin');

            if (!scanner.scan(rawEnd)) {
              throw 'missing end of raw directive';
            }

            match = scanner.lastMatch as RegExpMatch;

            final data = match[1]!;
            final sign = match[3]!;
            final stripped = sign == '-' ? data.trimRight() : data;
            yield Token(match.start, 'data', stripped);
            yield Token.simple(match.start + data.length, 'raw_end');
          },
        ),
      ],
    };
  }

  final RegExp newLineRe;

  final RegExp whitespaceRe;

  final RegExp nameRe;

  final RegExp stringRe;

  final RegExp integerRe;

  final RegExp floatRe;

  final RegExp operatorsRe;

  final RegExp? lStripUnlessRe;

  final String newLine;

  final bool keepTrailingNewLine;

  final List<String> ignoredTokens;

  late Map<String, List<Rule>> rules;

  Iterable<Token> tokenize(String source, {String? path}) sync* {
    final lines = const LineSplitter().convert(source);

    if (keepTrailingNewLine && source.isNotEmpty) {
      if (source.endsWith('\r\n') || source.endsWith('\r') || source.endsWith('\n')) {
        lines.add('');
      }
    }

    source = lines.join('\n');

    final scanner = StringScanner(source, sourceUrl: path);
    var notFound = true; // is needed?

    while (!scanner.isDone) {
      for (final token in scan(scanner)) {
        notFound = false;

        if (ignoredTokens.any(token.test)) {
          continue;
        } else if (token.test('linestatement_begin')) {
          yield token.change(type: 'block_begin');
        } else if (token.test('linestatement_end')) {
          yield token.change(type: 'block_end');
        } else if (token.test('data') || token.test('string')) {
          yield token.change(value: normalizeNewLines(token.value));
        } else if (token.test('integer') || token.test('float')) {
          yield token.change(value: token.value.replaceAll('_', ''));
        } else {
          yield token;
        }
      }

      if (notFound) {
        throw 'unexpected char ${scanner.rest[0]} at ${scanner.position}.';
      }
    }

    yield Token.simple(source.length, 'eof');
  }

  @protected
  String normalizeNewLines(String value) {
    return value.replaceAll(newLineRe, newLine);
  }

  @protected
  Iterable<Token> scan(StringScanner scanner, [String state = 'root']) sync* {
    for (final rule in rules[state]!) {
      if (scanner.scan(rule.regExp)) {
        yield* rule.parse(scanner);
        break;
      }
    }
  }

  @protected
  Iterable<Token> expression(StringScanner scanner, RegExp end) sync* {
    final stack = <String>[];

    while (!scanner.isDone) {
      if (stack.isEmpty && scanner.matches(end)) {
        return;
      } else if (scanner.scan(whitespaceRe)) {
        yield Token(scanner.lastMatch!.start, 'whitespace', scanner.lastMatch![0]!);
      } else if (scanner.scan(nameRe)) {
        yield Token(scanner.lastMatch!.start, 'name', scanner.lastMatch![0]!);
      } else if (scanner.scan(stringRe)) {
        yield Token(scanner.lastMatch!.start, 'string', scanner.lastMatch![2] ?? scanner.lastMatch![3] ?? '');
      } else if (scanner.scan(integerRe)) {
        final start = scanner.lastMatch!.start;
        final integer = scanner.lastMatch![0]!;

        if (scanner.scan(floatRe)) {
          yield Token(start, 'float', integer + scanner.lastMatch![0]!);
        } else {
          yield Token(start, 'integer', integer);
        }
      } else if (scanner.scan(operatorsRe)) {
        final operator = scanner.lastMatch![0]!;

        if (operator == '(') {
          stack.add(')');
        } else if (operator == '[') {
          stack.add(']');
        } else if (operator == '{') {
          stack.add('}');
        } else if (operator == ')' || operator == ']' || operator == '}') {
          if (stack.isEmpty) {
            scanner.position -= 1;
            return;
          }

          final expected = stack.removeLast();

          if (operator != expected) {
            throw 'unexpected char ${scanner.rest[0]} at ${scanner.position}\'$operator\', expected \'$expected\'.';
          }
        }

        yield Token.simple(scanner.lastMatch!.start, operators[operator]!);
      } else {
        break;
      }
    }
  }

  @override
  String toString() {
    return 'Tokenizer()';
  }
}
