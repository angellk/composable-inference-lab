# Threat model

This is a lightweight threat model scoped to **running this lab on a local machine**, not an enterprise deployment guide. The point is modeling the habit of thinking about this before standing up infrastructure, proportionate to what this actually is, not padded for its own sake.

## What this lab is (and isn't) exposed to

By default, everything in this lab runs on a local `kind` cluster with no external ingress. The risks below mostly show up when someone deviates from that default, which is common, since the natural next step after a local lab is "let me show this to someone" or "let me point a real client at it."

## Risks and mitigations

| Risk | How it could happen | Mitigation |
| :--- | :--- | :--- |
| **Unauthenticated public OTLP endpoint** | Exposing the Jaeger/OTel collector Service via a `LoadBalancer`, `NodePort`, or port-forward bound to `0.0.0.0` instead of `localhost`. Anyone who finds it can both read your traces and inject fake spans. | Keep observability endpoints on `ClusterIP` (as shipped in `manifests/observe/jaeger.yaml`). If you need external access, put it behind the same gateway/auth boundary as everything else, not a raw exposed port. |
| **Secrets or kubeconfig committed to git** | Pasting a real HuggingFace token, cloud credential, or your live `~/.kube/config` into a manifest or script while debugging, then committing it. | `.gitignore` excludes common secret/kubeconfig patterns. Review `git diff` before committing, especially after a debugging session. If you ever do commit a secret, rotate it; don't just remove it from a later commit (git history keeps it). |
| **Untrusted model/container images** | Pulling an arbitrary model or container image from an unverified source and running it inside the cluster with default (often permissive) pod security settings. | This lab only pulls from the upstream project registries named in the manifests (`ghcr.io/llm-d/*`, `jaegertracing/*`, official Helm chart OCI registries). If you swap in a different model or image, check its provenance first. |
| **Gateway/EPP header spoofing** | The llm-d header contract (`x-llm-d-inference-objective`, `x-llm-d-slo-ttft-ms`, `x-llm-d-inference-fairness-id`) is just request headers; nothing stops a client from setting its own priority/fairness values unless the gateway strips and re-injects trusted copies. | If you extend this lab to demo fairness or priority, strip externally supplied copies of these headers at the gateway and inject trusted values server-side. Documented in `docs/ARCHITECTURE.md`. |
| **Podman machine / kind cluster left running with broad resource grants** | The setup scripts resize a podman VM to 4 CPU/8GB RAM/40GB disk and leave it running after the lab for convenience. On a shared or sensitive machine, that's more persistent attack surface than necessary. | Run `make clean` (or `scripts/cleanup.sh`) when you're done with a session instead of leaving the cluster up indefinitely. |
| **Load-testing traffic mistaken for a real attack, or used as one** | The scripts in `scripts/06-loadtest.sh` and `docs/WORKLOADS.md` generate concurrent/bursty traffic patterns. Pointed at anything other than your own local lab endpoint, this is indistinguishable from an availability attack. | Only ever point these scripts at the `localhost`-forwarded lab endpoint. Don't repurpose them against a shared, staging, or production endpoint without explicit authorization from whoever owns it. |

## What's out of scope here

This threat model does not cover: multi-tenant cluster isolation, supply-chain verification of every transitive Helm chart dependency, or production-grade secrets management (Vault, sealed-secrets, etc.). Those are real concerns for a production deployment of this stack, but they're a different document from "what should I watch out for running a demo lab on my laptop."
