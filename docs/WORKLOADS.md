# Realistic workload patterns

The thesis of this lab (and the talk it comes from) is that inference traffic is bursty, multi-model, multi-team, and multi-accelerator — a single-turn completion request doesn't exercise any of that. These scripts generate more realistic traffic *shapes* against the lab's OpenAI-compatible endpoint. They're lightweight curl-based generators, not full agent frameworks — the goal is traffic shape, not a real agent implementation.

All scripts assume a port-forward to the gateway is already running:

```bash
kubectl port-forward -n inference-lab svc/llm-d-inference-gateway 8080:80 &
```

## Multi-turn conversational loop

`scripts/workloads/multi-turn.sh`

Sends a sequence of requests where each prompt includes the growing conversation context from prior turns. Exercises prefix-cache / KV-cache locality: does the gateway/EPP route repeat traffic from the same conversation to the same endpoint to benefit from cached prefix state?

```bash
TURNS=5 ./scripts/workloads/multi-turn.sh
```

## Tool-calling / ReAct-style burst

`scripts/workloads/tool-call-burst.sh`

Interleaves short "planning" calls with longer "generation" calls at irregular intervals, mimicking an agent loop that calls a tool, waits, then generates a response based on the tool's output. Exercises queueing behavior and the gateway's backpressure/retry handling under mixed request sizes.

```bash
ROUNDS=10 ./scripts/workloads/tool-call-burst.sh
```

## Concurrent multi-tenant load

`scripts/workloads/multi-tenant.sh`

Runs several simulated "tenants" concurrently, each tagging its requests with a distinct `x-llm-d-inference-fairness-id` header. Exercises the gateway/EPP's request-level fairness mechanism — this is different from Kueue's resource fairness (see `docs/ARCHITECTURE.md`); don't conflate what this script measures with Kueue quota behavior.

```bash
TENANTS=3 REQUESTS_PER_TENANT=10 ./scripts/workloads/multi-tenant.sh
```

## Bursty, mostly-idle agent pattern

`scripts/workloads/bursty-idle.sh`

Idles, then fires a sudden concurrent burst — the traffic shape that motivates autoscaling signals like KEDA + EPP metrics (described in this lab's upstream research, not implemented here). Useful for observing queue depth and per-request latency degradation under a sudden load spike, even without an autoscaler actually reacting to it.

```bash
IDLE_SECONDS=15 BURST_SIZE=20 ./scripts/workloads/bursty-idle.sh
```

## Relationship to load testing and evals

These scripts describe *shape* (timing, concurrency, header patterns) — they're not a substitute for [`scripts/06-loadtest.sh`](../scripts/06-loadtest.sh) (raw throughput/latency measurement) or the evaluation tools in [`EVALS.md`](EVALS.md) (quality/cost judged against a standard). Use all three for different questions: shape scripts answer "does the system behave sanely under this traffic pattern," the load test answers "how fast is it," and an eval tool answers "is the output any good."
