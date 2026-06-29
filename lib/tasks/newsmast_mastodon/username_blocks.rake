# frozen_string_literal: true

# Import username blocks from CSV in batches.
require "csv"

namespace :username_blocks do
  desc "Import username_blocks.csv into username_blocks table in chunks of 500"
  task import: :environment do
    file_path = Rails.root.join("public", "csv", "username_blocks.csv")

    unless File.exist?(file_path)
      puts "CSV file not found: #{file_path}"
      exit
    end

    puts "Starting bulk import (500 per batch) from #{file_path}..."

    homoglyphs         = UsernameBlock::HOMOGLYPHS
    regex              = Regexp.union(homoglyphs.keys)
    existing_usernames = UsernameBlock.pluck(:username).to_set
    new_records        = []

    CSV.foreach(file_path, headers: true) do |row|
      username = row["#username"]&.strip
      next if username.blank? || existing_usernames.include?(username)

      normalized_username = username.downcase.gsub(regex, homoglyphs)
      new_records << {
        username:            username,
        normalized_username: normalized_username,
        exact:               row.fetch("#exact", true),
        allow_with_approval: row.fetch("#allow_with_approval", false)
      }
    end

    ActiveRecord::Base.transaction do
      new_records.each_slice(500) do |batch|
        UsernameBlock.insert_all(batch)
        puts "Inserted #{batch.size} records..."
      end

      if File.exist?(file_path)
        File.delete(file_path)
        puts "Successfully deleted: #{file_path}"
      end
    end

    puts "Bulk import completed. Total new: #{new_records.size}"
  end
end
