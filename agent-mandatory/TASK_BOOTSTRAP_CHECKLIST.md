# Task Bootstrap Checklist (Mandatory)

## A. Context Integrity
- [ ] Confirm current working directory is repository root.
- [ ] Capture current branch and dirty state (`git status --short`).
- [ ] Identify whether runtime environment is local process, Docker, simulator, or physical device.

## B. API/Backend Reality Check
- [ ] Determine active API namespace by probing both:
  - `/api/health`
  - `/api/v1/health`
- [ ] Verify endpoint contract with valid parameters (not empty/default curls for required query fields).
- [ ] Confirm backend process/container logs include mapped routes.

## C. Failure Classification
- [ ] Transport failure (DNS/TCP/connect timeout)?
- [ ] HTTP contract failure (`400`, `404`, `422`)?
- [ ] Backend execution failure (`500`, worker errors, DB trigger violations)?
- [ ] State-management/UI reporting defect?

## D. Change Safety
- [ ] Prefer minimal targeted fix over broad refactor.
- [ ] Preserve existing unrelated changes.
- [ ] Verify changed code path with at least one reproducible command per fix axis.

## E. Reporting
- [ ] Report root cause(s) and evidence lines.
- [ ] Report what was changed (file-level).
- [ ] Report what was not verified.
