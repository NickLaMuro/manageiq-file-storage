module RSpec
  class SudoHelper
    def self.prime_sudo
      # only run once
      return true if RSpec.configuration.with_sudo?

      puts "priming 'sudo' for specs..."
      `sudo ls`
      puts

      RSpec.configuration.with_sudo = true
    end
  end
end

# Add a configuration setting that defaults to `false` that requires sudo to
# run.
#
# If the RSPEC_SUDO environment variable is set, run a shell call of `sudo ls`
# to auth with the user (if necessary) so it is primed for the specs that
# follow.
#
RSpec.configure do |config|
  config.add_setting :with_sudo, :default => false

  RSpec::SudoHelper.prime_sudo if ENV["RSPEC_SUDO"]
end
