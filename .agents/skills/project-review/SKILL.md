---
name: project-review
description: Independently review a task diff for concrete defects without relying on builder reasoning.
---
# Review
Inspect locked task, rules, exact diff/source, and test/CI evidence. Check scope, correctness, ownership/IDOR, SSRF/network safety when relevant, framework compatibility, DB/performance, jobs/retry behavior, and meaningful tests. Return APPROVE, REJECT, or NEEDS_HUMAN with evidence.
