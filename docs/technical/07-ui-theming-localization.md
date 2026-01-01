## UI Standards & Theming

- **Minimal Theme** Import `config/app_theme.dart` / `MinimalTheme` helpers; never hardcode colors or spacing.
- **Design Rules** See `docs/coding-rules/theme-styling-guide.md` for spacing (`spacing(4/8/12/16/20/24)`), radii (`radius(16/20/24/28)`), icon sizes (`icons(18/22/24)`), and flat design philosophy (avoid borders, prefer subtle shadows and opacity).
- **Builders** Use shared factories like `buildIconButton()` and `buildCloseButton()`; line icons only (`*_line`).
- **Mobile Galleries** `ui/screens/media_gallery/` follow flat cards (no elevation) and reuse `MobileFileActionsController` for top action bars.

## Localization (Mandatory)

- **Rule** All user-facing strings must go through i18n keys.
- **Implementation** Import `config/languages/app_localizations.dart` or call `context.tr.keyName`.
- **Adding Keys** Update `config/languages/app_localizations.dart`, `config/languages/english_localizations.dart`, and `config/languages/vietnamese_localizations.dart` in tandem.
- **Reference** `docs/coding-rules/i18n-internationalization-guide.md` documents the workflow.

_Last reviewed: 2025-10-25_
