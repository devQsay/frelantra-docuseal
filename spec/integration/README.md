# DocuSeal API Integration Tests

Comprehensive integration tests for the DocuSeal API hosted on AWS (`http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com`).

## Overview

This test suite provides complete API coverage for your DocuSeal instance, testing all endpoints documented in the [DocuSeal API Documentation](https://www.docuseal.com/docs/api).

## Test Coverage

### Submissions API (`submissions_integration_spec.rb`)
- ✅ List submissions with pagination and filtering
- ✅ Get submission details
- ✅ Get submission documents
- ✅ Create submissions from templates
- ✅ Create submissions from PDF (Pro feature)
- ✅ Create submissions from HTML (Pro feature)
- ✅ Archive submissions
- ✅ End-to-end submission workflows
- ✅ Error handling and validation

### Submitters API (`submitters_integration_spec.rb`)
- ✅ List submitters with pagination and filtering
- ✅ Get submitter details
- ✅ Update submitter information
- ✅ Update submitter email, name, phone
- ✅ Pre-fill field values
- ✅ Mark submitters as completed (auto-sign)
- ✅ Manage external IDs and metadata
- ✅ End-to-end submitter workflows
- ✅ Error handling and validation

### Templates API (`templates_integration_spec.rb`)
- ✅ List templates with pagination and filtering
- ✅ Get template details
- ✅ Create templates from PDF (Pro feature)
- ✅ Create templates from HTML (Pro feature)
- ✅ Clone templates
- ✅ Merge templates (Pro feature)
- ✅ Update template settings
- ✅ Manage shared links
- ✅ Archive templates
- ✅ End-to-end template workflows
- ✅ Error handling and validation

## Prerequisites

1. **API Token**: You need a valid API token from your DocuSeal instance
2. **Ruby**: Ruby 2.7+ installed
3. **Dependencies**: Run `bundle install` to install required gems

## Getting Your API Token

1. Log in to your DocuSeal instance at `http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com`
2. Navigate to **Settings** → **API**
3. Generate or copy your API token
4. Keep this token secure - do not commit it to version control

## Configuration

### Environment Variables

Create a `.env.test` file in the project root:

```bash
# Required: Your API authentication token
API_TEST_TOKEN=your_api_token_here

# Optional: Testing mode API token (for testing environments)
API_TEST_TESTING_TOKEN=your_testing_token_here

# Optional: Override the base URL (defaults to your AWS ALB)
API_TEST_BASE_URL=http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com

# Optional: Request timeout in seconds (defaults to 30)
API_TEST_TIMEOUT=30

# Required: Enable integration tests
RUN_API_INTEGRATION_TESTS=true
```

### Quick Setup

```bash
# Copy the example configuration
cat > .env.test << EOF
API_TEST_TOKEN=your_api_token_here
API_TEST_BASE_URL=https://esign.frelantra.com
RUN_API_INTEGRATION_TESTS=true
EOF

# Load the environment variables
export $(cat .env.test | xargs)
```

## Running the Tests

### Run All Integration Tests

```bash
# Run all integration tests
bundle exec rspec spec/integration/

# Run with verbose output
bundle exec rspec spec/integration/ --format documentation
```

### Run Specific Test Files

```bash
# Test submissions only
bundle exec rspec spec/integration/submissions_integration_spec.rb

# Test submitters only
bundle exec rspec spec/integration/submitters_integration_spec.rb

# Test templates only
bundle exec rspec spec/integration/templates_integration_spec.rb
```

### Run Specific Test Cases

```bash
# Run a specific describe block
bundle exec rspec spec/integration/submissions_integration_spec.rb -e "GET /api/submissions"

# Run a specific test
bundle exec rspec spec/integration/submissions_integration_spec.rb:17
```

### Run with Coverage Report

```bash
# Generate coverage report
COVERAGE=true bundle exec rspec spec/integration/
```

## Test Organization

```
spec/integration/
├── README.md                          # This file
├── api_config.rb                      # Configuration management
├── api_helper.rb                      # HTTP request helpers
├── shared_examples.rb                 # Reusable test examples
├── test_data_factory.rb              # Test data creation helpers
├── submissions_integration_spec.rb    # Submissions API tests
├── submitters_integration_spec.rb     # Submitters API tests
└── templates_integration_spec.rb      # Templates API tests
```

## Test Helpers

### API Helper Methods

```ruby
# GET request
response = api_get('/submissions', query: { limit: 10 })

# POST request
response = api_post('/submissions', body: { template_id: 1, submitters: [...] })

# PUT request
response = api_put('/submitters/123', body: { name: 'Updated' })

# DELETE request
response = api_delete('/submissions/123')
```

### Test Data Factory

```ruby
# Create test data easily
factory = APIIntegration::TestDataFactory.new

# Create a submission
submission = factory.create_submission(name: 'Test')

# Create multiple submissions
submissions = factory.create_submissions(5)

# Cleanup all created resources
factory.cleanup_all
```

### Response Structure

All API helper methods return a hash with:

```ruby
{
  status: 200,                    # HTTP status code
  body: {...},                    # Parsed JSON response
  headers: {...}                  # Response headers
}
```

## Understanding Test Results

### Successful Test Run

```
Submissions API Integration
  GET /api/submissions
    ✓ returns a list of submissions
    ✓ supports pagination with limit parameter
    ✓ supports filtering by status
  ...

Finished in 12.34 seconds
150 examples, 0 failures
```

### Failed Test

```
Failures:

  1) Submissions API Integration POST /api/submissions creates a submission
     Failure/Error: expect(response[:status]).to eq(200)
       expected: 200
            got: 422
     # ./spec/integration/submissions_integration_spec.rb:85
```

### Skipped Tests

Some tests may be skipped if:
- No test data is available (templates, submissions)
- Pro features are not enabled
- Resources can't be created

```
Submissions API Integration
  POST /api/submissions/pdf
    ○ creates a submission from PDF (SKIPPED: Pro feature not enabled)
```

## CI/CD Integration

### GitHub Actions Example

```yaml
name: API Integration Tests

on:
  schedule:
    - cron: '0 0 * * *'  # Run daily
  workflow_dispatch:      # Manual trigger

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 3.2
          bundler-cache: true

      - name: Run API Integration Tests
        env:
          API_TEST_TOKEN: ${{ secrets.API_TEST_TOKEN }}
          API_TEST_BASE_URL: http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com
          RUN_API_INTEGRATION_TESTS: true
        run: |
          bundle exec rspec spec/integration/ --format documentation
```

## Troubleshooting

### Tests Not Running

**Problem**: Tests are being skipped
**Solution**: Ensure `RUN_API_INTEGRATION_TESTS=true` is set

```bash
export RUN_API_INTEGRATION_TESTS=true
bundle exec rspec spec/integration/
```

### Authentication Errors (401)

**Problem**: All tests fail with 401 Unauthorized
**Solution**: Verify your API token is correct

```bash
# Test your token directly
curl -H "X-Auth-Token: your_token_here" http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com/api/templates
```

### Connection Timeouts

**Problem**: Tests timeout connecting to the API
**Solution**:
1. Check your internet connection
2. Verify the API URL is accessible
3. Increase timeout value

```bash
export API_TEST_TIMEOUT=60
```

### No Templates/Data Available

**Problem**: Tests skip due to missing data
**Solution**: Create at least one template in your DocuSeal instance before running tests

### SSL Certificate Errors

**Problem**: SSL verification failures
**Solution**: This shouldn't happen with a properly configured AWS instance, but if it does:

```ruby
# Add to api_helper.rb temporarily for debugging
http.verify_mode = OpenSSL::SSL::VERIFY_NONE  # NOT recommended for production
```

## Best Practices

### 1. Don't Commit Secrets

Never commit your `.env.test` file or API tokens:

```bash
# Add to .gitignore
echo ".env.test" >> .gitignore
```

### 2. Use Testing API Keys

If available, use testing mode API keys to avoid affecting production data:

```bash
API_TEST_TESTING_TOKEN=your_testing_token
```

### 3. Clean Up Test Data

The tests automatically clean up created resources, but you can manually verify:

```bash
# Check for test submissions
curl -H "X-Auth-Token: your_token" \
  "http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com/api/submissions?q=test"
```

### 4. Run Tests Regularly

Schedule regular test runs to catch API issues early:
- Daily automated runs via CI/CD
- Before and after deployments
- After API updates

### 5. Monitor Test Performance

Track test execution time to identify performance issues:

```bash
bundle exec rspec spec/integration/ --format documentation --profile
```

## Support

For issues with:
- **DocuSeal API**: Check [DocuSeal API Docs](https://www.docuseal.com/docs/api)
- **Test Suite**: Review this README or check test comments
- **AWS Hosting**: Contact your AWS administrator

## Contributing

When adding new tests:

1. Follow existing patterns in test files
2. Use helper methods from `api_helper.rb`
3. Clean up created resources in `after` blocks
4. Add appropriate documentation
5. Test both success and error cases

## License

These tests are part of the DocuSeal project and follow the same license.
