// ignore_for_file: avoid_print

import 'package:renderable/jinja.dart';
import 'package:stack_trace/stack_trace.dart';

void main() {
  try {
    final environment = Environment();
    final template = environment.fromString('{% for i in items %}{{ i }}{% if not loop.last %},{% endif %}{% endfor %}');
    print(template.nodes);
    print(template.render(<String, Object>{'items': <int>[1, 2, 3]}));
  } catch (error, trace) {
    print(error);
    print(Trace.from(trace));
  }
}
