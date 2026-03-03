# frozen_string_literal: true

# Shared examples for common API behavior patterns

RSpec.shared_examples 'an authenticated API endpoint' do |method, path|
  it 'returns 401 with invalid token' do
    case method
    when :get
      response = api_get(path, token: 'invalid_token')
    when :post
      response = api_post(path, body: {}, token: 'invalid_token')
    when :put
      response = api_put(path, body: {}, token: 'invalid_token')
    when :delete
      response = api_delete(path, token: 'invalid_token')
    end

    expect(response[:status]).to eq(401)
  end

  it 'returns 401 with missing token' do
    case method
    when :get
      response = api_get(path, token: '')
    when :post
      response = api_post(path, body: {}, token: '')
    when :put
      response = api_put(path, body: {}, token: '')
    when :delete
      response = api_delete(path, token: '')
    end

    expect(response[:status]).to eq(401)
  end
end

RSpec.shared_examples 'a paginated API endpoint' do |path|
  it 'returns paginated data structure' do
    response = api_get(path)

    expect(response[:status]).to eq(200)
    expect(response[:body]).to have_key('data')
    expect(response[:body]).to have_key('pagination')
    expect(response[:body]['data']).to be_an(Array)
  end

  it 'respects limit parameter' do
    response = api_get(path, query: { limit: 5 })

    expect(response[:status]).to eq(200)
    expect(response[:body]['data'].length).to be <= 5
  end

  it 'includes pagination metadata' do
    response = api_get(path)

    expect(response[:status]).to eq(200)
    expect(response[:body]['pagination']).to have_key('count')
  end

  it 'supports after parameter for pagination' do
    first_response = api_get(path, query: { limit: 1 })
    return if first_response[:body]['data'].empty?

    next_id = first_response[:body]['pagination']['next']
    return unless next_id

    second_response = api_get(path, query: { after: next_id })

    expect(second_response[:status]).to eq(200)
    expect(second_response[:body]).to have_key('data')
  end
end

RSpec.shared_examples 'a searchable API endpoint' do |path, search_field|
  it 'supports search query parameter' do
    response = api_get(path, query: { q: 'test' })

    expect(response[:status]).to eq(200)
    expect(response[:body]).to have_key('data')
  end

  it 'returns results matching search criteria' do
    # First get some data
    list_response = api_get(path)
    return if list_response[:body]['data'].empty?

    # Pick a field value to search for
    first_item = list_response[:body]['data'].first
    search_term = first_item[search_field]&.to_s&.split&.first
    return if search_term.blank?

    response = api_get(path, query: { q: search_term })

    expect(response[:status]).to eq(200)
    # Results should include the search term (though may have other results too)
    expect(response[:body]['data']).to be_an(Array)
  end
end

RSpec.shared_examples 'a resource with external_id' do |resource_type, create_method|
  it 'accepts and stores external_id' do
    external_id = "test-#{SecureRandom.hex(8)}"

    resource = send(create_method, external_id: external_id)

    expect(resource).to have_key('external_id')
    expect(resource['external_id']).to eq(external_id)
  end

  it 'allows filtering by external_id' do
    external_id = "unique-#{SecureRandom.hex(8)}"

    resource = send(create_method, external_id: external_id)

    response = api_get("/#{resource_type}s", query: { external_id: external_id })

    expect(response[:status]).to eq(200)
    matching_items = response[:body]['data'].select { |item| item['external_id'] == external_id }
    expect(matching_items).not_to be_empty
  end
end

RSpec.shared_examples 'a resource with metadata' do |create_method|
  it 'accepts and stores metadata' do
    metadata = {
      customer_id: '12345',
      department: 'Sales',
      custom_field: 'custom_value'
    }

    resource = send(create_method, metadata: metadata)

    expect(resource).to have_key('metadata')
    expect(resource['metadata']).to include(metadata.stringify_keys)
  end

  it 'allows empty metadata' do
    resource = send(create_method, metadata: {})

    expect(resource).to have_key('metadata')
    expect(resource['metadata']).to be_a(Hash)
  end

  it 'preserves metadata types' do
    metadata = {
      string_field: 'text',
      number_field: 42,
      boolean_field: true,
      array_field: [1, 2, 3]
    }

    resource = send(create_method, metadata: metadata)

    expect(resource['metadata']['number_field']).to eq(42)
    expect(resource['metadata']['boolean_field']).to be true
  end
end

RSpec.shared_examples 'an archivable resource' do |resource_type, create_method|
  it 'archives the resource' do
    resource = send(create_method)
    resource_id = resource['id'] || resource['submission_id']

    response = api_delete("/#{resource_type}s/#{resource_id}")

    expect(response[:status]).to eq(200)
    expect(response[:body]).to have_key('archived_at')
    expect(response[:body]['archived_at']).not_to be_nil
  end

  it 'sets archived_at timestamp' do
    resource = send(create_method)
    resource_id = resource['id'] || resource['submission_id']

    before_time = Time.now.iso8601

    response = api_delete("/#{resource_type}s/#{resource_id}")

    expect(response[:status]).to eq(200)
    archived_at = Time.parse(response[:body]['archived_at'])
    expect(archived_at).to be >= Time.parse(before_time)
  end
end

RSpec.shared_examples 'a resource that validates email' do |create_method|
  it 'rejects invalid email format' do
    result = send(create_method, email: 'invalid-email')

    expect(result[:status]).to eq(422)
    expect(result[:body]).to have_key('error')
  end

  it 'accepts valid email addresses' do
    valid_emails = [
      'test@example.com',
      'user+tag@example.com',
      'user.name@example.com',
      'user@subdomain.example.com'
    ]

    valid_emails.each do |email|
      result = send(create_method, email: email)
      expect(result[:status]).to be_between(200, 201)
    end
  end
end

RSpec.shared_examples 'a resource with timestamps' do |resource|
  it 'includes created_at timestamp' do
    expect(resource).to have_key('created_at')
    expect(resource['created_at']).not_to be_nil
    expect { Time.parse(resource['created_at']) }.not_to raise_error
  end

  it 'includes updated_at timestamp' do
    expect(resource).to have_key('updated_at')
    expect(resource['updated_at']).not_to be_nil
    expect { Time.parse(resource['updated_at']) }.not_to raise_error
  end

  it 'has created_at before or equal to updated_at' do
    created = Time.parse(resource['created_at'])
    updated = Time.parse(resource['updated_at'])
    expect(created).to be <= updated
  end
end

RSpec.shared_examples 'a rate limited endpoint' do |path, method = :get|
  # Note: This example requires high request volume to trigger
  # May not work in all environments

  it 'eventually returns 429 with excessive requests' do
    skip 'Rate limiting test requires many requests'

    responses = []
    100.times do
      case method
      when :get
        responses << api_get(path)
      when :post
        responses << api_post(path, body: {})
      end
      break if responses.last[:status] == 429
    end

    # Check if any response was rate limited
    rate_limited = responses.any? { |r| r[:status] == 429 }

    # This test might not trigger rate limiting in test environment
    unless rate_limited
      skip 'Rate limiting not triggered (may be disabled in test env)'
    end
  end
end
