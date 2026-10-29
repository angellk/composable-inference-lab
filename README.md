# Composable Inference Lab

A hands-on lab for running production inference on Kubernetes as a **composable stack of open, swappable layers**: gateway, schedule, serve, observe, instead of a single closed vertical.

This repo stands up each layer on a local `kind` cluster, verifies it with real requests (not just `kubectl get pods`), and documents what actually works, what's a known gap, and what's documented-but-not-yet-verified.

This lab isn't a live demo. It exists to back a talk's claims with verified proof points, and as a take-home resource for running the same verification yourself after the talk.

## Thesis

Production inference on Kubernetes should be composed from open, swappable layers instead of rebuilt as a closed vertical for every model, accelerator, or team. A healthy architecture lets you change the serving engine without replacing the gateway, add accelerators without forking the platform, and attribute cost and latency through shared telemetry.

## The stack

```
Observe      OpenTelemetry (gen_ai.* spans), traces, latency, cost attribution
Serve        llm-d-inference-sim, KServe + vLLM, Ray Serve, SGLang, Triton
Gateway      Gateway API + Inference Extension, agentgateway, Istio, Envoy AI Gateway, Praxis
Schedule     Kueue, Kubernetes scheduler + HAMi, KubeRay, llm-d Endpoint Picker (EPP)
Accelerate   GPUs, TPUs, DPUs, DRA, device plugins, HAMi sharing
Control      Kubernetes primitives
```

See [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full model, including a correction worth internalizing before you build anything on top of this: **"schedule" is not one layer**. It's four separate, cooperating control loops (the llm-d Endpoint Picker, Kueue, the Kubernetes scheduler + HAMi, and KubeRay) with different jobs. Treating them as one is the single most common source of confused debugging in this space.

## What's actually verified vs. documented

This lab distinguishes what was **run and confirmed end-to-end** from what's **documented with working commands but not personally verified**. See [`docs/ALTERNATIVES.md`](docs/ALTERNATIVES.md) for the full per-layer breakdown. Short version:

| Layer | Verified | Documented only |
| :--- | :--- | :--- |
| Gateway | agentgateway + Gateway API Inference Extension | Istio, Envoy AI Gateway, Praxis |
| Schedule | Kueue (admission/quota loop) | Volcano, KAI Scheduler, HAMi (needs GPU hardware) |
| Serve | llm-d-inference-sim (GPU-free simulator) | KServe + vLLM, Ray Serve, SGLang, Triton |
| Observe | OTel trace correlation across gateway → EPP | Serve-layer span emission (structural gap, see [Gotchas](docs/FINDINGS.md)) |

## Prerequisites

- `kind`, `kubectl`, `helm`
- A container runtime `kind` can use: Docker, or `podman` with `KIND_EXPERIMENTAL_PROVIDER=podman` (this lab was built and verified against podman; if your podman machine is stale or undersized, resize it first: `podman machine set --cpus 4 --memory 8192 --disk-size 40 <machine-name>`)
- No GPU required for the core path (gateway → schedule → serve → observe). A GPU is only needed for HAMi and for the KServe + real vLLM alternative serving path.

## Quickstart

```bash
make all      # cluster + gateway + schedule + serve + observe, in order
make verify   # run the acceptance tests for each layer
```

Or step through it layer by layer:

```bash
make cluster
make gateway
make schedule
make serve
make observe
```

See the `Makefile` and `scripts/` for what each target actually runs, and [`docs/FINDINGS.md`](docs/FINDINGS.md) for the gotchas you'll hit along the way. Most of them are already fixed in these scripts, but a few (like the EPP reporting an error status on an otherwise-successful request) are open and worth knowing about before you demo this.

## Layout

```
.
├── Makefile              # orchestrates the layers
├── scripts/              # one script per layer, idempotent where practical
├── manifests/
│   ├── gateway/          # Gateway API CRDs, agentgateway, Inference Extension
│   ├── schedule/         # Kueue ResourceFlavor/ClusterQueue/LocalQueue
│   ├── serve/            # llm-d-inference-sim + llm-d router/EPP
│   └── observe/          # Jaeger (used directly as the OTLP backend)
└── docs/
    ├── ARCHITECTURE.md   # the composable stack model and the four-control-loop correction
    ├── FINDINGS.md       # verified gotchas, corrections, and open issues
    └── ALTERNATIVES.md   # per-layer alternate projects, verified vs. documented-only
```

## License

Apache 2.0, see [LICENSE](LICENSE).
