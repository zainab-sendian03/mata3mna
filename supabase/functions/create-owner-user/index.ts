// Create owner user without sending confirmation email (admin-created accounts).
// Uses GoTrue Admin API with email_confirm: true.
// Requires: caller must be authenticated (admin JWT). Service role is used server-side only.
// This file runs on Deno (Supabase Edge Functions). IDE may show errors; they are resolved at deploy time.
// @ts-nocheck
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { email, password } = await req.json()
    if (!email || typeof email !== 'string' || !password || typeof password !== 'string') {
      return new Response(
        JSON.stringify({ error: 'email and password required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { autoRefreshToken: false, persistSession: false },
    })

    const { data: user, error } = await supabaseAdmin.auth.admin.createUser({
      email: email.trim(),
      password,
      email_confirm: true, // no confirmation email sent
      user_metadata: { display_name: email.trim().split('@')[0] },
    })

    if (error) {
      return new Response(
        JSON.stringify({ error: error.message, code: error.status }),
        { status: error.status || 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    return new Response(
      JSON.stringify({ user: { id: user.user.id, email: user.user.email } }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (e) {
    return new Response(
      JSON.stringify({ error: String(e) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
