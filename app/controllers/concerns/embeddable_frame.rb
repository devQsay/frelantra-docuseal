# frozen_string_literal: true

# Allow the signing-form pages to be embedded (iframe / <docuseal-form>
# web component) from approved origins — e.g. the Frelantra app.
#
# DocuSeal inherits Rails' default `X-Frame-Options: SAMEORIGIN`, which
# blocks ALL cross-origin framing. `X-Frame-Options` has no usable
# "allow specific origin" in modern browsers, so for embeddable routes we
# delete it and use a CSP `frame-ancestors` allowlist instead.
#
# Origins come from EMBED_ALLOWED_ORIGINS (space- or comma-separated),
# e.g. "https://app.frelantra.com https://abc123.ngrok-free.app".
# When the env var is unset this is a no-op and the default SAMEORIGIN
# stays in place (no behavior change).
module EmbeddableFrame
  extend ActiveSupport::Concern

  included do
    after_action :allow_embedding_frame
  end

  private

  def allow_embedding_frame
    origins = ENV['EMBED_ALLOWED_ORIGINS'].to_s.split(/[\s,]+/).reject(&:blank?)
    return if origins.empty?

    response.headers.delete('X-Frame-Options')
    response.headers['Content-Security-Policy'] =
      "frame-ancestors 'self' #{origins.join(' ')}"
  end
end
