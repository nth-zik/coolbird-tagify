# Coding Standards

- **Language & Style** Follow Effective Dart; embrace null safety; keep functions focused; name things clearly.
- **Structure** Mirror existing layouts: BLoCs in `lib/bloc/`, config in `lib/config/`, helpers in `lib/helpers/`, UI by feature under `lib/ui/`.
- **Widgets** Keep widgets side-effect free, lift logic to blocs, extract reusable pieces into `ui/components/`, obey theme + spacing tokens.
- **Errors** Throw specific exceptions, surface friendly messages, never swallow failures silently.
- **Async** Prefer `async`/`await`, close streams/controllers, guard isolates.
- **Testing** Add unit/widget coverage for touched code paths; create goldens only for critical visuals.
- **Linting** Fix all `analysis_options.yaml` warnings before merging.
- **Commits** Use Conventional Commit prefixes.
- **Docs** Update public `///` docs and relevant files in `docs/` as features evolve.
