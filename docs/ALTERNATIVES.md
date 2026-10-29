# Alternatives per layer

Status key: **VERIFIED** = actually run in this lab with real acceptance checks. **DOCUMENTED** = commands/config provided and sourced from upstream docs, not personally run here.

## Gateway

| Project | Status | Notes |
| :--- | :--- | :--- |
| **agentgateway** | VERIFIED | Used in this lab. `Gateway`/`GatewayClass` both reach `Programmed=True`/`ACCEPTED=True`; maintained under the kgateway project as its AI-gateway-focused component. |
| kgateway | DOCUMENTED (deprecated path) | llm-d's `main` branch has dropped kgateway from its supported-providers list; don't lead with it for new llm-d work. Still a general-purpose Gateway API implementation outside the llm-d context. |
| **Istio** | VERIFIED | Installed with `SUPPORT_GATEWAY_API_INFERENCE_EXTENSION=true`/`ENABLE_GATEWAY_API_INFERENCE_EXTENSION=true`, ran alongside agentgateway simultaneously, both routing to the same `InferencePool`. Requires a `DestinationRule` with `tls.mode: SIMPLE` targeting the EPP service; its `h2c` protocol hint misleadingly suggests plaintext, but the EPP actually terminates TLS on that port. Without it, the `ext_proc` filter fails silently before reaching the EPP. |
| Envoy AI Gateway | DOCUMENTED | Same CRD model (`AIGatewayRoute`, `AIServiceBackend`). Not run in this lab. |
| Praxis | CHECKED, NOT CURRENTLY VIABLE | Its operator supports `GatewayClass`/`Gateway`/`HTTPRoute`/`ReferenceGrant` only; its own docs list `ExtensionRef` filters as "logged and dropped," with no `InferencePool`/EPP/`ext-proc` support in either the operator or its separate `ai` repo. A real, relevant CNCF project for the gateway layer generally, just not a tested fit for this specific Inference Extension pattern yet. |

## Schedule

The four control loops (see `ARCHITECTURE.md`) should be proved **independently**, not stacked blind. There's no single validated end-to-end compatibility matrix across all of them.

| Project | Status | Notes |
| :--- | :--- | :--- |
| **Kueue** | VERIFIED | `ClusterQueue` reaches `Active=True, Ready`. Proved independently, correctly never touched by the request-routing path. |
| **llm-d Endpoint Picker (EPP)** | VERIFIED | Request-placement loop, proven via the end-to-end serve test. |
| **Volcano** | VERIFIED | A `batch.volcano.sh/v1alpha1` Job with `schedulerName: volcano` scheduled and ran cleanly. Don't run alongside Kueue as the default scheduler on the same cluster; they compete for the scheduler slot. |
| **KAI Scheduler** | VERIFIED | A plain Pod with `kai.scheduler/queue: default-queue` label and `schedulerName: kai-scheduler` scheduled and ran cleanly; default queue hierarchy was present with zero setup. Same scheduler-slot caveat as Volcano. |
| HAMi | **NEEDS GPU HARDWARE** | GPU sharing cannot be meaningfully validated on a laptop `kind` cluster. If you do get GPU hardware: disable the NVIDIA GPU Operator's own device plugin (`devicePlugin.enabled=false`) before installing HAMi, or both will try to advertise `nvidia.com/gpu`. HAMi's memory/compute limits are a software/reactive mechanism, not hardware MIG isolation; don't present it as a hard instantaneous guarantee. |
| KubeRay | DOCUMENTED | Ray cluster/job *lifecycle* management, not a replacement pod scheduler. A Kueue-managed `RayJob` cannot target an already-existing `RayCluster`; Ray's autoscaling integration with Kueue is version/feature-gate dependent, so start with a fixed worker count. |

## Serve

| Project | Status | Notes |
| :--- | :--- | :--- |
| **llm-d-inference-sim** | VERIFIED | GPU-free, OpenAI-compatible simulator. Does not need KServe to run standalone. Has zero OTel tracing support (see `FINDINGS.md`); this is the gap that real vLLM would close. |
| KServe + vLLM | ATTEMPTED, BLOCKED | Hard-blocked by `kserve/huggingfaceserver:v0.20.0` having no arm64 manifest, confirmed via image manifest inspection. An Apple Silicon architecture block, not a resource or tuning issue; would need an amd64 host to actually run. Use Standard/RawDeployment mode when you do, not the older Knative/Serverless path, which is pinned to specific version combinations and isn't general-purpose. KServe's newer `LLMInferenceService` is a distinct, llm-d-integrated API; don't mix it with plain `InferenceService` examples. CPU-only runs need extra vLLM flags (`--gpu-memory-utilization`, `--max-model-len`). |
| Ray Serve | DOCUMENTED | Reachable via the KubeRay install if you want one additional serving-abstraction data point. |
| SGLang, Triton | NOT ATTEMPTED | Better represented from their own docs/benchmarks than a rushed local install; this lab deliberately doesn't try to be a serving-engine benchmark. |

## Observe

| Project | Status | Notes |
| :--- | :--- | :--- |
| **Jaeger (all-in-one)** | VERIFIED | Used directly as the OTLP trace backend; its built-in OTLP receiver on 4317/4318 made a separate OTel Collector unnecessary for this lab's scope. |
| OpenTelemetry Collector | DOCUMENTED | Needed once you want processing/routing/multiple exporters beyond a single Jaeger instance. |
| Tempo | DOCUMENTED | Equally valid trace backend; not used here for simplicity. |

## Adjacent agentic / secure-execution workloads

Not yet exercised in this lab (future work):

| Project | Status | Notes |
| :--- | :--- | :--- |
| nono | DOCUMENTED | Lightweight, unprivileged agent sandbox (Landlock on Linux, Seatbelt on macOS). No cluster of its own; composes into Kubernetes via the SIG **Agent Sandbox** project. |
| OpenShell | DOCUMENTED | Policy-enforced execution boundary: filesystem/network/process/credential controls. |
| Agent Substrate | DOCUMENTED | High-density actor/worker runtime with sub-second suspend/resume, built for large-scale agent deployment density. |
| gVisor | DOCUMENTED, newly accepted CNCF Sandbox | Userspace Linux implementation for container/agentic-workload sandboxing, a different isolation mechanism than the three above. |
