require 'net/ftp'

module FTPSpecMatcherHelper
  def with_connection
    Net::FTP.open("localhost") do |ftp|
      ftp.login("ftpuser", "ftppass")
      yield ftp
    end
  end

  # Do searches with Net::FTP instead of normal directory scan (even though
  # we could) just so we are exercising the FTP interface as expected.
  def list_in_ftp(file_or_dir)
    with_connection do |ftp|
      begin
        ftp.nlst(to_path_string(file_or_dir))
      rescue Net::FTPPermError
        []
      end
    end
  end

  # Do searches with Net::FTP instead of normal directory scan (even though
  # we could) just so we are exercising the FTP interface as expected.
  def size_on_ftp(file_or_dir)
    path = to_path_string(file_or_dir)
    with_connection do |ftp|
      begin
        ftp.size(path)
      rescue Net::FTPPermError
        0
      end
    end
  end

  def to_path_string(path)
    (path.respond_to?(:path) && path.path) || URI.split(path.to_s)[5]
  end
end
