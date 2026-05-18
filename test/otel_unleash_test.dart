// Licensed under the Dartastic Pro Software License Agreement.
// Copyright 2025-2026 Mindful Software LLC d/b/a Dartastic.io, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry/testing.dart';
import 'package:otel_unleash/otel_unleash.dart';
import 'package:test/test.dart';

void main() {
  late TestHarness harness;
  late InMemorySpanExporter spans;

  setUpAll(() async {
    harness = await maybeInitializeOtelForTest(
      serviceName: 'otel_unleash-test',
    );
    spans = harness.spans;
  });

  setUp(() => harness.clear());

  Map<String, Object> attrsOf(Span s) =>
      {for (final a in s.attributes.toList()) a.key: a.value};

  test('variant.get records variant + stickiness + deployment', () async {
    await tracedUnleash<String>(
      operation: 'variant.get',
      deployment: 'self_hosted',
      invoke: () async => const UnleashCallResult(
        value: 'ok',
        result: UnleashResult(
          toggleName: 'new-checkout',
          enabled: true,
          variantName: 'blue',
          variantStickiness: 'userId',
          project: 'default',
          environment: 'production',
          strategiesEvaluated: 2,
          fromCache: true,
          deployment: 'self_hosted',
        ),
      ),
    );
    final a = attrsOf(spans.findSpanByName('unleash variant.get')!);
    expect(a['unleash.toggle.name'], 'new-checkout');
    expect(a['unleash.variant.name'], 'blue');
    expect(a['unleash.variant.stickiness'], 'userId');
    expect(a['unleash.environment'], 'production');
    expect(a['unleash.deployment'], 'self_hosted');
  });

  test('suppression skips spans', () async {
    await runWithoutUnleashInstrumentationAsync(() async {
      await tracedUnleash<String>(
        operation: 'client.features',
        invoke: () async => const UnleashCallResult(value: 'v'),
      );
    });
    expect(spans.findSpansStartingWith('unleash '), isEmpty);
  });
}
