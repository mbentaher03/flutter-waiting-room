# flutter_application_1

## Workshop 6 setup

The app uses one shared waiting queue. Offline registrations are saved locally
with a pending status and are not shown as official queue entries until
Supabase assigns a queue number. Location is optional. Precise coordinates are
stored for synchronization but omitted from queue reads and Realtime messages.

### Supabase database setup

1. Open the project's Supabase Dashboard and select **SQL Editor**.
2. Select **New query**.
3. Open `supabase/migrations/202611230002_resilient_queue.sql` in this project,
   copy the full contents into the SQL Editor, and run it.
4. Confirm `public.clients.id` is `uuid`, plus the location, `queue_number`,
   and timestamp columns added by the migration. Flutter represents UUIDs as
   strings and PostgREST passes them to the RPC's UUID parameter.
5. Restart the Flutter app. The migration adds a registration RPC, queue-number
   sequence, safe public-field grants, and a Realtime trigger that broadcasts
   only queue fields.

Do not paste a Supabase `service_role` key into the Flutter app. The app uses
the public/anon key from `.env`; the registration RPC is the write boundary.

### Local development

```sh
flutter pub get
flutter analyze
flutter test
flutter run -d chrome
```

For team collaboration, branch from the shared main branch, use separate
feature branches for connectivity/storage and queue/realtime work, open pull
requests for review, then run the full test suite on the integrated branch.

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
