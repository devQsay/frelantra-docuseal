# frozen_string_literal: true

require 'net/http'
require 'json'
require 'uri'
require_relative 'api_config'

module APIIntegration
  module Helper
    # Make HTTP request to API
    def api_request(method, path, body: nil, token: nil, query: nil)
      uri = build_uri(path, query)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = APIIntegration::Config.timeout

      request = build_request(method, uri, body, token)
      response = http.request(request)

      parse_response(response)
    end

    # GET request
    def api_get(path, query: nil, token: nil)
      api_request(:get, path, query: query, token: token)
    end

    # POST request
    def api_post(path, body:, token: nil)
      api_request(:post, path, body: body, token: token)
    end

    # PUT request
    def api_put(path, body:, token: nil)
      api_request(:put, path, body: body, token: token)
    end

    # DELETE request
    def api_delete(path, token: nil)
      api_request(:delete, path, token: token)
    end

    # Wait for async operations
    def wait_for_condition(max_attempts: 10, delay: 2)
      attempts = 0
      loop do
        return true if yield

        attempts += 1
        raise 'Condition not met within timeout' if attempts >= max_attempts

        sleep delay
      end
    end

    # Generate test email
    def test_email(prefix = 'test')
      "#{prefix}+#{SecureRandom.hex(8)}@example.com"
    end

    # Generate test phone
    def test_phone
      "+1#{rand(2_000_000_000..9_999_999_999)}"
    end

    # Create a base64 encoded test PDF
    def test_pdf_base64
      # Minimal valid PDF
      pdf_content = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n" \
                    "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n" \
                    "3 0 obj\n<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] >>\nendobj\n" \
                    "xref\n0 4\n0000000000 65535 f\n0000000009 00000 n\n0000000058 00000 n\n" \
                    "0000000115 00000 n\ntrailer\n<< /Size 4 /Root 1 0 R >>\nstartxref\n190\n%%EOF"
      Base64.strict_encode64(pdf_content)
    end

    # Create test HTML content
    def test_html_content
      <<~HTML
        <html>
          <body>
            <h1>Test Document</h1>
            <p>This is a test document for API integration testing.</p>
            <text-field name="full_name" role="Signer" required="true" />
            <signature-field name="signature" role="Signer" required="true" />
            <date-field name="date" role="Signer" />
          </body>
        </html>
      HTML
    end

    # Cleanup created resources
    def cleanup_resource(type, id, token: nil)
      path = case type
             when :submission
               "/submissions/#{id}"
             when :template
               "/templates/#{id}"
             else
               return
             end

      api_delete(path, token: token)
    rescue StandardError
      # Ignore cleanup errors
      nil
    end

    private

    def build_uri(path, query)
      base = APIIntegration::Config.api_url
      full_path = path.start_with?('/') ? path : "/#{path}"
      uri = URI.parse("#{base}#{full_path}")

      if query
        uri.query = URI.encode_www_form(query)
      end

      uri
    end

    def build_request(method, uri, body, token)
      request_class = case method
                      when :get then Net::HTTP::Get
                      when :post then Net::HTTP::Post
                      when :put then Net::HTTP::Put
                      when :delete then Net::HTTP::Delete
                      else raise "Unsupported method: #{method}"
                      end

      request = request_class.new(uri)
      APIIntegration::Config.headers(token: token).each do |key, value|
        request[key] = value
      end

      if body && %i[post put].include?(method)
        request.body = body.is_a?(String) ? body : body.to_json
      end

      request
    end

    def parse_response(response)
      {
        status: response.code.to_i,
        body: parse_body(response.body),
        headers: response.to_hash
      }
    end

    def parse_body(body)
      return nil if body.nil? || body.empty?

      JSON.parse(body)
    rescue JSON::ParserError
      body
    end
  end
end
