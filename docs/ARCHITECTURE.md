# Architecture

## The composable stack

```
Observe      OpenTelemetry (gen_ai.* spans), traces, latency, cost attribution
Serve        llm-d-inference-sim, KServe + vLLM, Ray Serve, SGLang, Triton
Gateway      Gateway API + Inference Extension, agentgateway, Istio, Envoy AI Gateway, Praxis
Schedule     Kueue, Kubernetes scheduler + HAMi, KubeRay, llm-d Endpoint Picker (EPP)
Accelerate   GPUs, TPUs, DPUs, DRA, device plugins, HAMi sharing
Control      Kubernetes primitives
```

Each layer is an independent replacement boundary and failure domain. A serving engine change should leave the gateway boundary intact. A new accelerator should fit the same operational model. An observability change should preserve correlation across gateway, scheduling, runtime, and model.

## Correction: "schedule" is not one layer

The most common mental-model mistake in this space is treating "schedule" as a single blended layer that the gateway talks to. It is not. There are **four separate, cooperating control loops**, each owning a different decision:

| Control loop | Owns | Does not do |
| :--- | :--- | :--- |
| **llm-d Endpoint Picker (EPP)** | Inference-*request* placement onto already-running model endpoints, using live serving metrics | Does not allocate pods or GPUs |
| **Kueue** | Workload *admission* and quota/fairness — which pending pods get resources | Does not pick which endpoint serves a given request |
| **Kubernetes scheduler + HAMi** | Pod *placement* and accelerator allocation/sharing | Not a request router |
| **KubeRay** | RayCluster/RayJob *lifecycle* | Not a replacement Kubernetes pod scheduler |

The gateway talks to the EPP for request routing. The EPP gets its signals from **the serving layer's own metrics** (`vllm:num_requests_waiting`, `vllm:num_requests_running`, `vllm:kv_cache_usage_perc`) — **not** from Kueue. Kueue is a separate, slower-moving admission loop underneath all of this.

This lab proved that independence directly: the Kueue `ClusterQueue` in this repo was never touched by the end-to-end request test, and that's correct — request routing and resource admission are genuinely separate concerns.

## How the gateway actually talks to the EPP

The gateway sends request headers/body to the EPP via gRPC `ext_proc` (Envoy's external processing protocol); the EPP evaluates candidate endpoints and returns the chosen address. This is a routing decision over already-running pods — not a Kubernetes scheduler call, and not a Kueue interaction.

```text
Client → Gateway → EPP consultation (gRPC ext_proc) → selected model endpoint
                       ↑
             endpoint state + engine metrics (vllm:num_requests_waiting,
             vllm:kv_cache_usage_perc, vllm:num_requests_running)
```

## Priority and SLO signals ride in request headers

Not a separate control plane — llm-d's header contract (verify against your pinned Router version; these names are for v0.9.0+):

- `x-llm-d-inference-objective` → maps to an `InferenceObjective` in the pool's namespace
- `x-llm-d-inference-fairness-id` → the fairness flow identifier
- `x-llm-d-slo-ttft-ms` / `x-llm-d-slo-tpot-ms` → latency targets used by scoring plugins

Flow control (tenant fairness) is feature-gated (`flowControl`) — installing the EPP does not turn this on by itself. If you want to demo fairness/priority, **strip any externally supplied copies of these headers and inject trusted values at the gateway**, since nothing stops a client from spoofing them otherwise.

## The serving-engine swap boundary

An `InferencePool` selects pods **by label, within its namespace** — it does not select an `InferenceService` CR directly, and it does not auto-adapt protocol. A clean serving-engine swap means:

1. Freeze the client contract first: hostname, base path, logical `model` name, auth, streaming/error behavior.
2. Keep the same pool identity and target port; change which labeled pods are eligible backends.
3. Validate **two** contracts, not one: the client-facing inference API, and the scheduler-facing metrics/protocol (an OpenAI-compatible engine isn't automatically compatible with every vLLM-specific scheduling plugin).
4. Cut over only after a non-streaming request, a streaming request, and an error case all pass identically before and after.

## Observability: spans describe, they don't connect

`gen_ai.*` attributes describe individual spans — they do not connect them into a trace. Three layers each emitting a span with matching `gen_ai.request.model` values to the same collector is not a distributed trace. Correlation comes entirely from **W3C trace-context propagation** (`traceparent`/`tracestate`): extract the incoming context, start the local span as a *child* of it (not a fresh root), carry it through any async work, and inject it into the next outbound call.

The EPP boundary is the one most likely to break silently. Because the gateway talks to the EPP via a gRPC `ext_proc` callback rather than a normal HTTP hop, it's easy to end up with the EPP's span as an orphaned new root instead of a child of the incoming request. llm-d's own scheduler implementation deliberately delays starting its span until request headers (and therefore trace context) arrive, specifically to avoid this.

Treat "telemetry reaches the collector" and "one request produces a connected trace across gateway → schedule → serve" as two separate, both-required acceptance criteria — not one. See [`GOTCHAS.md`](GOTCHAS.md) for what this lab could and couldn't prove on that front.
