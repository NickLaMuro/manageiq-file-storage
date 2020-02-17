require "support/testfile_server_api_client"
require "support/contexts/with_file_storage"

class NfsSingletonServer
  def self.run_specs?
    # short circuit if using global sudo var
    return true if ENV["RSPEC_SUDO"]

    if ENV["RSPEC_NFS"]
      RSpec.configuration.with_sudo? || RSpec::SudoHelper.prime_sudo
    end
  end

  def self.driver
    @driver ||= TestfileServerAPIClient.new("nfs")
  end
end

shared_context "with nfs server", :with_nfs_server do
  include WithFileStorageInterface

  def driver
    NfsSingletonServer.driver
  end
end
