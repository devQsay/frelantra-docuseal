# frozen_string_literal: true

# Additive overlay — does NOT modify ds-ee Pro code. Mirrors the existing
# custom_routes.rb overlay pattern (copied in via the Dockerfile).
#
# Allow the signing-form pages to be embedded (iframe / <docuseal-form> web
# component) from approved origins, e.g. the Frelantra app. By default
# Rails sends `X-Frame-Options: SAMEORIGIN`, which blocks ALL cross-origin
# framing. `X-Frame-Options` has no usable "allow specific origin" in modern
# browsers, so for the signing-form paths we drop it and set a CSP
# `frame-ancestors` allowlist instead.
#
# Origins come from EMBED_ALLOWED_ORIGINS (space- or comma-separated), e.g.
# "https://app.frelantra.com https://abc123.ngrok-free.app". When the env var
# is unset this is a no-op and the default SAMEORIGIN stays in place.
#
# Implemented as Rack middleware (rather than a controller hook) because the
# Docker image is built FROM the ds-ee base and only overlays additive files;
# the app's own controllers are not copied in. Inserted outermost so it has
# the final say on response headers.
class EmbedFrameHeaders
  # Signing / embedding form path prefixes:
  #   /s/<slug>  submitter signing form
  #   /d/<slug>  template start form
  #   /e/<slug>  embedded submission
  #   /p/<slug>  draw-signature popup
  FORM_PATH = %r{\A/(s|d|e|p)/}

  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    origins = ENV['EMBED_ALLOWED_ORIGINS'].to_s.split(/[\s,]+/).reject(&:empty?)
    if origins.any? && env['PATH_INFO'].to_s.match?(FORM_PATH)
      # Cover both Rack 2 (capitalized) and Rack 3 (lowercase) header casings.
      headers.delete('X-Frame-Options')
      headers.delete('x-frame-options')
      headers['content-security-policy'] = "frame-ancestors 'self' #{origins.join(' ')}"
    end

    [status, headers, body]
  end
end

Rails.application.config.middleware.insert_before(0, EmbedFrameHeaders)
