# Use case: the enterprise multi-team LLM gateway

This is the real-world pattern this lab is built to validate, stated generically so it isn't tied to any one company's specific implementation.

## The problem

A company has many internal teams building LLM-powered features independently: customer support, content generation, internal process automation, and others. Each team integrates directly against one or more LLM vendors on its own. The result is duplicated integration work across teams, inconsistent handling of sensitive data, and no centralized visibility into who is spending what on inference.

This is the same failure mode this lab's companion talk opens with: a pilot succeeds, then becomes everyone's dependency, and the platform problem shows up once multiple teams depend on inference as shared infrastructure rather than something each team owns end to end.

## Why this requires every layer this lab tests

- **Gateway**: all teams need one stable, OpenAI-compatible entry point, so existing client code and tooling (LangChain-style SDKs, internal services in multiple languages) keep working regardless of which backend actually serves the request.
- **Schedule**: teams share finite capacity. One team's traffic spike shouldn't starve another's, and someone has to decide who gets admitted when capacity is tight.
- **Serve**: the gateway routes to a mix of backends, external vendor APIs for some use cases, self-hosted models for others, behind the same client-facing contract. Swapping or adding a backend shouldn't break any team's integration.
- **Observe**: centralized usage and cost attribution per team is a first-class requirement, not an afterthought. Finance and platform teams need to know what each team's usage actually costs, and operators need correlated data to tell whether a slowdown is routing, admission, or the model itself.

A production-scale deployment of exactly this pattern has been documented publicly: dozens of internal teams sharing one gateway, millions of requests per month, a request mix of chat generation, text generation, and embeddings, centralized usage/cost audit logging, and a PII-redaction layer sitting in front of external vendor calls to limit sensitive-data exposure. That confirms this is a real, common, validated pattern, not a convenient benchmark fiction. The exact figures used in this lab's workload defaults below are representative of that class of deployment, not an invented round number.

## The workload

Representative parameters for this pattern at a realistic (if modest) production scale:

- **Tenants**: on the order of 2-3 dozen internal teams sharing one gateway.
- **Request mix**: a combination of chat generation, text generation, and embeddings calls, not a single uniform request type.
- **Aggregate load**: tens of millions of requests per month in aggregate, with a peak in the tens of requests per second, well within what this lab's infrastructure should be able to sustain even on modest hardware.
- **Per-tenant tagging**: every request carries an identifier so usage and cost can be attributed back to the originating team, exactly what `x-llm-d-inference-fairness-id` already does in [`scripts/workloads/multi-tenant.sh`](../scripts/workloads/multi-tenant.sh).
- **A security pre-processing step**: real deployments of this pattern run PII redaction (or an equivalent data-handling policy) before requests leave the gateway for an external backend. This lab doesn't implement that step, but it's worth keeping in mind as a layer that sits between Gateway and Serve in a real deployment.

## Running it

`scripts/workloads/multi-tenant.sh` already implements the core shape (concurrent tenants, per-tenant header tagging). To approximate the request-mix and scale described above rather than the script's lab-practical defaults, run it with a higher tenant count and request volume tuned to your cluster's actual capacity:

```bash
TENANTS=10 REQUESTS_PER_TENANT=50 ./scripts/workloads/multi-tenant.sh
```

Extending the script to send a genuine mix of chat/text-generation/embeddings request bodies (rather than one request shape repeated) would make this a closer match to the real pattern, and is a reasonable next contribution to this lab.
