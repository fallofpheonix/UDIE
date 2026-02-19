# Contributing

## Branching
- Branch format: `feature/<short-name>` or `fix/<short-name>`
- Keep branch scope single-purpose.

## Commit Standard
- Use conventional style: `type(scope): summary`
- Example: `feat(auth): add token refresh path`

## Pull Request Checklist
- [ ] Requirements mapped
- [ ] Tests added/updated
- [ ] Security impact reviewed
- [ ] Performance impact reviewed
- [ ] Changelog updated

## Review Criteria
- Deterministic behavior
- Failure handling for external calls
- Clear rollback path for migrations
