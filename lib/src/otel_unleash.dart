// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'otel_unleash_suppression.dart';

const _tracerName = 'dartastic_otel_libs_unleash';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

class UnleashResult {
  const UnleashResult({
    this.toggleName,
    this.enabled,
    this.variantName,
    this.variantStickiness,
    this.project,
    this.environment,
    this.strategiesEvaluated,
    this.fromCache,
    this.deployment,
    this.requestId,
    this.statusCode,
  });

  /// Toggle name.
  final String? toggleName;

  /// Final boolean decision.
  final bool? enabled;

  /// Variant name if toggle has variants (`disabled` when none).
  final String? variantName;

  /// `default` / `userId` / `sessionId` / `random` — stickiness mode.
  final String? variantStickiness;

  /// Project id.
  final String? project;

  /// `development` / `production` (or custom env).
  final String? environment;

  /// Strategies evaluated on this call.
  final int? strategiesEvaluated;

  /// Whether the SDK answered from in-memory cache (vs upstream).
  final bool? fromCache;

  /// `cloud` / `self_hosted` / `enterprise_self_hosted` — Unleash is
  /// frequently self-hosted; deployment dimension drives reliability
  /// SLO expectations.
  final String? deployment;

  /// `X-Request-Id` (when reverse proxy adds one).
  final String? requestId;

  final int? statusCode;
}

class UnleashCallResult<T> {
  const UnleashCallResult({required this.value, this.result});
  final T value;
  final UnleashResult? result;
}

/// Wraps an Unleash API call in a CLIENT span. [operation] is one of
/// `is_enabled`, `variant.get`, `client.features`, `metrics.send`,
/// `register`, `toggles.list`, `toggles.create`, `toggles.update`,
/// `toggles.archive`, `strategies.list`, `projects.list`,
/// `environments.list`, `tags.list`, `playgrounds.evaluate`.
Future<T> tracedUnleash<T>({
  required String operation,
  required Future<UnleashCallResult<T>> Function() invoke,
  String? deployment,
}) async {
  if (unleashInstrumentationSuppressed()) {
    final r = await invoke();
    return r.value;
  }
  final m = <String, Object>{
    'rpc.system': 'unleash',
    'rpc.method': operation,
    'unleash.operation': operation,
  };
  if (deployment != null) m['unleash.deployment'] = deployment;

  final span = _tracer().startSpan(
    'unleash $operation',
    kind: SpanKind.client,
    attributes: OTel.attributesFromMap(m),
  );
  try {
    final r = await invoke();
    if (r.result != null) {
      final extras = <Attribute<Object>>[];
      if (r.result!.toggleName != null) {
        extras.add(OTel.attributeString(
          'unleash.toggle.name',
          r.result!.toggleName!,
        ));
      }
      if (r.result!.enabled != null) {
        extras.add(OTel.attributeBool(
          'unleash.enabled',
          r.result!.enabled!,
        ));
      }
      if (r.result!.variantName != null) {
        extras.add(OTel.attributeString(
          'unleash.variant.name',
          r.result!.variantName!,
        ));
      }
      if (r.result!.variantStickiness != null) {
        extras.add(OTel.attributeString(
          'unleash.variant.stickiness',
          r.result!.variantStickiness!,
        ));
      }
      if (r.result!.project != null) {
        extras.add(OTel.attributeString(
          'unleash.project',
          r.result!.project!,
        ));
      }
      if (r.result!.environment != null) {
        extras.add(OTel.attributeString(
          'unleash.environment',
          r.result!.environment!,
        ));
      }
      if (r.result!.strategiesEvaluated != null) {
        extras.add(OTel.attributeInt(
          'unleash.strategies_evaluated',
          r.result!.strategiesEvaluated!,
        ));
      }
      if (r.result!.fromCache != null) {
        extras.add(OTel.attributeBool(
          'unleash.from_cache',
          r.result!.fromCache!,
        ));
      }
      if (r.result!.deployment != null) {
        extras.add(OTel.attributeString(
          'unleash.deployment',
          r.result!.deployment!,
        ));
      }
      if (r.result!.requestId != null) {
        extras.add(OTel.attributeString(
          'unleash.request.id',
          r.result!.requestId!,
        ));
      }
      if (r.result!.statusCode != null) {
        extras.add(OTel.attributeInt(
          'http.response.status_code',
          r.result!.statusCode!,
        ));
        if (r.result!.statusCode! >= 400) {
          span.setStatus(
            SpanStatusCode.Error,
            'Unleash HTTP ${r.result!.statusCode}',
          );
        }
      }
      if (extras.isNotEmpty) span.addAttributes(OTel.attributes(extras));
    }
    return r.value;
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}
