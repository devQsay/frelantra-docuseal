# Build on the maintained DocuSeal Enterprise (Pro) base image instead of the
# from-source build. The base bakes in pdfium, fonts, vips/libheif and the EE
# runtime config, so it avoids the bit-rot in the source build (Alpine `edge`
# packages, renamed pdfium release assets, etc.). ds-ee Pro code is NOT
# modified — we only add curl + one additive initializer overlay.
FROM public.ecr.aws/q1q9g1b3/ds-ee:latest

# curl for the ECS container health check (ds-ee ships wget but not curl).
RUN apk add --no-cache curl

# Additive overlay (does NOT touch ds-ee Pro code): allow the signing form to
# be embedded from approved origins. Active only when EMBED_ALLOWED_ORIGINS is
# set; see config/initializers/embed_frame_headers.rb.
COPY --chown=docuseal:docuseal ./config/initializers/embed_frame_headers.rb /app/config/initializers/embed_frame_headers.rb

# Inherit the base image's WORKDIR / ENV / CMD / ENTRYPOINT (the EE runtime,
# incl. config/puma_ee.rb). Do not override them.
