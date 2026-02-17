# Supabase Edge Functions

## create-owner-user

Creates an owner user **without sending a confirmation email**. Used when an admin creates a restaurant from the dashboard.

- **Mobile app signup** still uses normal `signUp()` and Supabase will send confirmation email if "Confirm email" is enabled.
- **Admin-created owners** are created via this function with `email_confirm: true`, so no email is sent.

### Deploy

From the project root (where `supabase/` is):

```bash
# Install Supabase CLI if needed: npm i -g supabase
supabase login
supabase link --project-ref YOUR_PROJECT_REF
supabase functions deploy create-owner-user
```

Or deploy from Supabase Dashboard: Project → Edge Functions → New function → paste the code from `create-owner-user/index.ts`.

### Security

The function uses `SUPABASE_SERVICE_ROLE_KEY` (set automatically by Supabase) to call the Auth Admin API. Only call this function from the **admin dashboard**; the dashboard should already be protected by admin login.
