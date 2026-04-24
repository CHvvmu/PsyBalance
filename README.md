# PsyBalance


https://github.com/user-attachments/assets/415313b8-c93c-418b-88c4-4ce7ae036851    

https://github.com/user-attachments/assets/8d1f277e-b3f5-4ce5-be11-642e8a06e964




Initial Flutter project skeleton for MVP.

## Environment configuration

Flutter runtime uses only these Dart defines:

- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`

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

