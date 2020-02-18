require "support/testfile_server_api_client"
require "support/contexts/with_file_storage"

class SMBSingletonServer
  def self.run_specs?
    # short circuit if using global sudo var
    return true if ENV["RSPEC_SUDO"]

    if ENV["RSPEC_SMB"]
      RSpec.configuration.with_sudo? || RSpec::SudoHelper.prime_sudo
    end
  end

  def self.driver
    @driver ||= TestfileServerAPIClient.new("smb")
  end
end

shared_context "with smb server", :with_smb_server do
  include WithFileStorageInterface

  def driver
    SMBSingletonServer.driver
  end
end
