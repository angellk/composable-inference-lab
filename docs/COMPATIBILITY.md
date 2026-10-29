# Compatibility

This lab aims to work regardless of host CPU architecture or container runtime. The table below states what's actually been verified, not what's assumed to work. Where something is "assumed," that's stated explicitly so you know where to look if it breaks.

## CPU architecture (amd64 / arm64)

Checked via registry manifest inspection (querying each image's manifest list directly, not by trial and error), so this reflects what the published images actually support, independent of whether this lab has run on both architectures itself.

| Component | Image | amd64 | arm64 | Notes |
| :--- | :--- | :---: | :---: | :--- |
| llm-d-inference-sim | `ghcr.io/llm-d/llm-d-inference-sim` | yes | yes | Confirmed multi-arch. |
| Jaeger (all-in-one) | `jaegertracing/all-in-one` | yes | yes | Also publishes s390x and ppc64le. |
| Kueue | `registry.k8s.io/kueue/kueue` | yes | yes | Also publishes s390x and ppc64le. |
| Istio (pilot) | `istio/pilot` | yes | yes | Confirmed multi-arch. |
| vLLM (upstream) | `vllm/vllm-openai` | yes | yes | The engine itself is multi-arch, see the KServe note below. |
| KServe HuggingFace runtime | `kserve/huggingfaceserver:v0.20.0` | yes | **no** | Confirmed blocker: no arm64 manifest published. This is KServe's own wrapper image, not vLLM itself, see the workaround below. |
| agentgateway, Volcano, KAI Scheduler, gVisor | various | assumed | assumed | Not independently checked via manifest inspection; these are modern cloud-native projects where multi-arch publishing is standard practice, but that's an assumption, not a verification. |

### Workaround for the KServe arm64 blocker

Since `vllm/vllm-openai` itself is multi-arch, running vLLM directly (bypassing KServe's `InferenceService` wrapper entirely) is a real-vLLM path that works on arm64:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: vllm-direct
  namespace: inference-lab
spec:
  replicas: 1
  selector:
    matchLabels:
      app: vllm-direct
  template:
    metadata:
      labels:
        app: vllm-direct
    spec:
      containers:
      - name: vllm
        image: vllm/vllm-openai:latest
        args:
          - "--model=Qwen/Qwen2.5-0.5B-Instruct"
          - "--device=cpu"
          - "--max-model-len=2048"
        ports:
        - containerPort: 8000
```

This loses the things KServe's `InferenceService` wrapper adds (standardized CRD, autoscaling integration, model storage abstraction), but it's a genuine real-vLLM path for arm64 hosts rather than waiting on an upstream fix. Not independently run end to end as part of this pass; the approach and flags are documented, but verify it in your own environment before relying on it.

## Container runtime (podman / Docker)

The full core path (Gateway, Schedule, Serve, Observe) has been verified on both:

| Runtime | Verified | Notes |
| :--- | :---: | :--- |
| podman (via `kind`'s experimental podman provider) | yes | The primary environment this lab was built and tested against. |
| Docker (via colima, a CLI-only Docker-compatible runtime, no Docker Desktop needed) | yes | Same core-path acceptance tests passed: `Gateway` `Programmed=True`, `InferencePool` `Accepted`/`ResolvedRefs=True`, a real request returning HTTP 200, and a correctly nested 10-span trace in Jaeger matching the podman run exactly. |

Two things differed between the runtimes while getting there, worth knowing:

- llm-d's router chart defaults (`router.epp.resources` and `router.proxy.resources` in its `base.values.yaml`) request 4 CPU and 8Gi each, a production-sized default that didn't fit on a leaner 4 CPU/8GB test VM. `scripts/04-serve.sh` overrides these down to lab-appropriate values; if you're following upstream docs directly instead of this lab's scripts, you'll likely hit the same `Pending` pod until you override them too.
- Both podman machine and colima showed a gap between the disk size you ask for and the disk size actually usable inside the VM (see `FINDINGS.md` for the podman-specific version of this; colima's showed a similar mismatch for a possibly different underlying reason). If you hit `no space left on device` on either runtime, check `df -h` inside the VM before assuming the resize command alone was enough.

The setup scripts auto-detect which runtime is present (see `CONTAINER_RUNTIME` below) rather than assuming one specifically.

## Host OS

- **macOS**: needs a VM layer for either runtime, podman machine or colima. `scripts/00-prereqs.sh` detects macOS and gives the right guidance for whichever runtime it finds (or installs colima if neither is present and Docker-style tooling is preferred).
- **Linux**: neither runtime needs a VM layer; both podman and Docker run natively. The scripts skip the VM-setup step entirely on Linux.
- **Windows**: not tested in this lab. WSL2 with either runtime should behave like the Linux path from inside the WSL2 environment, but this hasn't been verified here.

Set `CONTAINER_RUNTIME=docker` or `CONTAINER_RUNTIME=podman` to force a choice; otherwise the scripts prefer whichever is already running.

## Accelerator vendor diversity

CPU architecture and host OS are a different axis from accelerator vendor (NVIDIA, AMD, Intel). This lab's GPU-dependent pieces (HAMi, the real serving path) assume NVIDIA on x86_64, which is a real and separate limitation, not something this lab attempts to solve. If you're specifically interested in heterogeneous accelerator vendor support, llm-d's own benchmark across three GPU vendors is the place to look: [Heterogeneous inference serving across three GPU vendors with llm-d](https://llm-d.ai/blog/heterogeneous-inference-3-vendor-sovereign-cluster).
