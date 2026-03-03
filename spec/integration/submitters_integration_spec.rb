# frozen_string_literal: true

require_relative 'api_helper'

RSpec.describe 'Submitters API Integration', :integration, if: APIIntegration::Config.enabled? do
  include APIIntegration::Helper

  let(:api_token) { APIIntegration::Config.api_token }
  let(:created_resource_ids) { [] }

  after do
    # Cleanup created submissions (submitters are deleted with submissions)
    created_resource_ids.each do |id|
      cleanup_resource(:submission, id)
    end
  end

  describe 'GET /api/submitters' do
    context 'with valid authentication' do
      it 'returns a list of submitters' do
        response = api_get('/submitters')

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
        expect(response[:body]).to have_key('pagination')
        expect(response[:body]['data']).to be_an(Array)
      end

      it 'supports pagination with limit parameter' do
        response = api_get('/submitters', query: { limit: 5 })

        expect(response[:status]).to eq(200)
        expect(response[:body]['data'].length).to be <= 5
      end

      it 'supports filtering by submission_id' do
        # Get a submission first
        submissions_response = api_get('/submissions')
        skip 'No submissions available' if submissions_response[:body]['data'].empty?

        submission_id = submissions_response[:body]['data'].first['id']

        response = api_get('/submitters', query: { submission_id: submission_id })

        expect(response[:status]).to eq(200)
        if response[:body]['data'].any?
          expect(response[:body]['data'].all? { |s| s['submission_id'] == submission_id }).to be true
        end
      end

      it 'supports search by name/email/phone' do
        response = api_get('/submitters', query: { q: 'test' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering by slug' do
        # Get a submitter first to get its slug
        list_response = api_get('/submitters')
        skip 'No submitters available' if list_response[:body]['data'].empty?

        slug = list_response[:body]['data'].first['slug']

        response = api_get('/submitters', query: { slug: slug })

        expect(response[:status]).to eq(200)
        if response[:body]['data'].any?
          expect(response[:body]['data'].first['slug']).to eq(slug)
        end
      end

      it 'supports filtering by external_id' do
        response = api_get('/submitters', query: { external_id: 'test-external-id' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering by completion dates' do
        completed_after = (Time.now - 30.days).iso8601
        completed_before = Time.now.iso8601

        response = api_get('/submitters', query: {
                             completed_after: completed_after,
                             completed_before: completed_before
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 with invalid token' do
        response = api_get('/submitters', token: 'invalid_token')

        expect(response[:status]).to eq(401)
      end
    end
  end

  describe 'GET /api/submitters/:id' do
    it 'returns a specific submitter with full details' do
      list_response = api_get('/submitters')
      skip 'No submitters available for testing' if list_response[:body]['data'].empty?

      submitter_id = list_response[:body]['data'].first['id']

      response = api_get("/submitters/#{submitter_id}")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('submission_id')
      expect(response[:body]).to have_key('email')
      expect(response[:body]).to have_key('status')
      expect(response[:body]).to have_key('slug')
      expect(response[:body]).to have_key('uuid')
      expect(response[:body]).to have_key('role')
      expect(response[:body]).to have_key('template')
      expect(response[:body]).to have_key('values')
      expect(response[:body]).to have_key('documents')
      expect(response[:body]).to have_key('submission_events')
      expect(response[:body]).to have_key('metadata')
    end

    it 'returns 404 for non-existent submitter' do
      response = api_get('/submitters/999999999')

      expect(response[:status]).to be_between(403, 404)
    end
  end

  describe 'PUT /api/submitters/:id' do
    let(:test_submitter) do
      # Create a test submission to get a submitter
      templates_response = api_get('/templates')
      raise 'No templates available' if templates_response[:body]['data'].empty?

      template_id = templates_response[:body]['data'].first['id']

      create_response = api_post('/submissions', body: {
                                    template_id: template_id,
                                    send_email: false,
                                    submitters: [
                                      {
                                        email: test_email('update-test'),
                                        name: 'Original Name'
                                      }
                                    ]
                                  })

      expect(create_response[:status]).to eq(200)
      submission_id = create_response[:body].first['submission_id']
      created_resource_ids << submission_id

      create_response[:body].first
    end

    context 'with valid parameters' do
      it 'updates submitter email' do
        new_email = test_email('updated')

        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             email: new_email
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['email']).to eq(new_email)
        expect(response[:body]).to have_key('embed_src')
      end

      it 'updates submitter name' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             name: 'Updated Name'
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['name']).to eq('Updated Name')
      end

      it 'updates submitter phone' do
        new_phone = test_phone

        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             phone: new_phone
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['phone']).to eq(new_phone)
      end

      it 'updates submitter values (field pre-fill)' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             values: {
                               'field1' => 'Updated Value 1',
                               'field2' => 'Updated Value 2'
                             }
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates submitter external_id' do
        external_id = "ext-#{SecureRandom.hex(8)}"

        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             external_id: external_id
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['external_id']).to eq(external_id)
      end

      it 'updates submitter metadata' do
        metadata = {
          custom_field: 'custom_value',
          customer_id: '12345'
        }

        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             metadata: metadata
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['metadata']).to include(metadata.stringify_keys)
      end

      it 'marks submitter as completed (auto-sign)' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             completed: true
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]['status']).to eq('completed')
        expect(response[:body]['completed_at']).not_to be_nil
      end

      it 'updates completed_redirect_url' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             completed_redirect_url: 'https://example.com/success'
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates with send_email flag' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             email: test_email('resend'),
                             send_email: false
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates with custom message' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             message: {
                               subject: 'Updated Subject',
                               body: 'Updated message body'
                             }
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates field configurations' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             fields: [
                               {
                                 name: 'test_field',
                                 default_value: 'New Default',
                                 required: true,
                                 readonly: false
                               }
                             ]
                           })

        expect(response[:status]).to be_between(200, 422)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for invalid email' do
        response = api_put("/submitters/#{test_submitter['id']}", body: {
                             email: 'invalid-email'
                           })

        expect(response[:status]).to eq(422)
        expect(response[:body]).to have_key('error')
      end

      it 'returns error for non-existent submitter' do
        response = api_put('/submitters/999999999', body: {
                             name: 'Test'
                           })

        expect(response[:status]).to be_between(403, 404)
      end
    end
  end

  describe 'End-to-end submitter workflow' do
    it 'creates submission, retrieves and updates submitter' do
      # Step 1: Get template
      templates_response = api_get('/templates')
      expect(templates_response[:status]).to eq(200)
      skip 'No templates available' if templates_response[:body]['data'].empty?

      template_id = templates_response[:body]['data'].first['id']

      # Step 2: Create submission
      create_response = api_post('/submissions', body: {
                                    template_id: template_id,
                                    send_email: false,
                                    submitters: [
                                      {
                                        email: test_email('workflow'),
                                        name: 'Workflow Test User',
                                        external_id: 'workflow-123',
                                        metadata: { test: 'workflow' }
                                      }
                                    ]
                                  })

      expect(create_response[:status]).to eq(200)
      submitter = create_response[:body].first
      created_resource_ids << submitter['submission_id']

      # Step 3: Get submitter details
      get_response = api_get("/submitters/#{submitter['id']}")
      expect(get_response[:status]).to eq(200)
      expect(get_response[:body]['id']).to eq(submitter['id'])
      expect(get_response[:body]['external_id']).to eq('workflow-123')

      # Step 4: Update submitter
      update_response = api_put("/submitters/#{submitter['id']}", body: {
                                   name: 'Updated Workflow User',
                                   metadata: { test: 'updated_workflow' }
                                 })
      expect(update_response[:status]).to eq(200)
      expect(update_response[:body]['name']).to eq('Updated Workflow User')

      # Step 5: List submitters and verify update
      list_response = api_get('/submitters', query: { submission_id: submitter['submission_id'] })
      expect(list_response[:status]).to eq(200)
      updated_submitter = list_response[:body]['data'].find { |s| s['id'] == submitter['id'] }
      expect(updated_submitter['name']).to eq('Updated Workflow User')
    end

    it 'handles submitter lifecycle from pending to completed' do
      # Create submission
      templates_response = api_get('/templates')
      skip 'No templates available' if templates_response[:body]['data'].empty?

      template_id = templates_response[:body]['data'].first['id']

      create_response = api_post('/submissions', body: {
                                    template_id: template_id,
                                    send_email: false,
                                    submitters: [
                                      {
                                        email: test_email('lifecycle')
                                      }
                                    ]
                                  })

      expect(create_response[:status]).to eq(200)
      submitter = create_response[:body].first
      created_resource_ids << submitter['submission_id']

      # Verify initial status
      expect(submitter['status']).to eq('pending')
      expect(submitter['completed_at']).to be_nil

      # Complete the submitter
      update_response = api_put("/submitters/#{submitter['id']}", body: {
                                   completed: true
                                 })

      expect(update_response[:status]).to eq(200)
      expect(update_response[:body]['status']).to eq('completed')
      expect(update_response[:body]['completed_at']).not_to be_nil

      # Verify completion persisted
      get_response = api_get("/submitters/#{submitter['id']}")
      expect(get_response[:status]).to eq(200)
      expect(get_response[:body]['status']).to eq('completed')
    end
  end
end
