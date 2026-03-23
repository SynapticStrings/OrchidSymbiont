# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.1]

*Refactored Session ID to support Binary (Strings). Resolved Atom exhaustion vulnerabilities and implemented a unified global registry with compound keys for robust multi-tenancy.*

## [0.2.0] - 2026-01-04

### Added
- **Session Isolation (Multi-Tenancy)**: Introduced the ability to run completely isolated sandboxes of Symbiont processes using `session_id`. Perfect for concurrent workflows or multi-tenant SaaS architectures without PID conflicts.
- **Dynamic Supervision Trees**: `Orchid.Symbiont.Runtime` can now be started multiple times under different namespaces by passing `[session_id: :your_session_name]`. Each session gets its own isolated `Registry`, `DynamicSupervisor`, `Catalog`, and `Preloader`.
- **Smart Catalog Fallback**: Added a hierarchical lookup mechanism in `Orchid.Symbiont.Catalog`. If a blueprint is not found in a session-specific catalog, it will automatically fall back to the global catalog. *(Write blueprints once globally, run instances locally!)*
- **New Naming Module**: Added `Orchid.Symbiont.Naming` to handle dynamic process registration routing transparently.

### Changed
- **Injector Hook Upgraded**: `Orchid.Symbiont.Hooks.Injector` now automatically extracts `:session_id` from the `Orchid.WorkflowCtx` baggage and routes the process resolution to the corresponding session's registry.
- **API Enhancements**: `Orchid.Symbiont.register` and `Orchid.Symbiont.Resolver.resolve` now accept an optional `session_id` parameter. *(Fully backward compatible with global singleton usage)*.
- **Dependencies Bump**: Updated `orchid` to `0.5.6`, `telemetry` to `1.4.1`, and `ex_doc` to `0.40.1`.

## [0.1.4] - 2026-01-03

### Added
- **Global Mapping Support**: `Orchid.Symbiont.Hooks.Injector` now supports resolving symbiont aliases from the `Orchid.WorkflowCtx` baggage. 
- **Hierarchical Resolution**: Symbiont mappings are now merged from two levels:
    1. **Global**: Set via `Orchid.WorkflowCtx.put_baggage(ctx, :symbiont_mapper, [...])`.
    2. **Local**: Set via `step_opts`. 
    *Note: Local step-specific mappings will override global mappings if both define the same logical name.*

### Fixed
- Internal `get_headers` logic in the Injector hook to properly handle the workflow context.

## [0.1.3] - 2026-01-02

### Changed
- **Breaking**: Renamed `Orchid.Symbiont.Step.get_required/0` with old name called `get_step_required_mapper/0` for shorter and cleaner API usage.
- `Orchid.Symbiont.call/3` now uses `apply/3` for dynamic module invocation.

### Added
- `Orchid.Symbiont.preload/1` now accepts a single symbiont name in addition to a list of names.

## [0.1.2] - 2026-01-02

### Dependencies

- update orchid's version to `0.5`

## [0.1.1] - 2025-12-27

### Dependencies

- use a looser version constraint for better compatibility with future patch releases

## [0.1.0] - 2025-12-26

### Added

- **Initial Release**: Launched `OrchidSymbiont` as the official process management extension for the [Orchid](https://hex.pm/packages/orchid) workflow engine.
- **Lazy Loading**: Introduced a mechanism to start GenServers (Symbionts) only when requested by a workflow step, optimizing resource usage for heavy tasks (e.g., ML models, DB connections).
- **Dependency Injection**: Added `Orchid.Symbiont.Hooks.Injector` to automatically resolve and inject running process references (PIDs) into Steps implementing the `Orchid.Symbiont.Step` behavior.
- **Lifecycle Management (TTL)**:
  - Implemented an `Idle Shutdown` mechanism using a transparent Wrapper/Proxy pattern.
  - Workers configured with a `:ttl` option will automatically terminate after a period of inactivity to free up resources.
  - The Wrapper ensures request forwarding is transparent and handles timeouts (`:infinity` internally) correctly to support long-running tasks.
- **Registry & Catalog**:
  - `Orchid.Symbiont.register/2`: API to define blueprints for services, supporting both standard startup and TTL-enabled modes.
  - Built-in `Registry` for name resolution and idempotency check (preventing duplicate startups).
- **Integration**:
  - Provides `Orchid.Symbiont.Step` behavior requiring `required/0` (dependencies) and `run_with_model/3` (execution logic).
  - Added helper `Orchid.Symbiont.call/3` for ergonomic synchronous communication with Symbionts.

### Dependencies

- Requires **Orchid ~> 0.4.0** (utilizes the new Context and Hook architecture).
