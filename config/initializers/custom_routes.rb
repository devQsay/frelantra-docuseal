# frozen_string_literal: true

# Console callback posts to /register_ee/ee but the route only exists at POST /ee.
# Append a route alias so the Console's license registration callback works.
Rails.application.routes.append do
  post 'register_ee/ee', to: 'ee#create'
end
