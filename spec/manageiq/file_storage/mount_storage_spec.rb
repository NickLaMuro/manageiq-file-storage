require "manageiq/file_storage/mount_storage"

describe ManageIQ::FileStorage::MountStorage do
  it "#connect returns a string pointing to the mount point" do
    allow(described_class).to receive(:raw_disconnect)
    s = described_class.new(:uri => '/tmp/abc')
    s.logger = Logger.new("/dev/null")

    result = s.connect
    expect(result).to     be_kind_of(String)
    expect(result).to_not be_blank

    s.disconnect
  end

  it "#mount_share is unique" do
    expect(described_class.new(:uri => '/tmp/abc').mount_share).to_not eq(described_class.new(:uri => '/tmp/abc').mount_share)
  end

  it ".runcmd will retry with sudo if needed" do
    cmd = "mount X Y"

    # TODO:  Delete me
    RSpec::Mocks.configuration.allow_message_expectations_on_nil = true

    expect(described_class).to receive(:`).once.with("#{cmd} 2>&1")
    expect(described_class).to receive(:`).with("sudo #{cmd} 2>&1")
    expect($CHILD_STATUS).to receive(:exitstatus).once.and_return(1)
    `#{Gem.ruby} -v` # HACK

    described_class.runcmd(cmd)
  end
end
