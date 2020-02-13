# Assumes this in run in a shared context with a driver defined.
#
# See spec/support/with_file_storage.rb for more info.
RSpec::Matchers.define :have_size_in_storage_of do |expected|
  match do |filepath|
    size = driver.size_in_storage(filepath)
    size == expected
  end

  failure_message do |actual|
    fail_msg(actual)
  end

  def fail_msg(actual, negated: false)
    dir     = File.dirname(actual)
    entries = driver.list_in_storage(dir).map do |filename|
                [filename, driver.size_in_storage(filename)]
              end
    <<~MSG
      expected: #{driver.to_path_string(actual)} to be of size #{expected}"

      Entries for #{dir}:
      #{entries.empty? ? "  []" : entries.map { |f, s| "  #{f}: #{s}" }.join("\n")}
    MSG
  end
end
