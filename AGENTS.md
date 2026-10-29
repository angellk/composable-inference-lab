# AGENTS.md

Context for any coding agent working in this repository. See https://agents.md for the standard this file follows.

## What this repo is

A hands-on, runnable lab for production inference on Kubernetes as a **composable stack of open, swappable layers**: gateway, schedule, serve, observe. It is not a framework or a product — it is a verified reference setup plus documentation of what works, what's a known gap, and what's an alternative that wasn't run.

## How to run it

```bash
make all      # cluster + gateway + schedule + serve + observe, in order
make verify   # run the acceptance tests for each layer
make loadtest # generate realistic inference traffic against the live endpoint
make clean    # tear down the kind cluster
```

Each `make` target maps to one script in `scripts/`. Read the script before running it if you want to know exactly what it does — they're short and not abstracted behind extra tooling on purpose.

## Layer-by-layer architecture

```
Observe      OpenTelemetry (gen_ai.* spans), traces, latency, cost attribution
Serve        llm-d-inference-sim, KServe + vLLM, Ray Serve, SGLang, Triton
Gateway      Gateway API + Inference Extension, agentgateway, Istio, Envoy AI Gateway, Praxis
Schedule     Kueue, Kubernetes scheduler + HAMi, KubeRay, llm-d Endpoint Picker (EPP)
Accelerate   GPUs, TPUs, DPUs, DRA, device plugins, HAMi sharing
Control      Kubernetes primitives
```

**Load-bearing fact for anyone extending this repo:** "schedule" is not one layer. It's four separate control loops (the llm-d Endpoint Picker for request routing, Kueue for admission/quota, the Kubernetes scheduler + HAMi for pod placement/accelerator allocation, and KubeRay for Ray lifecycle). Conflating them is the most common mistake when reasoning about or extending this stack. Full detail: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Where things live

- `scripts/` — one script per layer, called by the `Makefile`. Idempotent where practical.
- `manifests/` — the Kubernetes YAML each script applies, organized by layer.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — the stack model and the four-control-loop correction.
- [docs/GOTCHAS.md](docs/GOTCHAS.md) — verified findings, corrections to the "obvious" path, and one open issue (an EPP span reports `error=True` on a successful request — see that file for the suspected cause).
- [docs/ALTERNATIVES.md](docs/ALTERNATIVES.md) — per-layer alternate projects, each tagged VERIFIED or DOCUMENTED. Don't assume something marked DOCUMENTED works until you've run it.
- [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) — what could go wrong running this lab, and how to avoid it.
- [docs/EVALS.md](docs/EVALS.md) — recommended (not integrated) tools for evaluating real model behavior once you swap in a real model.
- [docs/WORKLOADS.md](docs/WORKLOADS.md) — realistic traffic shapes to run through the lab beyond single-turn completions.

## Conventions for changes

- Every claim in [docs/GOTCHAS.md](docs/GOTCHAS.md) should be something that was actually run and verified, not copied from upstream docs without checking. If you add a finding, say how you verified it.
- [docs/ALTERNATIVES.md](docs/ALTERNATIVES.md) status tags (VERIFIED / DOCUMENTED / NEEDS GPU HARDWARE) are load-bearing — don't flip a DOCUMENTED entry to VERIFIED without actually running it.
- Keep this repo vendor-neutral. Every project referenced here is upstream open source; don't add anything that implies endorsement of a specific commercial distribution.
- No secrets, kubeconfigs, or cloud credentials should ever be committed — see [docs/THREAT_MODEL.md](docs/THREAT_MODEL.md) and `.gitignore`.

## Linting this file

This file and any other agent-instruction files in this repo are linted with [skillsaw](https://github.com/stbenjam/skillsaw) (`uvx skillsaw lint .`), a public, Apache-2.0-licensed linter for AI coding agent context files. Run it before committing changes here.
