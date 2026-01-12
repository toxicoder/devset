---
layout: page
title: Incident Response Simulation
permalink: /training/engineering/incident_response_simulation/
---

# Incident Response Simulation: "Wheel of Misfortune"

## Overview
The Wheel of Misfortune is a role-playing game used to train engineers on incident response.

## Objectives
* Practice debugging under pressure.
* Understand the incident management process.
* Improve communication during outages.

## How to Play
1.  **Game Master**: Sets up a scenario based on a past or theoretical incident.
2.  **On-Call Engineer**: The primary player who must diagnose and resolve the issue.
3.  **Scribe**: Records the timeline and actions taken.
4.  **Communication Lead**: Simulates external communication updates.

## Scenarios

### Scenario 1: The Cascading Failure
**Symptom**: Latency spikes on Service A.
**Root Cause**: Retry storm from Service B due to a temporary network blip.
**Resolution**: Implement exponential backoff and circuit breakers.

### Scenario 2: The Bad Config Push
**Symptom**: Service C is returning 500 errors immediately after a deployment.
**Root Cause**: Invalid YAML configuration file.
**Resolution**: Rollback to the previous version and validate config in CI/CD.
