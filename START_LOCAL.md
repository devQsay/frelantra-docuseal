# Start Local Development Server

## 📋 Prerequisites / External Dependencies

Before starting the local server, ensure you have these installed:

### Required Programs

1. **Homebrew** (macOS package manager)
   ```bash
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```

2. **Ruby 3.4.2+** (currently using 3.4.5)
   ```bash
   brew install ruby
   ```

3. **SQLite3** (usually pre-installed on macOS)
   ```bash
   sqlite3 --version
   # If not installed: brew install sqlite3
   ```

4. **Node.js & Yarn** (JavaScript runtime and package manager)
   ```bash
   brew install node
   brew install yarn
   ```

5. **Redis** (for Sidekiq background jobs)
   ```bash
   brew install redis
   brew services start redis
   ```

6. **AWS CLI** (for S3 operations)
   ```bash
   brew install awscli
   # Configure with: aws configure
   ```

### Required Libraries

7. **libpdfium** (PDF processing library)
   ```bash
   # Install wget if not already installed
   brew install wget

   # Download for macOS arm64
   wget https://github.com/bblanchon/pdfium-binaries/releases/download/chromium%2F6666/pdfium-mac-arm64.tgz
   tar -xzf pdfium-mac-arm64.tgz
   sudo cp lib/libpdfium.dylib /opt/homebrew/lib/
   # Or without sudo: cp lib/libpdfium.dylib /opt/homebrew/lib/
   ```

### Ruby Gems

8. **Bundler** (Ruby dependency manager)
   ```bash
   gem install bundler
   bundle install
   ```

### Verification

Check all dependencies are installed:
```bash
ruby --version          # Should be 3.4.2+
sqlite3 --version       # Any recent version
node --version          # Should be v16+
yarn --version          # Any recent version
redis-cli ping          # Should return "PONG"
aws --version           # Should show AWS CLI version
ls /opt/homebrew/lib/libpdfium.dylib  # Should exist (5.3MB file)
bundle --version        # Should show Bundler version
```

---

## 🔑 Environment Configuration

### Set Up .env File

Copy the example environment file and configure it with your credentials:

```bash
# Copy the development template
cp .env.development.example .env.development

# Edit with your actual values
nano .env.development  # or use your preferred editor
```

**Required Configuration:**
1. **AWS Credentials** - Get from AWS IAM console or administrator
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `S3_ATTACHMENTS_BUCKET`

2. **Secrets** - Generate with `bundle exec rails secret`
   - `SECRET_KEY_BASE`
   - `ENCRYPTION_SECRET`

3. **Redis** - Should work with defaults if Redis is running locally

**Example `.env.development`:**
```env
SECRET_KEY_BASE=your_generated_secret_here
ENCRYPTION_SECRET=your_generated_secret_here
S3_ATTACHMENTS_BUCKET=your-bucket-name
AWS_ACCESS_KEY_ID=your_aws_key
AWS_SECRET_ACCESS_KEY=your_aws_secret
REDIS_URL=redis://localhost:6379/0
```

**Note:** Never commit your `.env.development` or `.env` files! They contain secrets and are already in `.gitignore`.

---

## ✅ Server Status

The Rails server should be running on **http://localhost:3000**

Check if it's running:
```bash
ps aux | grep puma | grep -v grep
```

**Configuration**:
- libpdfium library installed for PDF processing
- Active Storage configured to use S3 (aws_s3 service)
- Environment variables loaded from .env.development
- search_entries table created (PostgreSQL migration skipped for SQLite)

## Access the Application

Open your browser to: **http://localhost:3000**

Login with:
- **Email**: `admin@test.com`
- **Password**: `password123`

## If You Need to Restart the Server

### Stop Current Server

```bash
# Kill all puma processes
pkill -f puma
```

### Start Server Again

```bash
cd /Users/quasaymultani/Documents/Dev/docuseal

# Build assets (only needed if you change JavaScript/CSS)
bin/shakapacker

# Load environment variables and start Puma server
set -a && source .env.development && set +a && \
bundle exec puma -C config/puma.rb
```

The server will start on http://localhost:3000

## Test S3 Integration

### 1. Login and Upload a Document

