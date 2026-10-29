# Gotchas and verified corrections

Things this lab found by actually running the stack, not by reading docs. Environment: `kind` v0.31.0 against `podman` v5.8.3 via `KIND_EXPERIMENTAL_PROVIDER=podman` (no Docker CLI on the build machine). Versions used are pinned in the Makefile/scripts.

## Verified end-to-end (not just "pods are Running")

- **Gateway**: `Gateway` → `Accepted=True`, `Programmed=True`. `GatewayClass/agentgateway` → `ACCEPTED=True`.
- **Schedule (Kueue admission loop only)**: `ClusterQueue` → `Active=True, Reason=Ready, "Can admit new workloads"`. Confirmed it is never touched by the request-routing path below, which is correct, since admission and request routing are separate control loops (see [ARCHITECTURE.md](ARCHITECTURE.md)).
- **Serve**: `InferencePool` → `Accepted=True`, `ResolvedRefs=True`. `HTTPRoute` → `Accepted=True`, `ResolvedRefs=True`, bound to the Gateway. A live request through the full chain (client → port-forwarded Gateway → EPP → simulator pod) returned HTTP 200 with a real OpenAI-style completion body.
- **Observe (gateway/EPP side)**: sent one request with a hand-crafted W3C `traceparent` header carrying a known trace ID. That exact trace ID appeared in the trace backend with **10 correctly nested spans** (`request` → `request_orchestration` → `tokenize` / `run_scheduler_profile` → `scoring` → per-scorer plugin spans → `filter_endpoints` → `pick_endpoints`), all `CHILD_OF`-linked back to the externally supplied parent span ID.

## Corrections to the obvious/documented path

1. **llm-d's `main` branch dropped `kgateway`** from its list of supported gateway providers entirely. The current supported list is Istio, GKE Gateway, **agentgateway**, Envoy AI Gateway, and NGINX Gateway Fabric. This lab uses **agentgateway**, which worked cleanly. Its own Helm chart's post-install notes point to `kgateway.dev/docs`, confirming agentgateway is maintained under the kgateway project as its AI-gateway-focused component, not a separate, competing project. **Re-check this before relying on it; this ecosystem moves fast.**

2. **`llm-d-inference-sim` defaults to a real HuggingFace model name** in its own example manifest, which triggers a `vllm-render` tokenizer sidecar requiring real network/HF access, defeating the point of a no-GPU, no-network lab. **Use an explicit dummy/non-existent model name** (e.g. `--model lab-dummy-model`) to get the simulator's actual "Simulated Mode" with zero external dependencies.

3. **Setting `router.tracing.otelExporterEndpoint` and `.sampling` alone does not enable tracing.** `router.tracing.enabled=true` must be set explicitly, confirmed by inspecting the EPP pod's actual launch args, which still showed `--tracing=false` without it.

4. **The router chart's real default sampling is 10%** (`parentbased_traceidratio`, `samplerArg: "0.1"`), not the 5% some older references suggest. Override to `"1.0"` for lab/demo purposes or you'll intermittently fail to find your test trace.

5. **`llm-d-inference-sim` has zero OpenTelemetry/tracing support.** No `--otlp-traces-endpoint` flag or any OTel integration exists in the simulator, confirmed by inspecting its full config reference. This is a **structural limitation**, not a bug in this lab: the GPU-free serve path can prove gateway+EPP-side trace correlation, but it cannot prove serve-layer span emission. Closing that gap requires a real vLLM instance (see `docs/ALTERNATIVES.md`).

## Open issue (not yet resolved)

**The EPP's root `request` span reports `error=True, status=ModelServerError` even on a fully successful request** (client got a correct HTTP 200 with valid output). The likely cause is the EPP attempting to scrape vLLM-style Prometheus metrics (`vllm:num_requests_waiting`, etc.) from the simulator, which may not expose them in the exact expected format. The request itself works correctly; it's a telemetry/status-reporting quirk, not a functional failure. It does mean the EPP/simulator pairing isn't "clean" yet from an observability standpoint. Worth investigating before treating this combination as a reference example of healthy tracing.

