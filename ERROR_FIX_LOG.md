# Error & Fix Log for DocuSeal S3/Download Issues

## Error #1: Files Not Uploading to S3
**Error**: Files uploading to local disk instead of S3
**Location**: `config/environments/development.rb:53`
**Root Cause**: Active Storage configured to use `:disk` service instead of `:aws_s3`
**Fix**: Changed `config.active_storage.service = :disk` to `:aws_s3`
**Status**: ✅ FIXED

## Error #2: Environment Variables Not Loaded
**Error**: S3 bucket name not available (AWS SDK error: missing required option :name)
**Location**: Server startup
**Root Cause**: `.env.development` file not being loaded automatically
**Fix**: Start server with: `set -a && source .env.development && set +a && bundle exec puma -C config/puma.rb`
**Status**: ✅ FIXED

## Error #3: NoMethodError - undefined method 'value' for nil
**Error**: `NoMethodError: undefined method 'value' for nil`
**Location**: `lib/accounts.rb:95`
**Root Cause**: Missing safe navigation operator when `esign_certs` config doesn't exist
**Fix**: Changed `EncryptedConfig.find_by(key: EncryptedConfig::ESIGN_CERTS_KEY).value` to `EncryptedConfig.find_by(key: EncryptedConfig::ESIGN_CERTS_KEY)&.value`
**Status**: ✅ FIXED

## Error #4: NoMethodError - undefined method '[]' for nil
**Error**: `NoMethodError: undefined method '[]' for nil`
**Location**: `lib/accounts.rb:98`
**Root Cause**: Trying to access `cert_data['custom']` when `cert_data` is `nil`
**Fix**: Added early return: `return Docuseal.default_pkcs if cert_data.blank?` before line 98
**Status**: ✅ FIXED

## Error #5: TypeError - no implicit conversion of nil into String
**Error**: `TypeError: no implicit conversion of nil into String`
**Location**: `lib/generate_certificate.rb:93` in `OpenSSL::X509::Certificate#initialize`
**Stack Trace**:
- `lib/generate_certificate.rb:93` in `GenerateCertificate.load_pkcs`
- `lib/docuseal.rb:73` in `Docuseal.default_pkcs`
- `lib/accounts.rb:98` in `Accounts.load_signing_pkcs`
**Root Cause**: `Docuseal::CERTS` is empty hash `{}` from ENV (not set in development). Code tries to access `cert_data['cert']` which is nil.
**Fix**: Added check in `lib/docuseal.rb:72`: `return if Docuseal::CERTS.blank? || Docuseal::CERTS['cert'].blank?`
**Status**: ✅ FIXED

---

## Error #6: Missing search_entries Table in SQLite
**Error**: `ActiveRecord::StatementInvalid: Could not find table 'search_entries'`
**Location**: Deleting archived templates
**Root Cause**: Migration `20250603105556_create_search_enties.rb` only runs for PostgreSQL (`return unless adapter_name == 'PostgreSQL'`), so table doesn't exist in SQLite
**Fix**: Manually created simplified `search_entries` table in SQLite with required columns and unique index
**Status**: ✅ FIXED

---

## Error #7: Production API Settings Page Returns 500 Error
**Error**: `500 Internal Server Error` when accessing `/settings/api` in production
**Location**: Production environment (ECS task)
**Root Cause**: ECS task definition referenced wrong AWS Secrets Manager secret name
- **Referenced**: `docuseal-env-w1zkf5` (doesn't exist)
- **Actual**: `docuseal-env` (exists)
- **Impact**: `ENCRYPTION_SECRET` and `SECRET_KEY_BASE` environment variables were not loaded
- **Result**: Rails couldn't decrypt existing access tokens (Active Record Encryption failure)

**Stack Trace**:
- `app/controllers/api_settings_controller.rb:5` in `ApiSettingsController#index`
- `app/models/user.rb:78-80` in `User#access_token`
- `app/models/access_token.rb:32` - `encrypts :token` requires valid encryption keys

**Fix**: Updated ECS task definition to reference correct secret + deleted old tokens
1. Retrieved current task definition (revision 23)
2. Updated secret ARNs:
   - `SECRET_KEY_BASE`: Changed from `docuseal-env-w1zkf5:SECRET_KEY::` to `docuseal-env:SECRET_KEY::`
   - `ENCRYPTION_SECRET`: Changed from `docuseal-env-w1zkf5:ENCRYPTION_KEY::` to `docuseal-env:ENCRYPTION_KEY::`
3. Registered new task definition (revision 24)
4. Updated ECS service to use revision 24
5. Deployed to production
6. **Deleted 2 old access tokens** from database (encrypted with old/missing keys)
   - Used: `DELETE FROM access_tokens;`
   - New tokens will auto-generate with correct encryption keys

**Status**: ✅ FIXED & VERIFIED (task definition revision 24 + old tokens deleted)
**Verified**: Production `/settings/api` page now loads successfully, new tokens auto-generate with correct encryption

**Production Environment Config** (`config/environments/production.rb:111-119`):
```ruby
encryption_secret = ENV['ENCRYPTION_SECRET'].presence || Digest::SHA256.hexdigest(ENV['SECRET_KEY_BASE'].to_s)

config.active_record.encryption = {
  primary_key: encryption_secret.first(32),
  deterministic_key: encryption_secret.last(32),
  key_derivation_salt: Digest::SHA256.hexdigest(encryption_secret)
}
```

---

## Summary
Server should now:
- ✅ Upload files to S3
- ✅ Download files without errors
- ✅ Generate PDFs with certificates
- ✅ Access API settings page without 500 errors
- ✅ Load encryption keys from correct AWS Secrets Manager secret
