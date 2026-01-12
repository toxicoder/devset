---
layout: page
title: Operational Playbooks
permalink: /playbooks/
---

This section contains operational playbooks for common failure scenarios. These guides are designed to help on-call engineers quickly mitigate and resolve incidents.

## Core Playbooks

* **[High Latency](/playbooks/high_latency/)**: Investigating and mitigating high latency or latency spikes.
* **[High Error Rate](/playbooks/high_error_rate/)**: Handling elevated 5xx error rates.
* **[Database Failover](/playbooks/database_failover/)**: Procedures for primary database failure.
* **[Memory Leak / OOM](/playbooks/memory_leak_oom/)**: Diagnosing and mitigating OOM (Out of Memory) crashes.
* **[Disk Space Exhaustion](/playbooks/disk_space_exhaustion/)**: Clearing disk space and handling full volumes.
* **[Certificate Expiry](/playbooks/certificate_expiry/)**: Emergency rotation of expired certificates.
* **[Dependency Failure](/playbooks/dependency_failure/)**: Handling failures of third-party APIs.
* **[Bad Deployment](/playbooks/bad_deployment/)**: Rolling back bad deployments.

## How to Use These Playbooks

1.  **Assess Severity:** Determine the impact (SEV level) immediately.
2.  **Mitigate First:** Focus on restoring service before finding the root cause.
3.  **Follow the Steps:** Execute the investigation and mitigation steps in order.
4.  **Escalate:** If you are stuck or the SEV level increases, escalate to the appropriate subject matter expert.
