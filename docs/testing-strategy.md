# Testing Strategy

- **Goal** Fast feedback with enough coverage to block regressions.
- **Pyramid** Unit > widget > integration; run E2E only for smoke checks.
- **Focus Areas** Services/blocs, helper parsing, navigation + gallery/file flows.
- **Tooling** `flutter test`, `mocktail` (mocks), goldens only for critical visuals.
- **Fixtures** Keep deterministic; prefer fakes over live network/storage.
- **CI** Run unit + widget tests on every PR; schedule heavier suites nightly.
- **Coverage** Minimum 70%, improve as modules stabilize.
- **Structure** Mirror `lib/` under `test/`, name files `<target>_test.dart`.
- **Non-Functional** Track performance on heavy lists/streams and verify retry/backoff logic.
