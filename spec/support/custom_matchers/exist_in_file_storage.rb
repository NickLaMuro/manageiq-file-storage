require "support/ftp_spec_matcher_helper"

# Assumes this in run in a :with_ftp_server context so an FTP server on
# localhost is available.
#
# See spec/support/with_ftp_server.rb for more info.
RSpec::Matchers.define :exist_in_file_storage do
  include FTPSpecMatcherHelper

  match do |actual|
    !list_in_ftp(actual).empty?
  end

  failure_message do |actual|
    fail_msg(actual)
  end

  failure_message_when_negated do |actual|
    fail_msg(actual, :negated => true)
  end

  def fail_msg(actual, negated: false)
    dir     = File.dirname(actual)
    entries = list_in_ftp(dir)
    exist   = negated ? "not exist" : "exist"
    <<~MSG
      expected: #{to_path_string(actual)} to #{exist} in ftp directory"

      Entries for #{dir}:
      #{entries.empty? ? "  []" : entries.map { |e| "  #{e}" }.join("\n")}
    MSG
  end
end
