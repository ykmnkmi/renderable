// ignore_for_file: inference_failure_on_collection_literal

import 'package:renderable/jinja.dart';
import 'package:renderable/reflection.dart';
import 'package:renderable/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('Set', () {
    final environment = Environment(getField: getField, trimBlocks: true);

    test('normal', () {
      final template = environment.fromString('{% set foo = 1 %}{{ foo }}');
      expect(template.render(), equals('1'));
    });

    test('block', () {
      final template = environment.fromString('{% set foo %}42{% endset %}{{ foo }}');
      expect(template.render(), equals('42'));
    });

    test('block escaping', () {
      final env = Environment(autoEscape: true);
      final template = env.fromString('{% set foo %}<em>{{ test }}</em>{% endset %}foo: {{ foo }}');
      expect(template.render({'test': '<unsafe>'}), equals('foo: <em>&lt;unsafe&gt;</em>'));
    });

    test('set invalid', () {
      expect(() => environment.fromString('{% set foo["bar"] = 1 %}'), throwsA(isA<TemplateSyntaxError>()));

      final template = environment.fromString('{% set foo.bar = 1 %}');
      expect(() => template.render({'foo': {}}), throwsA(predicate((error) => error is TemplateRuntimeError && error.message == 'non-namespace object')));
    });

    test('namespace redefined', () {
      final template = environment.fromString('{% set ns = namespace() %}{% set ns.bar = "hi" %}');
      expect(() => template.render({'namespace': () => {}}), throwsA(predicate((error) => error is TemplateRuntimeError && error.message == 'non-namespace object')));
    });

    test('namespace', () {
      final template = environment.fromString('{% set ns = namespace() %}{% set ns.bar = "42" %}{{ ns.bar }}');
      expect(template.render(), equals('42'));
    });

    test('namespace block', () {
      final template = environment.fromString('{% set ns = namespace() %}{% set ns.bar %}42{% endset %}{{ ns.bar }}');
      expect(template.render(), equals('42'));
    });

    test('init namespace', () {
      final template = environment.fromString('{% set ns = namespace(d, self=37) %}{% set ns.b = 42 %}{{ ns.a }}|{{ ns.self }}|{{ ns.b }}');
      expect(template.render({'d': {'a': 13}}), equals('13|37|42'));
    });

    test('namespace loop', () {
      final template = environment.fromString('{% set ns = namespace(found=false) %}{% for x in range(4) %}{% if x == v %}'
          '{% set ns.found = true %}{% endif %}{% endfor %}{{ ns.found }}');
      expect(template.render({'v': 3}), equals('true'));
      expect(template.render({'v': 4}), equals('false'));
    });

    // TODO: namespace macro

    test('block escapeing filtered', () {
      final env = Environment(autoEscape: true);
      final template = env.fromString('{% set foo | trim %}<em>{{ test }}</em>    {% endset %}foo: {{ foo }}');
      expect(template.render({'test': '<unsafe>'}), equals('foo: <em>&lt;unsafe&gt;</em>'));
    });

    test('block filtered', () {
      final template = environment.fromString('{% set foo | trim | length | string %} 42    {% endset %}{{ foo }}');
      expect(template.render(), equals('2'));
    });

    test('block filtered set', () {
      dynamic myfilter(dynamic value, dynamic arg) {
        assert(arg == ' xxx ');
        return value;
      }

      environment.filters['myfilter'] = myfilter;
      final template = environment.fromString('{% set a = " xxx " %}{% set foo | myfilter(a) | trim | length | string %} '
          '{% set b = " yy " %} 42 {{ a }}{{ b }}   {% endset %}{{ foo }}');
      expect(template.render(), equals('11'));
    });
  });
}
