# AGENTS.md

This file provides guidance to AI coding agents working in this repository.
All paths in this document are relative to the repository root.

## Required reading

Before planning, reviewing, or modifying this project, read
[docs/GENERIC_RULES.md](docs/GENERIC_RULES.md) in full and apply it alongside
this file. The link is an explicit reading requirement; do not assume your
tool automatically imports linked Markdown files.

GENERIC_RULES.md contains reusable working rules. This file adds the project's
Flutter conventions and spec-driven workflow. For repository conventions,
project-specific rules refine the generic defaults. Neither file overrides
the user's explicit instructions or the agent's higher-priority instructions.
If documents conflict in a way that affects behavior or scope, clarify the
conflict before implementing the affected part.

## Project

Flutter application for **Dog Doctor**.

- **Core Objective:** A multi-pet allergy tracker that allows users to log symptoms (like itchiness levels) and visualize data through comparative charts.
- **User Management:** Includes authentication (Firebase Auth).
- **Data Persistence:** Integration with Firebase Storage for files/images and a Database service (SQL/NoSQL) for structured data.
- **Tech Stack:** Flutter, Dart, Firebase Suite (Auth, Storage, Firestore/SQL).
- **Methodology:** Spec-driven development (SDD).
- **Design Pattern:** Clean Architecture with Unidirectional UI Data Flow.

## Commands

Run commands from the repository root using the Flutter CLI.

```bash
flutter pub get                    # Get dependencies
flutter analyze                    # Analyze code for linting/static errors
flutter test                       # Run all tests
flutter test --test-flavour=dev    # Run specific flavor tests (if applicable)

# Build the app
flutter build apk                 # Build Android APK
flutter build ios                 # Build iOS package (requires macOS/Xcode)

# Run tests for a specific file
flutter test --test-only=path_to_file.dart
```

For code changes, run `flutter analyze`, `flutter test`, and verify that the build succeeds. For documentation-only changes, verify content and references without requiring a build or test run. Report any checks that could not run and the reason.

## Spec-driven workflow

### Reference documents

Each template carries its own instructions for the agent, its section structure, and its identifier scheme. Read the template in full and follow it; this file does not restate its content and must not contradict it.

- `docs/SPEC_TEMPLATE.md`: copy to the feature's `SPEC.md` when creating or
  updating a specification. It owns the spec's sections, the `RF-` requirement
  and `CA-` acceptance-criteria identifiers, and its approval states.
- `docs/PLAN_TEMPLATE.md`: copy to the feature's `PLAN.md` once the specification is approved. It owns the plan's section and approval states. Reference requirements and criteria by their spec identifiers.
- `docs/MOBILE_GUIDELINES.md`: consult when writing or reviewing requirements,
  acceptance criteria, the technical plan, and mobile validation. Consider
  lifecycle, state retention, connectivity, persistence, UI states, navigation
  interactions, forms, screen adaptation, accessibility, permissions,
  performance, background work, privacy, and internationalization. Apply only
  relevant items; clarify undefined product behavior instead of inventing it.

Preserve each template's structure and its embedded comments in the copy. Do not
rewrite the shared templates for an individual feature.

### Feature documents

Keep each feature's documents together:

- `docs/features/<feature-name>/SPEC.md`
- `docs/features/<feature-name>/PLAN.md`
- `docs/features/<feature-name>/TASKS.md`

Use an existing feature directory when continuing its work.

### Sequence

Each stage is gated by the previous document's state. A document is only
`Aprobada`/`Aprobado` when the user says so: a complete document is not
an approved one, and the agent never changes that state on its own.

1. **Specification:** complete `SPEC.md` from `docs/SPEC_TEMPLATE.md`,
   collaboratively and section by section, following the template's own
   instructions. Do not start the plan until the user approves the spec.
2. **Plan:** write `PLAN.md` from `docs/PLAN_TEMPLATE.md` for the approved
   specification, following the template's own instructions. Additionally,
  record whether subagents are needed and their bounded responsibilities; do
  not assume delegation is required or available. Do not start tasks until
  the user approves the plan.
