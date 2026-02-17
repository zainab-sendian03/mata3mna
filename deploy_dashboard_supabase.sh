#!/usr/bin/env bash
# Build and deploy Admin Dashboard to Supabase Storage
# After running, set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY then run:
#   cd scripts && npm install && node upload_dashboard_to_supabase.cjs

set -e
BASE_HREF="/storage/v1/object/public/dashboard/"

echo "Building Flutter web (Admin Dashboard)..."
flutter build web --release -t lib/main_dashboard.dart --base-href "$BASE_HREF"

echo ""
echo "Build succeeded. To upload to Supabase Storage:"
echo "  1. export SUPABASE_URL=\"https://eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1emZjd3Fta3VscXR0bWdwd3FuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyMjAyOTcsImV4cCI6MjA3OTc5NjI5N30.ZK3gt-h7vbvyixnmsm2LS-hG3kUOErlNMd_m5orFxXs.supabase.co\""
echo "  2. export SUPABASE_SERVICE_ROLE_KEY=\"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZ1emZjd3Fta3VscXR0bWdwd3FuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDIyMDI5NywiZXhwIjoyMDc5Nzk2Mjk3fQ.eirJ8kaPe8DrR0TN4KHo2ISk97zI4b8unMob_NlhtUA\""
echo "  3. cd scripts && npm install && node upload_dashboard_to_supabase.cjs"
echo ""
echo "See docs/DEPLOY_DASHBOARD_SUPABASE.md for details."