If you find the root cause, a PR to this repo (or upstream to `llm-d-inference-sim` / the router chart) would be genuinely useful; this wasn't tracked down further here due to time.

## More verified findings (second pass)

6. **A `podman machine` stop/start cycle can leave the VM clock skewed from the host.** Resizing CPU/memory on an existing `podman machine` requires stopping and restarting it; after that cycle, the VM clock was found about two minutes behind the host, enough to break JWT-based session validation in a tool (OpenShell) that checks token issue time strictly. Forcing a time sync inside the VM fixed it immediately. Worth checking after any machine resize or host sleep/wake, independent of what you're actually testing.

7. **The individual `runsc`/`containerd-shim-runsc-v1` binary downloads from gVisor's release URL return 404.** Only the bundled `gvisor.tar.zstd`/`gvisor.tar.bz2` archives are currently published at that path, contrary to what some install guides suggest; download the archive, not the individual binaries.

8. **Two unrelated CNCF-adjacent agentic projects (nono's example, Agent Substrate's own dev setup) both hardcode Docker CLI commands directly**, with no podman equivalent path in either. A real, recurring portability gap in this class of tooling, not a one-off.

## What this lab has now actually verified vs. what's still open

Verified with real evidence in this pass: Envoy AI Gateway (a third gateway against the same `InferencePool`), OpenShell (real sandbox exec, after the clock-skew fix above), gVisor (a pod actually running under its sandboxed kernel).

Still not attempted:

- KServe + real vLLM (the alternative serving path that would close the serve-layer tracing gap; blocked here by an arm64 image gap, see `ALTERNATIVES.md`)
- HAMi (needs real GPU hardware)
- Praxis as a gateway alternate (checked and found not to support the Gateway API Inference Extension pattern yet, see `ALTERNATIVES.md`)
- nono, Agent Substrate (blocked by the Docker-CLI coupling in finding 8 above, not attempted further)

See `docs/ALTERNATIVES.md` for the full per-layer status.

## Docker verification pass (third pass)

The core path (Gateway, Schedule, Serve, Observe) was re-verified end to end under Docker (via colima, a CLI-only Docker-compatible runtime) on a separate `kind` cluster, confirming it isn't podman-specific. Same acceptance tests, same real results: `Gateway` `Programmed=True`, `InferencePool` `Accepted`/`ResolvedRefs=True`, a real HTTP 200 through the full path, and a 10-span trace in Jaeger with identical structure (same operation names, same parent/child nesting) to the podman run.

Two genuine bugs in this lab's own checked-in setup surfaced along the way, independent of podman vs. Docker:

9. **`manifests/schedule/kueue-setup.yaml` used the `kueue.x-k8s.io/v1beta1` API version, which Kueue v0.20.0 no longer serves** (the CRD lists `v1beta1` with `served: false`; only `v1beta2` is actually usable). This means the manifest as checked into this repo would fail for anyone cloning it fresh today, independent of which runtime they use. Fixed in place to `v1beta2`.

10. **llm-d's own router chart (`base.values.yaml`) defaults `router.epp.resources` and `router.proxy.resources` to 4 CPU / 8Gi each**, a production-sized default that needs an 8+ CPU / 16+ GB node just to schedule the router pod. This isn't something either runtime caused; it's the upstream chart's own default, sized for real deployments rather than a laptop-scale lab. `scripts/04-serve.sh` now overrides these down to 250m CPU / 256Mi for the EPP and 100m CPU / 128Mi for the sidecar proxy; without that override, the EPP pod sits `Pending` indefinitely on a typical lab-sized node.

11. **Both podman machine and colima showed a gap between requested and actually-usable disk size.** Podman's version of this (resizing the virtual disk file without growing the guest partition) is documented above. Colima, configured with `--disk 40`, showed `df -h /` inside the VM reporting only ~19G total; the underlying cause wasn't investigated further here, but the symptom (configured size does not equal usable size) is the same pattern on a second, independent VM-based runtime.
