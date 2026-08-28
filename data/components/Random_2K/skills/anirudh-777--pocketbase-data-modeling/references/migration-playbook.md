# Migration Playbook

1. Additive phase:
- Add new fields/collections while keeping old reads valid.

2. Backfill phase:
- Run one-time data transform scripts.
- Monitor record-level failures and retry strategy.

3. Cutover phase:
- Switch app reads/writes to new fields.
- Keep compatibility fallback during rollout window.

4. Cleanup phase:
- Remove deprecated fields after stable period.
- Update docs and tests.
