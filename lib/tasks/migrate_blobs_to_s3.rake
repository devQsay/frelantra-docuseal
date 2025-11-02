# frozen_string_literal: true

namespace :storage do
  desc "Migrate Active Storage blobs from disk to aws_s3 service"
  task migrate_to_s3: :environment do
    puts "Starting migration of Active Storage blobs to aws_s3 service..."

    # Find all blobs that are using disk or have no service_name
    disk_blobs = ActiveStorage::Blob.where(service_name: [nil, 'disk'])
    total_count = disk_blobs.count

    puts "Found #{total_count} blobs using disk service"

    return puts "No blobs to migrate" if total_count.zero?

    updated_count = 0
    failed_count = 0

    disk_blobs.find_each do |blob|
      begin
        blob.update_column(:service_name, 'aws_s3')
        updated_count += 1
        print "." if updated_count % 10 == 0
      rescue => e
        puts "\nError updating blob #{blob.id}: #{e.message}"
        failed_count += 1
      end
    end

    puts "\n\nMigration complete!"
    puts "Successfully updated: #{updated_count} blobs"
    puts "Failed: #{failed_count} blobs" if failed_count > 0
    puts "\nNote: Files must exist in S3 for downloads to work."
    puts "If files were uploaded before S3 configuration, they will need to be re-uploaded."
  end
end