3. **Tasks:** derive `TASKS.md` from the approved plan. There is no shared
  template for it, so this file defines it: small, ordered, verifiable
  checkboxes, each with an identifier, objective, scope, dependencies, the
  spec criteria it resolves, and its validation method. Keep tasks concise
  enough to execute and detailed enough to determine when they are done.
4. **Implementation:** execute the tasks within the agreed scope, preserving
  the architecture below. Authorization to implement must be explicit; it is
  not implied by the documents' state. Update task status as work progresses.
5. **Validation:** verify acceptance criteria with appropriate evidence and record the result in `TASKS.md`, including any outstanding checks.

Do not treat a filled template as resolution of unanswered questions. Ask
about missing product decisions that affect behavior. Resolve routine technical
details from the code and established conventions. Do not ask for renewed
permission for steps the user has already authorized.

If implementation reveals a requirement gap or contradiction, clarify the
affected behavior and update the relevant documents before continuing that
part. Keep the specification, plan, tasks, and resulting behavior consistent.

## Architecture

Clean Architecture with Unidirectional UI Data Flow. The project follows these layers:

| Path | Responsibility |
| --- | --- |
| `data/api/` | Remote data sources (Firebase Auth, Firebase Storage, SQL/Firestore API). |
| `data/repository_impl/` | Repository implementation: handles Auth, Storage operations and data fetching. |
| `data/local_datasource/` | Local storage logic (e.g., SQLite, Hive) if applicable for caching. |
| `domain/model/` | Plain Dart data classes representing business entities (Pet, AllergyLog). |
| `domain/repository_contract/` | Abstract repository definitions owned by the domain layer. |
| `domain/usecases/` | Business logic actions (e.g., `RegisterSymptomUseCase`, `UploadPetImage`). |
| `presentation/features/` | UI Logic and State Management (e.g., Bloc, Riverpod, or Provider). |
| `core/di/` | Dependency Injection setup (e.g., GetIt or constructor injection). |
| `core/navigation/` | Route definitions and navigation logic. |

### Layer dependencies

- `presentation -> domain` and `data -> domain`.
- Domain owns repository contracts and must not depend on presentation,
  data implementations, DTOs, or platform-specific APIs.
- Presentation accesses domain use cases and models, never data implementations
  or DTOs directly.
- Data implements domain contracts and maps external representations to domain
  models.

### Dependency Injection

- Use standard Dart/Flutter DI patterns (e.g., GetIt or constructor injection).
- Ensure clear separation between UI, Business Logic, and Data.

### Navigation

- Use standard Flutter navigation or a package like `go_router` for route management.
- Define clear, type-safe routes and centralize navigation flow in a dedicated router.

### UI State and Widgets

- Each screen/screen_view exposes its own state stream or provider.
- Use `StatefulWidget` or `StatelessWidget` appropriately with appropriate state management.
- Keep business logic and direct data access out of UI widgets.
- Ensure clear handling of loading, empty, content, and error states.

### Coroutines and Errors (Dart/Flutter)

- Use `Future` and `Stream` for asynchronous operations.
- Ensure proper error handling (e.g., using `Result` types or try/catch blocks).
- Do not block the UI thread; use asynchronous programming correctly.

### Theming

- Use a centralized Theme data structure for colors, typography, and component styles.
- Avoid hardcoded values in the UI layer; use theme variables provided by the design system.

### Networking / Data Sync

- Use `Dio` or `http` package for external requests.
- Integrate Firebase Auth and Storage SDKs correctly within the repository implementations.
- Map API/Database responses to Domain Models in the data layer.

## Completion report

Summarize the implemented behavior, the affected feature documents, and the
validation results. Link acceptance criteria to evidence in `TASKS.md`.
Clearly identify anything incomplete or unverified; do not present a test name,
an unexecuted command, or "should work" as proof of success.