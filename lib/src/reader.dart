import 'lexer.dart';

class TokenReader {
  TokenReader(Iterable<Token> tokens)
      : _iterator = tokens.iterator,
        _pushed = <Token>[] {
    _current = Token.simple(0, 'initial');
    _isClosed = false;
    next();
  }

  Iterator<Token> _iterator;

  List<Token> _pushed;

  Token _current;

  Token get current {
    return _current;
  }

  bool _isClosed;

  bool get isClosed {
    return _isClosed;
  }

  Iterable<Token> get values {
    return _TokenIterable(this);
  }

  void push(Token token) {
    _pushed.add(token);
  }

  Token look() {
    var old = next();
    var result = current;
    push(result);
    _current = old;
    return result;
  }

  void skip([int n = 1]) {
    for (var i = 0; i < n; i += 1) {
      if (_current.type == 'eof') {
        break;
      }

      if (_iterator.moveNext()) {
        _current = _iterator.current;
      } else {
        close();
        break;
      }
    }
  }

  Token nextIf(String type, [String value]) {
    if (_current.test(type, value)) {
      return next();
    }

    return null;
  }

  bool skipIf(String type, [String value]) {
    return nextIf(type, value) != null;
  }

  Token next() {
    final result = _current;

    if (_current.type != 'eof') {
      if (_iterator.moveNext()) {
        _current = _iterator.current;
      } else {
        close();
      }
    }

    return result;
  }

  void close() {
    _iterator = null;
    _isClosed = true;
    _current = Token.simple(current.start + current.length, 'eof');
  }

  Token expect(String expression) {
    if (!_current.test(expression)) {
      if (_current.type == 'eof') {
        throw 'unexpected end of template, expected $expression';
      }

      throw 'expected token $expression, got $_current';
    }

    return next();
  }
}

class _TokenIterable extends Iterable<Token> {
  _TokenIterable(this.reader);

  final TokenReader reader;

  @override
  Iterator<Token> get iterator {
    return _TokenIterator(reader);
  }
}

class _TokenIterator extends Iterator<Token> {
  _TokenIterator(this.reader);

  final TokenReader reader;

  @override
  Token get current {
    return reader.next();
  }

  @override
  bool moveNext() {
    if (reader.current.test('eof')) {
      reader.close();
      return false;
    }

    return true;
  }
}