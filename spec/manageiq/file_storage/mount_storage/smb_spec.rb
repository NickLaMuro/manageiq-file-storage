require "manageiq/file_storage/mount_storage/smb"

SMB_SPEC = ManageIQ::FileStorage::MountStorage::SMB

describe SMB_SPEC, :with_smb_server,:if => SMBSingletonServer.run_specs? do
  subject         { described_class.new(smb_creds.merge(:uri => smb_uri)) }
  let(:smb_uri)   { "smb://192.168.99.99/share" }
  let(:smb_creds) { { :username => "samba", :password => "samba" } }

  it_behaves_like "a file storage", "smb"
end
