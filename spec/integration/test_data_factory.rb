# frozen_string_literal: true

require_relative 'api_helper'

module APIIntegration
  # Factory for creating test data via API
  class TestDataFactory
    include APIIntegration::Helper

    attr_reader :created_resources

    def initialize
      @created_resources = []
    end

    # Create a test template
    def create_template(attrs = {})
      payload = {
        name: attrs[:name] || "Test Template #{SecureRandom.hex(4)}",
        html: attrs[:html] || default_html_content,
        external_id: attrs[:external_id]
      }.compact

      response = api_post('/templates/html', body: payload)

      if response[:status] == 200
        track_resource(:template, response[:body]['id'])
        response[:body]
      elsif response[:status] == 403
        # HTML templates not supported, use existing template
        existing_template
      else
        raise "Failed to create template: #{response[:body]}"
      end
    end

    # Get an existing template
    def existing_template
      response = api_get('/templates', query: { limit: 1 })
      raise 'No templates available' if response[:body]['data'].empty?

      response[:body]['data'].first
    end

    # Create a test submission
    def create_submission(attrs = {})
      template = attrs[:template] || existing_template
      template_id = template.is_a?(Hash) ? template['id'] : template

      payload = {
        template_id: template_id,
        send_email: attrs.fetch(:send_email, false),
        submitters: attrs[:submitters] || [
          {
            email: test_email,
            name: attrs[:name] || 'Test User',
            external_id: attrs[:external_id],
            metadata: attrs[:metadata],
            completed: attrs[:completed]
          }.compact
        ]
      }

      response = api_post('/submissions', body: payload)

      if response[:status] == 200
        submitter = response[:body].first
        track_resource(:submission, submitter['submission_id'])
        submitter
      else
        raise "Failed to create submission: #{response[:body]}"
      end
    end

    # Create multiple submissions
    def create_submissions(count, attrs = {})
      count.times.map { create_submission(attrs) }
    end

    # Get an existing submitter
    def existing_submitter
      response = api_get('/submitters', query: { limit: 1 })
      raise 'No submitters available' if response[:body]['data'].empty?

      response[:body]['data'].first
    end

    # Clone a template
    def clone_template(template_id, attrs = {})
      payload = {
        name: attrs[:name] || "Cloned Template #{SecureRandom.hex(4)}",
        folder_name: attrs[:folder_name],
        external_id: attrs[:external_id]
      }.compact

      response = api_post("/templates/#{template_id}/clone", body: payload)

      if response[:status] == 200
        track_resource(:template, response[:body]['id'])
        response[:body]
      else
        raise "Failed to clone template: #{response[:body]}"
      end
    end

    # Create a completed submission
    def create_completed_submission(attrs = {})
      create_submission(attrs.merge(completed: true))
    end

    # Create a pending submission
    def create_pending_submission(attrs = {})
      create_submission(attrs.merge(completed: false))
    end

    # Cleanup all created resources
    def cleanup_all
      @created_resources.reverse_each do |resource|
        cleanup_resource(resource[:type], resource[:id])
      rescue StandardError
        # Ignore cleanup errors
        nil
      end

      @created_resources.clear
    end

    # Cleanup specific resource
    def cleanup(type, id)
      cleanup_resource(type, id)
      @created_resources.delete_if { |r| r[:type] == type && r[:id] == id }
    end

    private

    def track_resource(type, id)
      @created_resources << { type: type, id: id }
    end

    def default_html_content
      <<~HTML
        <!DOCTYPE html>
        <html>
          <head><title>Test Document</title></head>
          <body>
            <h1>Test Document</h1>
            <p>Name: <text-field name="full_name" role="Signer" required="true" /></p>
            <p>Date: <date-field name="date" role="Signer" /></p>
            <p>Signature: <signature-field name="signature" role="Signer" required="true" /></p>
          </body>
        </html>
      HTML
    end
  end
end
