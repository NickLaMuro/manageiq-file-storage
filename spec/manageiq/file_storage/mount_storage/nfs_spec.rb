require "manageiq/file_storage/mount_storage/nfs"

NFS_SPEC = ManageIQ::FileStorage::MountStorage::NFS

describe NFS_SPEC, :with_nfs_server,:if => NfsSingletonServer.run_specs? do
  subject         { described_class.new(:uri => "nfs://192.168.99.99") }
  # let(:ftp_creds) { { :username => "ftpuser", :password => "ftppass" } }

  it_behaves_like "a file storage", "nfs"
end
