require "support/ftp_spec_matcher_helper"

# Assumes this in run in a :with_ftp_server context so an FTP server on
# localhost is available.
#
# See spec/support/with_ftp_server.rb for more info.
RSpec::Matchers.define :have_size_in_storage_of do |expected|
  include FTPSpecMatcherHelper

  match do |filepath|
    size = size_on_ftp(filepath)
    size == expected
  end

  failure_message do |actual|
    fail_msg(actual)
  end

  def fail_msg(actual, negated: false)
    dir     = File.dirname(actual)
    entries = list_in_ftp(dir).map { |filename| [filename, size_on_ftp(filename)] }
    <<~MSG
      expected: #{to_path_string(actual)} to be of size #{expected}"

      Entries for #{dir}:
      #{entries.empty? ? "  []" : entries.map { |f, s| "  #{f}: #{s}" }.join("\n")}
    MSG
  end
end
