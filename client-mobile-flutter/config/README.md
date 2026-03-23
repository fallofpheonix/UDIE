# Runtime Configuration

Build-time define files:

- `dev.local.json`
- `staging.json`
- `prod.json`

Examples:

```sh
flutter run -d RZCW50EK3NV --dart-define-from-file=config/dev.local.json
flutter run -d 00008110-00180DCA2E8A401E --dart-define-from-file=config/dev.local.json
flutter build apk --dart-define-from-file=config/staging.json
```

`UDIE_BASE_URL` is the authoritative override for direct API targeting.

`UDIE_CONFIG_URL` points at hosted runtime config JSON. If remote fetch fails, the app falls back to:

1. cached runtime config
2. compile-time/default config
