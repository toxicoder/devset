---
layout: page
title: Distributed Systems
permalink: /training/engineering/distributed_systems/
---

# Distributed Systems

## Course Overview
**Course Title:** Distributed Systems
**Level:** Intermediate/Advanced
**Format:** Self-paced Reading & Hands-on Labs

## Learning Objectives
*   Articulate the core principles of Distributed Systems.
*   Apply best practices to real-world engineering scenarios.
*   Troubleshoot common issues and optimize performance.

## Core Curriculum
## Overview
Understanding distributed systems is critical for building scalable, reliable applications at our scale.

## Core Concepts

### CAP Theorem
* **Consistency**: Every read receives the most recent write or an error.
* **Availability**: Every request receives a (non-error) response, without the guarantee that it contains the most recent write.
* **Partition Tolerance**: The system continues to operate despite an arbitrary number of messages being dropped (or delayed) by the network between nodes.

### PACELC Theorem
An extension of CAP that states in case of network partitioning (P) in a distributed computer system, one has to choose between availability (A) and consistency (C) (as per the CAP theorem), but else (E), even when the system is running normally in the absence of partitions, one has to choose between latency (L) and consistency (C).

## Sharding Strategies
* **Key-Based Sharding**: Distributing data based on a hash of a key.
* **Range-Based Sharding**: Distributing data based on ranges of key values.
* **Directory-Based Sharding**: Using a lookup table to find the shard.

## Consistency Models
* **Strong Consistency**: Sequential consistency.
* **Eventual Consistency**: If no new updates are made to a given data item, eventually all accesses to that item will return the last updated value.

## Hands-on Exercises
1.  **Review:** Read the core curriculum carefully.
2.  **Apply:** Identify one area in your current project where this applies.
3.  **Prototype:** Create a small proof-of-concept in your sandbox environment.

## Assessment
*   Complete the knowledge check in the Learning Management System (LMS).

## Resources
*   Internal Wiki
*   Official Documentation
