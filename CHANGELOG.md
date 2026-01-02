# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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