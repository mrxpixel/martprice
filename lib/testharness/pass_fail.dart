sealed class PassFailRule {
  const PassFailRule();
  String describe();
  bool evaluate(String output);
}

class MustContain extends PassFailRule {
  const MustContain(this.needle);
  final String needle;
  @override
  String describe() => 'contains "$needle"';
  @override
  bool evaluate(String output) => output.contains(needle);
}

class MustContainAny extends PassFailRule {
  const MustContainAny(this.needles);
  final List<String> needles;
  @override
  String describe() => 'contains any of $needles';
  @override
  bool evaluate(String output) => needles.any(output.contains);
}

class MustNotContain extends PassFailRule {
  const MustNotContain(this.needle);
  final String needle;
  @override
  String describe() => 'does not contain "$needle"';
  @override
  bool evaluate(String output) => !output.contains(needle);
}

class MustNotMatch extends PassFailRule {
  MustNotMatch(this.pattern, this.label);
  final RegExp pattern;
  final String label;
  @override
  String describe() => 'does not match $label';
  @override
  bool evaluate(String output) => !pattern.hasMatch(output);
}

class MaxLength extends PassFailRule {
  const MaxLength(this.max);
  final int max;
  @override
  String describe() => 'length ≤ $max chars';
  @override
  bool evaluate(String output) => output.length <= max;
}

class PassFailResult {
  const PassFailResult({required this.pass, required this.failures});
  final bool pass;
  final List<String> failures;
}

PassFailResult evaluateAll(List<PassFailRule> rules, String output) {
  final failures = <String>[];
  for (final rule in rules) {
    if (!rule.evaluate(output)) failures.add(rule.describe());
  }
  return PassFailResult(pass: failures.isEmpty, failures: failures);
}
