# Evaluating real model behavior

This lab's default serve-layer path (`llm-d-inference-sim`) is a simulator — it proves routing, scheduling, and gateway correlation, but it does not generate real model output, so there's nothing meaningful to evaluate for quality, cost, or latency against a real workload. Once you swap in a real model (KServe + vLLM, or llm-d's GPU-assumed deployer path), you'll want a real evaluation tool. This lab doesn't integrate one — that's a deliberate scope boundary — but here are two vendor-neutral, foundation-governed recommendations.

## HolmesGPT (recommended for cloud-native / Kubernetes-context evals)

[HolmesGPT](https://github.com/HolmesGPT/holmesgpt) is a CNCF Sandbox project (accepted 2025-10-08) built as an AI troubleshooting agent for Kubernetes/cloud-native environments. It ships a real benchmarking/evals architecture — custom evals that score model performance, cost, and latency, with an automated weekly benchmark suite run in CI across multiple LLMs.

Why it's a reasonable fit here specifically: this lab is itself a Kubernetes/cloud-native inference context, and HolmesGPT's evals are built for exactly that kind of environment rather than a generic LLM benchmark. If you extend this lab with a real model and want to evaluate it in a way that understands Kubernetes-shaped problems, start there.

## MLflow (recommended as the general-purpose alternative)

[MLflow](https://mlflow.org/) is a Linux Foundation-governed, OpenTelemetry-native ML lifecycle platform with built-in GenAI evaluation and tracing support. It's a better fit than HolmesGPT if you want general-purpose model evaluation (accuracy, relevance, custom judge-based scoring) decoupled from a Kubernetes-troubleshooting framing, or if you want evaluation results to live alongside experiment tracking you're already using elsewhere.

Its OTel-native tracing also means it composes naturally with this lab's existing observability layer (`docs/ARCHITECTURE.md`) — MLflow traces and this lab's `gen_ai.*` spans speak the same underlying protocol.

## What this means in practice

Neither tool is wired into this repo's scripts or Makefile. If you add one:

1. Point it at the real serving endpoint (KServe/vLLM `InferenceService`, not the simulator — the simulator has no real model behavior to evaluate).
2. Keep evaluation traffic separate from the load-testing traffic in [`WORKLOADS.md`](WORKLOADS.md) — one measures quality/cost/latency against a judged standard, the other measures raw throughput/latency under load. Conflating the two muddies both results.
3. Document which tool you used and why in a PR, the same way [`GOTCHAS.md`](GOTCHAS.md) documents verified findings — "it's recommended in a doc" is not the same as "it was run and the results are known."
