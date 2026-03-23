#!/usr/bin/env bash
# Build and deploy Admin Dashboard to Supabase Storage
# Do NOT put SUPABASE_SERVICE_ROLE_KEY or other secrets in this file.
# Set env vars from .env or export them before running the upload step.

set -e
BASE_HREF="/storage/v1/object/public/dashboard/"

echo "Building Flutter web (Admin Dashboard)..."
flutter build web --release -t lib/main_dashboard.dart --base-href "$BASE_HREF"

echo ""
echo "Build succeeded. To upload to Supabase Storage:"
echo "  1. Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY (e.g. from .env or Supabase Dashboard → Settings → API)"
echo "  2. cd scripts && npm install && node upload_dashboard_to_supabase.cjs"
echo ""
echo "See docs/DEPLOY_DASHBOARD_SUPABASE.md for details."
