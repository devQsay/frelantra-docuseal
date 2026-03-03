# frozen_string_literal: true

module APIIntegration
  class Config
    class << self
      # API Base URL - your AWS hosted instance
      def base_url
        ENV.fetch('API_TEST_BASE_URL', 'http://alb-docuseal-frelantra-1719079990.us-east-1.elb.amazonaws.com')
      end

      # API Authentication Token
      def api_token
        raise 'API_TEST_TOKEN environment variable is required' if ENV['API_TEST_TOKEN'].blank?

        ENV.fetch('API_TEST_TOKEN')
      end

      # Testing API Token (for test mode)
      def testing_api_token
        ENV['API_TEST_TESTING_TOKEN']
      end

      # Whether to run integration tests
      def enabled?
        ENV.fetch('RUN_API_INTEGRATION_TESTS', 'false') == 'true'
      end

      # Request timeout in seconds
      def timeout
        ENV.fetch('API_TEST_TIMEOUT', '30').to_i
      end

      # Full API URL
      def api_url
        "#{base_url}/api"
      end

      # Headers for API requests
      def headers(token: nil)
        {
          'Content-Type' => 'application/json',
          'X-Auth-Token' => token || api_token
        }
      end
    end
  end
end
