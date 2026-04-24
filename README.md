# PsyBalance


https://github.com/user-attachments/assets/415313b8-c93c-418b-88c4-4ce7ae036851


Initial Flutter project skeleton for MVP.

## Environment configuration

Flutter runtime uses only these Dart defines:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

`SUPABASE_SERVICE_ROLE_KEY` must never be used in Flutter runtime.

## Run (dev)

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## Run (prod profile)

```bash
flutter run --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## Build APK (prod)

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key>
```

## Validation behavior

`AppConfig.validate()` runs on startup and throws if a required variable is missing.

