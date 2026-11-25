# Postmortem: Chaos test on EKS (node failure caused a 7-minute prod outage)

**Date:** 26 Nov 2026 | **Environment:** portfolio-prod on EKS Auto Mode (gitops-eks, ap-south-1)
**Type:** Planned chaos test | **Severity:** High (full prod outage during test)

## Summary
A traffic probe (1 request/second to the prod ALB `/health`) ran while pods and a node were killed.
Killing one node caused **~7 minutes of full downtime**, even though prod runs 2 replicas.
After fixes, the same node kill caused **0 failed requests (0/179)**.

## Timeline (IST)
| Time | Event | Impact |
|---|---|---|
| 03:49:47 | Killed 1 of 2 prod pods | ~3 s errors (ALB still routed to the dying pod) |
| 03:50:26 | Killed all prod pods | ~13 s down (expected) |
| 03:50:50 | Deleted node `i-04b0744533b0d59cb` | **Outage starts**: 502/503 |
| ~03:51 | Replacement pods rejected: `failed calling webhook ... kyverno ... no endpoints available` | Pods cannot be created |
| ~03:51:30 | Kyverno back on the new node, but ReplicaSet in exponential retry backoff | Still down |
| 03:57:50 | Manual recovery: deleted the stuck ReplicaSet, Deployment recreated it | Pods start |
| 03:57:55 | Prod returns 200 | **Outage ends (~7 min 5 s)** |
| 04:11:42 | Retest after fixes: deleted node `i-02429b2a3fb501862` | **0 / 179 failures** |

## Root causes
1. **Both prod replicas on one node.** Two replicas on one machine is still a single point of failure.
2. **Kyverno admission controller: 1 replica, on the same node, fail-closed webhook.**
   With Kyverno gone, the API server rejected every new pod in `portfolio-*` namespaces.
3. **ReplicaSet backoff** delayed self-recovery after Kyverno returned.
4. **No graceful drain:** pods stopped instantly while the ALB still sent them traffic (the 3 s blip).

## What we tried that did not work
- `topologySpreadConstraints` (hostname, DoNotSchedule): only balances across **existing** nodes.
  With one node there is one domain, so skew = 0, both pods fit, nothing goes Pending, and Auto Mode never adds a node.

## Fixes (all in Git, deployed by ArgoCD)
| Fix | File |
|---|---|
| Required pod anti-affinity on hostname (2nd pod goes Pending, Auto Mode adds a node) | `gitops-manifests/charts/portfolio/templates/deployment.yaml` |
| PodDisruptionBudget minAvailable 1 | `charts/portfolio/templates/pdb.yaml` |
| preStop `sleep 15` + ALB `deregistration_delay=10s` | `deployment.yaml`, `ingress.yaml` |
| Kyverno admission controller: 2 replicas + required anti-affinity + PDB | `gitops-manifests/apps/platform-kyverno.yaml` |

## Result
Node kill after fixes: **0 failed requests out of 179**. Evidence: `docs/chaos-probe-before.log`, `docs/chaos-probe-after.log`.

## Lessons
- Replicas only help if they are on **different failure domains** (node, then AZ).
- Every **fail-closed admission webhook** is part of your critical path: run it HA, or it can block recovery.
- Chaos tests find dependencies you didn't know you had.

## Follow-ups
- Spread across **AZs** (`topology.kubernetes.io/zone`) as well as nodes.
- Alert on `FailedCreate` events / webhook errors.
- Persistent storage for Prometheus/Loki (they lost data with emptyDir when their node died).
