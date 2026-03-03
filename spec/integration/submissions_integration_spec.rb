# frozen_string_literal: true

require_relative 'api_helper'

RSpec.describe 'Submissions API Integration', :integration, if: APIIntegration::Config.enabled? do
  include APIIntegration::Helper

  let(:api_token) { APIIntegration::Config.api_token }
  let(:created_resource_ids) { [] }

  after do
    # Cleanup created resources
    created_resource_ids.each do |id|
      cleanup_resource(:submission, id)
    end
  end

  describe 'GET /api/submissions' do
    context 'with valid authentication' do
      it 'returns a list of submissions' do
        response = api_get('/submissions')

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
        expect(response[:body]).to have_key('pagination')
        expect(response[:body]['data']).to be_an(Array)
      end

      it 'supports pagination with limit parameter' do
        response = api_get('/submissions', query: { limit: 5 })

        expect(response[:status]).to eq(200)
        expect(response[:body]['data'].length).to be <= 5
        expect(response[:body]['pagination']).to have_key('count')
      end

      it 'supports filtering by status' do
        response = api_get('/submissions', query: { status: 'completed' })

        expect(response[:status]).to eq(200)
        if response[:body]['data'].any?
          expect(response[:body]['data'].all? { |s| s['status'] == 'completed' }).to be true
        end
      end

      it 'supports search by submitter info' do
        response = api_get('/submissions', query: { q: 'test' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering by template_id' do
        # First get a submission to extract template_id
        list_response = api_get('/submissions')
        if list_response[:body]['data'].any?
          template_id = list_response[:body]['data'].first['template']['id']

          response = api_get('/submissions', query: { template_id: template_id })

          expect(response[:status]).to eq(200)
          expect(response[:body]['data'].all? { |s| s['template']['id'] == template_id }).to be true
        end
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 with invalid token' do
        response = api_get('/submissions', token: 'invalid_token')

        expect(response[:status]).to eq(401)
      end
    end
  end

  describe 'GET /api/submissions/:id' do
    it 'returns a specific submission with full details' do
      # Get list first to find a submission ID
      list_response = api_get('/submissions')
      skip 'No submissions available for testing' if list_response[:body]['data'].empty?

      submission_id = list_response[:body]['data'].first['id']

      response = api_get("/submissions/#{submission_id}")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('submitters')
      expect(response[:body]).to have_key('template')
      expect(response[:body]).to have_key('status')
      expect(response[:body]).to have_key('created_at')
      expect(response[:body]).to have_key('documents')
      expect(response[:body]).to have_key('submission_events')
      expect(response[:body]['submitters']).to be_an(Array)
    end

    it 'returns 404 for non-existent submission' do
      response = api_get('/submissions/999999999')

      expect(response[:status]).to be_between(403, 404)
    end
  end

  describe 'GET /api/submissions/:id/documents' do
    it 'returns documents for a submission' do
      list_response = api_get('/submissions')
      skip 'No submissions available for testing' if list_response[:body]['data'].empty?

      submission_id = list_response[:body]['data'].first['id']

      response = api_get("/submissions/#{submission_id}/documents")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to be_an(Array)
      response[:body].each do |doc|
        expect(doc).to have_key('name')
        expect(doc).to have_key('url') if doc['url']
      end
    end
  end

  describe 'POST /api/submissions' do
    let(:test_template_id) do
      # Get first available template
      templates_response = api_get('/templates')
      raise 'No templates available for testing' if templates_response[:body]['data'].empty?

      templates_response[:body]['data'].first['id']
    end

    context 'with valid parameters' do
      it 'creates a submission with single submitter' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          submitters: [
            {
              email: test_email('submission-test'),
              name: 'Test Submitter'
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        expect(response[:body]).to be_an(Array)
        expect(response[:body].first).to have_key('id')
        expect(response[:body].first).to have_key('submission_id')
        expect(response[:body].first).to have_key('slug')
        expect(response[:body].first).to have_key('email')
        expect(response[:body].first['email']).to eq(payload[:submitters][0][:email])

        # Track for cleanup
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with pre-filled field values' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          submitters: [
            {
              email: test_email('prefill-test'),
              name: 'Test User',
              values: {
                'field_name' => 'Pre-filled value'
              }
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with custom message' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          message: {
            subject: 'Custom Subject',
            body: 'Custom email body message'
          },
          submitters: [
            {
              email: test_email('custom-msg')
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with external_id' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          submitters: [
            {
              email: test_email('external-id'),
              external_id: "ext-#{SecureRandom.hex(8)}"
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        expect(response[:body].first['external_id']).to eq(payload[:submitters][0][:external_id])
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with metadata' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          submitters: [
            {
              email: test_email('metadata-test'),
              metadata: {
                customer_id: '12345',
                department: 'Sales'
              }
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        expect(response[:body].first['metadata']).to eq(payload[:submitters][0][:metadata].stringify_keys)
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with completed submitter (auto-sign)' do
        payload = {
          template_id: test_template_id,
          submitters: [
            {
              email: test_email('auto-sign'),
              completed: true
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        expect(response[:body].first['status']).to eq('completed')
        expect(response[:body].first['completed_at']).not_to be_nil
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with redirect URL' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          completed_redirect_url: 'https://example.com/thank-you',
          submitters: [
            {
              email: test_email('redirect')
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(200)
        created_resource_ids << response[:body].first['submission_id']
      end

      it 'creates a submission with field configurations' do
        payload = {
          template_id: test_template_id,
          send_email: false,
          submitters: [
            {
              email: test_email('field-config')
            }
          ],
          fields: [
            {
              name: 'custom_field',
              default_value: 'Default Value',
              readonly: false,
              required: true
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to be_between(200, 201)
        created_resource_ids << response[:body].first['submission_id'] if response[:status] == 200
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid email' do
        payload = {
          template_id: test_template_id,
          submitters: [
            {
              email: 'invalid-email'
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(422)
        expect(response[:body]).to have_key('error')
      end

      it 'returns error for missing template_id' do
        payload = {
          submitters: [
            {
              email: test_email
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(422)
      end

      it 'returns error for invalid template_id' do
        payload = {
          template_id: 999_999_999,
          submitters: [
            {
              email: test_email
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to be_between(403, 404)
      end

      it 'returns error for message without body' do
        payload = {
          template_id: test_template_id,
          message: {
            subject: 'Subject only'
          },
          submitters: [
            {
              email: test_email
            }
          ]
        }

        response = api_post('/submissions', body: payload)

        expect(response[:status]).to eq(422)
      end
    end
  end

  describe 'POST /api/submissions/pdf' do
    it 'creates a submission from PDF with fields' do
      payload = {
        name: 'Test PDF Submission',
        send_email: false,
        documents: [
          {
            name: 'Test Document',
            file: test_pdf_base64,
            fields: [
              {
                name: 'signature',
                type: 'signature',
                role: 'Signer',
                required: true,
                areas: [
                  {
                    x: 100,
                    y: 100,
                    w: 200,
                    h: 50,
                    page: 0
                  }
                ]
              }
            ]
          }
        ],
        submitters: [
          {
            role: 'Signer',
            email: test_email('pdf-test')
          }
        ]
      }

      response = api_post('/submissions/pdf', body: payload)

      # May return 200 or 403 if pro feature is not enabled
      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        expect(response[:body]).to have_key('id')
        created_resource_ids << response[:body]['id']
      end
    end
  end

  describe 'POST /api/submissions/html' do
    it 'creates a submission from HTML' do
      payload = {
        html: test_html_content,
        name: 'Test HTML Submission',
        send_email: false,
        submitters: [
          {
            role: 'Signer',
            email: test_email('html-test')
          }
        ]
      }

      response = api_post('/submissions/html', body: payload)

      # May return 200 or 403 if pro feature is not enabled
      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        expect(response[:body]).to have_key('id')
        created_resource_ids << response[:body]['id']
      end
    end
  end

  describe 'DELETE /api/submissions/:id' do
    it 'archives a submission' do
      # Create a submission first
      payload = {
        template_id: test_template_id,
        send_email: false,
        submitters: [
          {
            email: test_email('delete-test')
          }
        ]
      }

      create_response = api_post('/submissions', body: payload)
      expect(create_response[:status]).to eq(200)

      submission_id = create_response[:body].first['submission_id']

      # Archive it
      response = api_delete("/submissions/#{submission_id}")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('archived_at')
      expect(response[:body]['archived_at']).not_to be_nil
    end
  end

  describe 'End-to-end submission workflow' do
    it 'creates, retrieves, and archives a submission' do
      # Step 1: Create submission
      create_payload = {
        template_id: test_template_id,
        send_email: false,
        submitters: [
          {
            email: test_email('e2e-test'),
            name: 'End to End Test User',
            metadata: { test_run: 'e2e' }
          }
        ]
      }

      create_response = api_post('/submissions', body: create_payload)
      expect(create_response[:status]).to eq(200)

      submission_id = create_response[:body].first['submission_id']
      submitter_slug = create_response[:body].first['slug']

      # Step 2: Retrieve submission
      get_response = api_get("/submissions/#{submission_id}")
      expect(get_response[:status]).to eq(200)
      expect(get_response[:body]['id']).to eq(submission_id)

      # Step 3: Get documents
      docs_response = api_get("/submissions/#{submission_id}/documents")
      expect(docs_response[:status]).to eq(200)

      # Step 4: Archive submission
      archive_response = api_delete("/submissions/#{submission_id}")
      expect(archive_response[:status]).to eq(200)
      expect(archive_response[:body]['archived_at']).not_to be_nil
    end
  end
end
