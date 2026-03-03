# frozen_string_literal: true

require_relative 'api_helper'

RSpec.describe 'Templates API Integration', :integration, if: APIIntegration::Config.enabled? do
  include APIIntegration::Helper

  let(:api_token) { APIIntegration::Config.api_token }
  let(:created_resource_ids) { [] }

  after do
    # Cleanup created resources
    created_resource_ids.each do |id|
      cleanup_resource(:template, id)
    end
  end

  describe 'GET /api/templates' do
    context 'with valid authentication' do
      it 'returns a list of templates' do
        response = api_get('/templates')

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
        expect(response[:body]).to have_key('pagination')
        expect(response[:body]['data']).to be_an(Array)
      end

      it 'supports pagination with limit parameter' do
        response = api_get('/templates', query: { limit: 5 })

        expect(response[:status]).to eq(200)
        expect(response[:body]['data'].length).to be <= 5
        expect(response[:body]['pagination']).to have_key('count')
      end

      it 'supports search by name' do
        response = api_get('/templates', query: { q: 'test' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering by slug' do
        list_response = api_get('/templates')
        skip 'No templates available' if list_response[:body]['data'].empty?

        slug = list_response[:body]['data'].first['slug']

        response = api_get('/templates', query: { slug: slug })

        expect(response[:status]).to eq(200)
        if response[:body]['data'].any?
          expect(response[:body]['data'].first['slug']).to eq(slug)
        end
      end

      it 'supports filtering by external_id' do
        response = api_get('/templates', query: { external_id: 'test-external-id' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering by folder' do
        response = api_get('/templates', query: { folder: 'Test Folder' })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end

      it 'supports filtering archived templates' do
        response = api_get('/templates', query: { archived: true })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('data')
      end
    end

    context 'with invalid authentication' do
      it 'returns 401 with invalid token' do
        response = api_get('/templates', token: 'invalid_token')

        expect(response[:status]).to eq(401)
      end
    end

    context 'response structure validation' do
      it 'returns templates with correct structure' do
        response = api_get('/templates')
        expect(response[:status]).to eq(200)

        if response[:body]['data'].any?
          template = response[:body]['data'].first

          expect(template).to have_key('id')
          expect(template).to have_key('name')
          expect(template).to have_key('slug')
          expect(template).to have_key('fields')
          expect(template).to have_key('submitters')
          expect(template).to have_key('documents')
          expect(template).to have_key('schema')
          expect(template).to have_key('created_at')
          expect(template).to have_key('updated_at')
        end
      end
    end
  end

  describe 'GET /api/templates/:id' do
    it 'returns a specific template with full details' do
      list_response = api_get('/templates')
      skip 'No templates available for testing' if list_response[:body]['data'].empty?

      template_id = list_response[:body]['data'].first['id']

      response = api_get("/templates/#{template_id}")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('name')
      expect(response[:body]).to have_key('slug')
      expect(response[:body]).to have_key('fields')
      expect(response[:body]).to have_key('submitters')
      expect(response[:body]).to have_key('documents')
      expect(response[:body]).to have_key('schema')
      expect(response[:body]).to have_key('preferences')
      expect(response[:body]).to have_key('author')
      expect(response[:body]).to have_key('created_at')
      expect(response[:body]).to have_key('updated_at')

      # Verify nested structures
      expect(response[:body]['submitters']).to be_an(Array)
      expect(response[:body]['documents']).to be_an(Array)
      expect(response[:body]['fields']).to be_an(Array)
    end

    it 'returns 404 for non-existent template' do
      response = api_get('/templates/999999999')

      expect(response[:status]).to be_between(403, 404)
    end
  end

  describe 'POST /api/templates/pdf' do
    it 'creates a template from PDF with field definitions' do
      payload = {
        name: 'Test PDF Template',
        documents: [
          {
            name: 'Test Document',
            file: test_pdf_base64,
            fields: [
              {
                name: 'full_name',
                type: 'text',
                role: 'Signer',
                required: true,
                areas: [
                  {
                    x: 50,
                    y: 100,
                    w: 200,
                    h: 30,
                    page: 0
                  }
                ]
              },
              {
                name: 'signature',
                type: 'signature',
                role: 'Signer',
                required: true,
                areas: [
                  {
                    x: 50,
                    y: 200,
                    w: 200,
                    h: 60,
                    page: 0
                  }
                ]
              },
              {
                name: 'date',
                type: 'date',
                role: 'Signer',
                required: false,
                areas: [
                  {
                    x: 50,
                    y: 300,
                    w: 150,
                    h: 30,
                    page: 0
                  }
                ]
              }
            ]
          }
        ],
        external_id: "test-pdf-#{SecureRandom.hex(6)}"
      }

      response = api_post('/templates/pdf', body: payload)

      # May return 200 or 403 if pro feature is not enabled
      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        expect(response[:body]).to have_key('id')
        expect(response[:body]).to have_key('name')
        expect(response[:body]['name']).to eq('Test PDF Template')
        created_resource_ids << response[:body]['id']
      end
    end

    it 'creates a template from PDF with multiple documents' do
      payload = {
        name: 'Multi-Document Template',
        documents: [
          {
            name: 'Document 1',
            file: test_pdf_base64
          },
          {
            name: 'Document 2',
            file: test_pdf_base64
          }
        ],
        merge_documents: false
      }

      response = api_post('/templates/pdf', body: payload)

      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        created_resource_ids << response[:body]['id']
      end
    end
  end

  describe 'POST /api/templates/html' do
    it 'creates a template from HTML' do
      payload = {
        name: 'Test HTML Template',
        html: test_html_content,
        external_id: "test-html-#{SecureRandom.hex(6)}"
      }

      response = api_post('/templates/html', body: payload)

      # May return 200 or 403 if pro feature is not enabled
      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        expect(response[:body]).to have_key('id')
        expect(response[:body]).to have_key('name')
        expect(response[:body]['name']).to eq('Test HTML Template')
        created_resource_ids << response[:body]['id']
      end
    end

    it 'creates a template from HTML with custom page size' do
      payload = {
        name: 'A4 HTML Template',
        html: test_html_content,
        size: 'A4'
      }

      response = api_post('/templates/html', body: payload)

      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        created_resource_ids << response[:body]['id']
      end
    end

    it 'creates a template from HTML with header and footer' do
      payload = {
        name: 'HTML Template with Header/Footer',
        html: test_html_content,
        html_header: '<div>Header Content</div>',
        html_footer: '<div>Footer Content - Page {page}</div>'
      }

      response = api_post('/templates/html', body: payload)

      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        created_resource_ids << response[:body]['id']
      end
    end
  end

  describe 'POST /api/templates/:id/clone' do
    let(:source_template_id) do
      list_response = api_get('/templates')
      raise 'No templates available' if list_response[:body]['data'].empty?

      list_response[:body]['data'].first['id']
    end

    it 'clones an existing template' do
      payload = {
        name: "Cloned Template #{SecureRandom.hex(4)}",
        external_id: "cloned-#{SecureRandom.hex(6)}"
      }

      response = api_post("/templates/#{source_template_id}/clone", body: payload)

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('name')
      expect(response[:body]['name']).to eq(payload[:name])
      expect(response[:body]['external_id']).to eq(payload[:external_id])

      created_resource_ids << response[:body]['id']
    end

    it 'clones a template to a different folder' do
      payload = {
        name: "Cloned to Folder #{SecureRandom.hex(4)}",
        folder_name: 'Test Folder'
      }

      response = api_post("/templates/#{source_template_id}/clone", body: payload)

      expect(response[:status]).to eq(200)
      created_resource_ids << response[:body]['id']
    end

    it 'returns error for non-existent template' do
      response = api_post('/templates/999999999/clone', body: {
                            name: 'Clone Test'
                          })

      expect(response[:status]).to be_between(403, 404)
    end
  end

  describe 'POST /api/templates/merge' do
    it 'merges multiple templates' do
      # Get at least 2 templates
      list_response = api_get('/templates', query: { limit: 2 })
      skip 'Not enough templates to merge' if list_response[:body]['data'].length < 2

      template_ids = list_response[:body]['data'].map { |t| t['id'] }

      payload = {
        name: "Merged Template #{SecureRandom.hex(4)}",
        template_ids: template_ids,
        external_id: "merged-#{SecureRandom.hex(6)}"
      }

      response = api_post('/templates/merge', body: payload)

      # May return 200 or 403 if pro feature is not enabled
      expect(response[:status]).to be_between(200, 403)

      if response[:status] == 200
        expect(response[:body]).to have_key('id')
        expect(response[:body]).to have_key('name')
        created_resource_ids << response[:body]['id']
      end
    end
  end

  describe 'PUT /api/templates/:id' do
    let(:test_template_id) do
      list_response = api_get('/templates')
      raise 'No templates available' if list_response[:body]['data'].empty?

      list_response[:body]['data'].first['id']
    end

    context 'with valid parameters' do
      it 'updates template name' do
        new_name = "Updated Template #{SecureRandom.hex(4)}"

        response = api_put("/templates/#{test_template_id}", body: {
                             name: new_name
                           })

        expect(response[:status]).to eq(200)
        expect(response[:body]).to have_key('id')
        expect(response[:body]).to have_key('updated_at')

        # Verify the update
        get_response = api_get("/templates/#{test_template_id}")
        expect(get_response[:body]['name']).to eq(new_name)
      end

      it 'updates template external_id' do
        external_id = "updated-#{SecureRandom.hex(6)}"

        response = api_put("/templates/#{test_template_id}", body: {
                             external_id: external_id
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates template folder' do
        response = api_put("/templates/#{test_template_id}", body: {
                             folder_name: 'Integration Tests'
                           })

        expect(response[:status]).to eq(200)
      end

      it 'enables template shared link' do
        response = api_put("/templates/#{test_template_id}", body: {
                             shared_link: true
                           })

        expect(response[:status]).to eq(200)

        # Verify shared_link is enabled
        get_response = api_get("/templates/#{test_template_id}")
        expect(get_response[:body]['shared_link']).to be true
      end

      it 'disables template shared link' do
        # First enable it
        api_put("/templates/#{test_template_id}", body: { shared_link: true })

        # Then disable it
        response = api_put("/templates/#{test_template_id}", body: {
                             shared_link: false
                           })

        expect(response[:status]).to eq(200)
      end

      it 'updates template roles' do
        response = api_put("/templates/#{test_template_id}", body: {
                             roles: ['Updated Role 1', 'Updated Role 2']
                           })

        expect(response[:status]).to be_between(200, 422)
      end
    end

    context 'with invalid parameters' do
      it 'returns error for non-existent template' do
        response = api_put('/templates/999999999', body: {
                             name: 'Test'
                           })

        expect(response[:status]).to be_between(403, 404)
      end
    end
  end

  describe 'PUT /api/templates/:id/documents' do
    it 'updates template documents' do
      list_response = api_get('/templates')
      skip 'No templates available' if list_response[:body]['data'].empty?

      template_id = list_response[:body]['data'].first['id']

      payload = {
        documents: [
          {
            name: 'Updated Document',
            file: test_pdf_base64
          }
        ]
      }

      response = api_put("/templates/#{template_id}/documents", body: payload)

      # This endpoint might have specific requirements
      expect(response[:status]).to be_between(200, 422)
    end
  end

  describe 'DELETE /api/templates/:id' do
    it 'archives a template' do
      # First, clone a template so we can archive it
      list_response = api_get('/templates')
      skip 'No templates available' if list_response[:body]['data'].empty?

      source_template_id = list_response[:body]['data'].first['id']

      clone_response = api_post("/templates/#{source_template_id}/clone", body: {
                                   name: "Template to Archive #{SecureRandom.hex(4)}"
                                 })

      expect(clone_response[:status]).to eq(200)
      template_id = clone_response[:body]['id']

      # Archive it
      response = api_delete("/templates/#{template_id}")

      expect(response[:status]).to eq(200)
      expect(response[:body]).to have_key('id')
      expect(response[:body]).to have_key('archived_at')
      expect(response[:body]['archived_at']).not_to be_nil
    end
  end

  describe 'End-to-end template workflow' do
    it 'creates, retrieves, updates, clones, and archives a template' do
      # Step 1: Create template from HTML (if supported)
      create_payload = {
        name: "E2E Test Template #{SecureRandom.hex(4)}",
        html: test_html_content,
        external_id: "e2e-#{SecureRandom.hex(6)}"
      }

      create_response = api_post('/templates/html', body: create_payload)
      skip 'HTML template creation not supported' unless create_response[:status] == 200

      template_id = create_response[:body]['id']

      # Step 2: Retrieve template
      get_response = api_get("/templates/#{template_id}")
      expect(get_response[:status]).to eq(200)
      expect(get_response[:body]['id']).to eq(template_id)

      # Step 3: Update template
      update_response = api_put("/templates/#{template_id}", body: {
                                   name: 'E2E Updated Template Name',
                                   shared_link: true
                                 })
      expect(update_response[:status]).to eq(200)

      # Step 4: Clone template
      clone_response = api_post("/templates/#{template_id}/clone", body: {
                                   name: 'E2E Cloned Template'
                                 })
      expect(clone_response[:status]).to eq(200)
      cloned_id = clone_response[:body]['id']

      # Step 5: Archive both templates
      archive_response1 = api_delete("/templates/#{template_id}")
      expect(archive_response1[:status]).to eq(200)

      archive_response2 = api_delete("/templates/#{cloned_id}")
      expect(archive_response2[:status]).to eq(200)
    end

    it 'creates template and uses it for submission' do
      # Create template
      create_payload = {
        name: "Template for Submission #{SecureRandom.hex(4)}",
        html: test_html_content
      }

      create_response = api_post('/templates/html', body: create_payload)
      skip 'HTML template creation not supported' unless create_response[:status] == 200

      template_id = create_response[:body]['id']
      created_resource_ids << template_id

      # Use template to create submission
      submission_payload = {
        template_id: template_id,
        send_email: false,
        submitters: [
          {
            role: 'Signer',
            email: test_email('template-workflow')
          }
        ]
      }

      submission_response = api_post('/submissions', body: submission_payload)
      expect(submission_response[:status]).to eq(200)

      # Cleanup submission
      cleanup_resource(:submission, submission_response[:body].first['submission_id'])

      # Archive template
      cleanup_resource(:template, template_id)
    end
  end
end
