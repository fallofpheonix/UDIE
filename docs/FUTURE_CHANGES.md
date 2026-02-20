# Future Changes

Upcoming refactors aimed at improving system stability and developer experience.

## Planned Refactors
- **Dependency Injection**: Move from `APIClient.shared` singleton to formal DI in `MapViewModel` for better testability.
- **Error Types**: Transition from string-based error messages to a strongly typed `AppError` enum across the iOS app.
- **Migrations**: Keep SQL-first migrations; add a deterministic migration validation job in CI (no ORM abstraction).

## Structural Improvements
- **Feature Folders**: Re-organize the `UDIE` folder into more granular feature-based modules (e.g., `Features/Onboarding`, `Features/Settings`).
- **Protocols**: Introduce `Repository` protocols to allow easy mocking of the data layer during unit tests.
