# Gotchas and verified corrections

Things this lab found by actually running the stack, not by reading docs. Environment: `kind` v0.31.0 against `podman` v5.8.3 via `KIND_EXPERIMENTAL_PROVIDER=podman` (no Docker CLI on the build machine). Versions used are pinned in the Makefile/scripts.

## Verified end-to-end (not just "pods are Running")

- **Gateway**: `Gateway` → `Accepted=True`, `Programmed=True`. `GatewayClass/agentgateway` → `ACCEPTED=True`.
- **Schedule (Kueue admission loop only)**: `ClusterQueue` → `Active=True, Reason=Ready, "Can admit new workloads"`. Confirmed it is never touched by the request-routing path below — correct, since admission and request routing are separate control loops (see [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Serve**: `InferencePool` → `Accepted=True`, `ResolvedRefs=True`. `HTTPRoute` → `Accepted=True`, `ResolvedRefs=True`, bound to the Gateway. A live request through the full chain (client → port-forwarded Gateway → EPP → simulator pod) returned HTTP 200 with a real OpenAI-style completion body.
- **Observe (gateway/EPP side)**: sent one request with a hand-crafted W3C `traceparent` header carrying a known trace ID. That exact trace ID appeared in the trace backend with **10 correctly nested spans** (`request` → `request_orchestration` → `tokenize` / `run_scheduler_profile` → `scoring` → per-scorer plugin spans → `filter_endpoints` → `pick_endpoints`), all `CHILD_OF`-linked back to the externally supplied parent span ID.

## Corrections to the obvious/documented path

1. **llm-d's `main` branch dropped `kgateway`** from its list of supported gateway providers entirely. The current supported list is Istio, GKE Gateway, **agentgateway**, Envoy AI Gateway, and NGINX Gateway Fabric. This lab uses **agentgateway**, which worked cleanly. Its own Helm chart's post-install notes point to `kgateway.dev/docs`, confirming agentgateway is maintained under the kgateway project as its AI-gateway-focused component — not a separate, competing project. **Re-check this before relying on it; this ecosystem moves fast.**

2. **`llm-d-inference-sim` defaults to a real HuggingFace model name** in its own example manifest, which triggers a `vllm-render` tokenizer sidecar requiring real network/HF access — defeating the point of a no-GPU, no-network lab. **Use an explicit dummy/non-existent model name** (e.g. `--model lab-dummy-model`) to get the simulator's actual "Simulated Mode" with zero external dependencies.

3. **Setting `router.tracing.otelExporterEndpoint` and `.sampling` alone does not enable tracing.** `router.tracing.enabled=true` must be set explicitly — confirmed by inspecting the EPP pod's actual launch args, which still showed `--tracing=false` without it.

4. **The router chart's real default sampling is 10%** (`parentbased_traceidratio`, `samplerArg: "0.1"`), not the 5% some older references suggest. Override to `"1.0"` for lab/demo purposes or you'll intermittently fail to find your test trace.

5. **`llm-d-inference-sim` has zero OpenTelemetry/tracing support.** No `--otlp-traces-endpoint` flag or any OTel integration exists in the simulator, confirmed by inspecting its full config reference. This is a **structural limitation**, not a bug in this lab: the GPU-free serve path can prove gateway+EPP-side trace correlation, but it cannot prove serve-layer span emission. Closing that gap requires a real vLLM instance (see `docs/ALTERNATIVES.md`).

## Open issue (not yet resolved)

**The EPP's root `request` span reports `error=True, status=ModelServerError` even on a fully successful request** (client got a correct HTTP 200 with valid output). The likely cause is the EPP attempting to scrape vLLM-style Prometheus metrics (`vllm:num_requests_waiting`, etc.) from the simulator, which may not expose them in the exact expected format. The request itself works correctly — this is a telemetry/status-reporting quirk, not a functional failure — but it means the EPP/simulator pairing isn't "clean" yet from an observability standpoint. Worth investigating before treating this combination as a reference example of healthy tracing.

If you find the root cause, a PR to this repo (or upstream to `llm-d-inference-sim` / the router chart) would be genuinely useful — this wasn't tracked down further here due to time.

## What wasn't attempted in this lab

- KServe + real vLLM (the alternative serving path that would close the serve-layer tracing gap)
- Volcano, KAI Scheduler, HAMi (GPU hardware or scheduler-conflict reasons — see `ALTERNATIVES.md`)
- Istio, Envoy AI Gateway, Praxis as alternate gateways (documented, not run)
- Secure-execution adjacent projects (nono, OpenShell, Agent Substrate, gVisor)

See `docs/ALTERNATIVES.md` for the full per-layer status.
