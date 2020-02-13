require "manageiq/file_storage/object_storage/ftp"

describe ManageIQ::FileStorage::ObjectStorage::FTP, :with_ftp_server do
  subject         { described_class.new(ftp_creds.merge(:uri => "ftp://localhost")) }
  let(:ftp_creds) { { :username => "ftpuser", :password => "ftppass" } }

  it_behaves_like "a file storage", "ftp"
end
