# flutter_application_1

## Waiting Room setup

The app uses one shared waiting queue. Offline registrations are saved locally
with a pending status and are not shown as official queue entries until
Supabase assigns a queue number. Location is optional. Precise coordinates are
stored for synchronization but omitted from queue reads and Realtime messages.

### Supabase database setup

1. Open the project's Supabase Dashboard and select **SQL Editor**.
2. Select **New query**.
3. If not already applied, run `supabase/migrations/202611230002_resilient_queue.sql`.
4. Run `supabase/migrations/202611230003_user_approval_and_admin.sql`.
5. Confirm `public.clients.id` is `uuid`. The account migration creates
   `public.profiles`, account approval and role controls, and admin-only queue
   deletion/call-next functions. Anonymous queue access is disabled.
6. Run `supabase/migrations/202611230004_admin_signup_allowlist.sql` if it has
   not already been applied, then run
   `supabase/migrations/202611230005_username_accounts.sql`. In **Authentication
   → Providers → Email**, disable email confirmations: the app asks for a
   username and password, and does not ask users for an email address.
7. To pre-authorize an administrator before signup, add the trusted username
   in Supabase SQL Editor before that account is created:

   ```sql
   insert into public.admin_signup_allowlist (username)
   values (lower('admin_username'));
   ```

   The signup trigger consumes this one-time allowlist entry and creates an
   approved admin profile. If an account already exists as pending, promote
   its profile once in SQL by username:

   ```sql
   update public.profiles
   set role = 'admin', approved = true, rejected = false
   where lower(username) = lower('admin_username');
   ```

   For an account created before username login was added, its profile username
   is backfilled from the email's first part. In **Authentication → Users**, set
   its internal Auth email to `<username>@waiting-room.invalid`; its password
   remains the one already chosen. Users do not enter or see this address in
   the app. Sign out and sign back in after applying database changes. Admins
   can approve/decline accounts, assign `user` or `admin` roles, remove queue
   entries, and call the next client. Regular users can join after approval.

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