1. Go to http://localhost:3000
2. Login with admin@test.com / password123
3. Create a new template or upload a document

### 2. Verify S3 Upload

Check that files are going to S3:

```bash
# List recent files
aws s3 ls s3://frelantra-docuseal-contracts/ --region us-east-1 | sort -r | head -10

# Compare count before and after upload
aws s3 ls s3://frelantra-docuseal-contracts/ --region us-east-1 | wc -l
```

### 3. Watch Server Logs

The Puma process is running. To see logs in real-time:

```bash
tail -f log/development.log
```

Look for:
- `ActiveStorage::Service::S3Service` - Confirms S3 is being used
- Upload/download operations
- Any errors

### 4. Test API Settings Page

1. Navigate to: http://localhost:3000/settings/api
2. Try to create an API token
3. If you get a 500 error, it's from old encrypted data - expected in dev

## Environment Configuration

Your local environment is using:

- **Database**: SQLite (`./db.sqlite3`)
  - Note: `search_entries` table requires manual creation (PostgreSQL-only migration)
- **S3 Bucket**: `frelantra-docuseal-contracts`
- **AWS Region**: `us-east-1`
- **AWS Credentials**: From `~/.aws/credentials`
- **Redis**: localhost:6379 (for Sidekiq/background jobs)

Check `.env.development` for full configuration.

## Troubleshooting

### Port 3000 Already in Use

```bash
# Find and kill the process
lsof -ti:3000 | xargs kill -9
```

### Assets Not Loading

```bash
# Rebuild webpack assets
bin/shakapacker
```

### Redis Connection Error

```bash
# Start Redis
brew services start redis
```

### Database Issues

```bash
# Reset database (will lose data!)
rm db.sqlite3
RAILS_ENV=development bundle exec rails db:migrate

# Create search_entries table (PostgreSQL-only migration, needs manual creation for SQLite)
sqlite3 db.sqlite3 << 'EOF'
CREATE TABLE IF NOT EXISTS search_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_type VARCHAR NOT NULL,
  record_id INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  tsvector TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS index_search_entries_on_record_id_and_record_type
  ON search_entries (record_id, record_type);
EOF

# Create admin user
RAILS_ENV=development bundle exec rails runner "
account = Account.create!(name: 'Dev Account')
User.create!(email: 'admin@test.com', password: 'password123', password_confirmation: 'password123', account: account, first_name: 'Admin', last_name: 'User')
"
```

### Missing search_entries Table Error

If you get "Could not find table 'search_entries'" when deleting archived templates:

```bash
# The migration only runs for PostgreSQL, create the table manually for SQLite
sqlite3 db.sqlite3 << 'EOF'
CREATE TABLE IF NOT EXISTS search_entries (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  record_type VARCHAR NOT NULL,
  record_id INTEGER NOT NULL,
  account_id INTEGER NOT NULL,
  tsvector TEXT,
  created_at DATETIME NOT NULL,
  updated_at DATETIME NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS index_search_entries_on_record_id_and_record_type
  ON search_entries (record_id, record_type);
EOF
```

## What to Test

### Critical Tests:

1. ✅ **Login** - Verify authentication works
2. ✅ **Upload Document** - Create a template with a PDF
3. ✅ **Check S3** - Confirm file appears in S3 bucket
4. ✅ **Download Document** - Verify downloads work
5. ⚠️ **API Settings** - May error on old tokens (expected)

### What to Look For in Logs:

**Good Signs:**
```
ActiveStorage::Service::S3Service
PUT https://s3.amazonaws.com/frelantra-docuseal-contracts/
service_name: "aws_s3"
```

**Bad Signs:**
```
ActiveStorage::Service::DiskService
service_name: "disk"
Errno::ENOENT (No such file or directory)
```

## Stop the Server

```bash
# Kill all puma processes
pkill -f puma
```

## Next Steps

Once you've confirmed S3 uploads work locally:

1. The fix is already deployed to production (task definition v23)
2. Same configuration is in production
3. Test in production by uploading a file
4. Verify it appears in S3
5. Old files may not download (they were lost when containers redeployed)

## Notes

- Don't commit local development changes (`config/database.yml`, `Gemfile`, migration versions)
- These are for local testing only
- Production uses PostgreSQL and different configuration
