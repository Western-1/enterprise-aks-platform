import os

_otlp_endpoint = os.environ.get("OTEL_EXPORTER_OTLP_ENDPOINT", "")


def init_tracing(app=None) -> bool:
    if not _otlp_endpoint:
        return False

    from opentelemetry import trace
    from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
    from opentelemetry.instrumentation.asyncpg import AsyncPGInstrumentor
    from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
    from opentelemetry.sdk.resources import Resource
    from opentelemetry.sdk.trace import TracerProvider
    from opentelemetry.sdk.trace.export import BatchSpanProcessor

    provider = TracerProvider(resource=Resource.create({"service.name": "media-api"}))
    provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter(endpoint=f"{_otlp_endpoint}/v1/traces")))
    trace.set_tracer_provider(provider)
    if app is not None:
        FastAPIInstrumentor().instrument_app(app)
    else:
        FastAPIInstrumentor().instrument()
    AsyncPGInstrumentor().instrument()
    return True