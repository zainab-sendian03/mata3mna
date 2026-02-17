/**
 * Upload Flutter web build (dashboard) to Supabase Storage public bucket.
 *
 * Prerequisites:
 *   1. Run: flutter build web --release -t lib/main_dashboard.dart --base-href /storage/v1/object/public/dashboard/
 *   2. Set env: SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
 *
 * Usage: node upload_dashboard_to_supabase.cjs
 */

const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const BUCKET = 'dashboard';
const UPLOAD_TIMEOUT_MS = 300000;        // 5 min default
const LARGE_FILE_TIMEOUT_MS = 600000;     // 10 min for files > 2MB (e.g. .wasm)

function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const to = setTimeout(() => controller.abort(), timeoutMs);
  return fetch(url, { ...options, signal: controller.signal }).finally(() => clearTimeout(to));
}

const BUILD_DIR = path.join(__dirname, '..', 'build', 'web');

// Optional: load .env from project root or scripts folder (no extra deps)
function loadEnv() {
  const envPaths = [
    path.join(__dirname, '..', '.env'),
    path.join(__dirname, '.env'),
  ];
  for (const envPath of envPaths) {
    if (!fs.existsSync(envPath)) continue;
    const content = fs.readFileSync(envPath, 'utf8');
    for (const line of content.split('\n')) {
      const m = line.match(/^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$/);
      if (m) {
        const val = m[2].replace(/^["']|["']$/g, '').trim();
        if (!process.env[m[1]]) process.env[m[1]] = val;
      }
    }
    break;
  }
}
loadEnv();

const MIME_TYPES = {
  '.html': 'text/html',
  '.js': 'application/javascript',
  '.json': 'application/json',
  '.css': 'text/css',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.map': 'application/json',
  '.wasm': 'application/wasm',
  '.bin': 'application/octet-stream',
  '.frag': 'text/plain',
  '.symbols': 'text/plain',
};

function getAllFiles(dir, base = '') {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  const files = [];
  for (const e of entries) {
    const rel = base ? `${base}/${e.name}` : e.name;
    const full = path.join(dir, e.name);
    if (e.isDirectory()) {
      files.push(...getAllFiles(full, rel));
    } else {
      files.push(rel);
    }
  }
  return files;
}

async function main() {
  const url = (process.env.SUPABASE_URL || '').trim();
  const key = (process.env.SUPABASE_SERVICE_ROLE_KEY || '').trim();

  if (!url) {
    console.error('SUPABASE_URL is missing or empty.');
    console.error('Set it in this terminal, or create a .env file in the project root.');
    console.error('Example: $env:SUPABASE_URL = "https://YOUR_PROJECT_REF.supabase.co"');
    process.exit(1);
  }
  if (!key) {
    console.error('SUPABASE_SERVICE_ROLE_KEY is missing or empty.');
    console.error('Set it in this terminal, or add to .env: SUPABASE_SERVICE_ROLE_KEY=eyJ...');
    console.error('Get it from: Supabase Dashboard → Settings → API → service_role (secret)');
    process.exit(1);
  }
  if (!key.startsWith('eyJ')) {
    console.error('SUPABASE_SERVICE_ROLE_KEY should be a JWT starting with eyJ...');
    process.exit(1);
  }

  if (!url.startsWith('https://') || !url.includes('.supabase.co')) {
    console.error('Invalid SUPABASE_URL. It must be your project URL, e.g.:');
    console.error('  https://vuzfcwqmkulqttmgpwqn.supabase.co');
    process.exit(1);
  }
  if (url.includes('eyJ')) {
    console.error('SUPABASE_URL must be the Project URL, not a JWT key.');
    process.exit(1);
  }

  if (!fs.existsSync(BUILD_DIR)) {
    console.error('Build folder not found:', BUILD_DIR);
    process.exit(1);
  }

  const supabase = createClient(url, key, {
    auth: { persistSession: false },
    global: {
      fetch: (input, init) => fetchWithTimeout(input, init, LARGE_FILE_TIMEOUT_MS),
    },
  });

  let buckets, listError;
  try {
    const result = await supabase.storage.listBuckets();
    buckets = result.data;
    listError = result.error;
  } catch (err) {
    console.error('Request failed:', err.message || err);
    process.exit(1);
  }
  if (listError) {
    console.error('List buckets error:', listError.message);
    process.exit(1);
  }

  const hasBucket = (buckets || []).some((b) => b.name === BUCKET);
  if (!hasBucket) {
    const { error: createErr } = await supabase.storage.createBucket(BUCKET, { public: true });
    if (createErr) {
      console.error('Create bucket error:', createErr.message);
      process.exit(1);
    }
    console.log('Created public bucket:', BUCKET);
  }

  const files = getAllFiles(BUILD_DIR);
  const DELAY_MS = 250;       // delay between uploads to avoid rate limit / connection issues
  const LARGE_FILE_MS = 800;  // extra delay before uploading large files
  const maxRetries = 3;
  const retryDelays = [2000, 4000, 6000];

  // Use full base URL so the app loads correctly when served from Storage
  const fullBaseUrl = `${url.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/`;

  console.log('Uploading', files.length, 'files to bucket', BUCKET, '(with delay between requests)...');

  const failed = [];
  for (let i = 0; i < files.length; i++) {
    const file = files[i];
    if (i > 0) await new Promise((r) => setTimeout(r, DELAY_MS));

    const fullPath = path.join(BUILD_DIR, file);
    const ext = path.extname(file);
    const contentType = MIME_TYPES[ext] || 'application/octet-stream';
    let body = fs.readFileSync(fullPath);

    // Patch index.html to use full base URL so assets load correctly from Supabase Storage
    if (file === 'index.html' && body.toString) {
      let html = body.toString('utf8');
      html = html.replace(/<base\s+href="[^"]*">/, '<base href="' + fullBaseUrl + '">');
      body = Buffer.from(html, 'utf8');
    }
    const size = body.length;
    if (size > 500000) await new Promise((r) => setTimeout(r, LARGE_FILE_MS));

    if (body instanceof Buffer && (ext === '.wasm' || ext === '.bin' || contentType === 'application/octet-stream')) {
      body = new Uint8Array(body);
    }

    for (let attempt = 0; attempt < maxRetries; attempt++) {
      try {
        const { error } = await supabase.storage.from(BUCKET).upload(file, body, {
          contentType,
          upsert: true,
        });
        if (error) {
          if (attempt < maxRetries - 1) {
            await new Promise((r) => setTimeout(r, retryDelays[attempt]));
            continue;
          }
          failed.push({ file, error: error.message });
          console.error('  FAIL:', file, '-', error.message);
          break;
        }
        console.log('  ', file);
        break;
      } catch (err) {
        if (attempt < maxRetries - 1) {
          await new Promise((r) => setTimeout(r, retryDelays[attempt]));
          continue;
        }
        failed.push({ file, error: err.message || String(err) });
        console.error('  FAIL:', file, '-', err.message || err);
      }
    }
  }

  if (failed.length > 0) {
    console.error('\n' + failed.length + ' file(s) failed to upload.');
    process.exit(1);
  }

  const indexUrl = `${url.replace(/\/$/, '')}/storage/v1/object/public/${BUCKET}/index.html`;
  console.log('\nDone. Open the dashboard in your browser:');
  console.log('  ' + indexUrl);
  console.log('\nImportant: Open this URL in a NEW TAB (address bar or right-click → Open in new tab).');
  console.log('Do NOT use Supabase Dashboard "Preview" — it loads the page in a sandboxed iframe and blocks scripts.');
  console.log('\nIf you see a blank screen: hard refresh (Ctrl+Shift+R) or clear site data and unregister Service Workers.');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
