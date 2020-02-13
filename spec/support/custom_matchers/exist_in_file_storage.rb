# Assumes this in run in a shared context with a driver defined.
#
# See spec/support/with_file_storage.rb for more info.
RSpec::Matchers.define :exist_in_file_storage do
  match do |actual|
    !driver.list_in_storage(actual).empty?
  end

  failure_message do |actual|
    fail_msg(actual)
  end

  failure_message_when_negated do |actual|
    fail_msg(actual, :negated => true)
  end

  def fail_msg(actual, negated: false)
    dir     = File.dirname(actual)
    entries = driver.list_in_storage(dir)
    exist   = negated ? "not exist" : "exist"
    <<~MSG
      expected: #{driver.to_path_string(actual)} to #{exist} in ftp directory"

      Entries for #{dir}:
      #{entries.empty? ? "  []" : entries.map { |e| "  #{e}" }.join("\n")}
    MSG
  end
end
