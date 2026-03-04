FROM public.ecr.aws/q1q9g1b3/ds-ee

# Only curl is missing from ds-ee (wget already present)
RUN apk add --no-cache curl

# --- Surgical patches (preserve all Pro code) ---

# accounts.rb: safe navigation on EncryptedConfig fallback lookup
RUN sed -i 's/ESIGN_CERTS_KEY)\.value/ESIGN_CERTS_KEY)\&.value/g' /app/lib/accounts.rb

# accounts.rb: guard against nil cert_data
RUN sed -i '/if (default_cert/i\    return Docuseal.default_pkcs if cert_data.blank?' /app/lib/accounts.rb

# docuseal.rb: guard against empty CERTS hash
RUN sed -i "/CERTS\['enabled'\] == false/a\\    return if Docuseal::CERTS.blank? || Docuseal::CERTS['cert'].blank?" /app/lib/docuseal.rb

# storage.yml: remove explicit AWS credentials (use IAM role)
RUN sed -i '/access_key_id:/d; /secret_access_key:/d' /app/config/storage.yml

# routes.rb: add route alias for Console callback (Console POSTs to /register_ee/ee)
RUN sed -i '/run_load_hooks(:routes/a\  post "register_ee/ee", to: "ee#create"' /app/config/routes.rb

# --- Additive custom file ---
COPY --chown=docuseal:docuseal ./lib/tasks/migrate_blobs_to_s3.rake /app/lib/tasks/migrate_blobs_to_s3.rake

WORKDIR /data/docuseal
ENV HOME=/home/docuseal
ENV WORKDIR=/data/docuseal

EXPOSE 3000
CMD ["/app/bin/bundle", "exec", "puma", "-C", "/app/config/puma.rb", "--dir", "/app"]
