require 'util/mount/miq_generic_mount_session'

class MiqS3Session < MiqGenericMountSession
  def initialize(log_settings)
    super(log_settings)
    # NOTE: This line to be removed once manageiq-ui-class region change implemented.
    @settings[:region] = "us-east-1" if @settings[:region].nil?
    raise "username, password, and region are required values!" if @settings[:username].nil? || @settings[:password].nil? || @settings[:region].nil?
    @host       = URI(@settings[:uri]).host
    @mount_path = URI(@settings[:uri]).path
  end

  def self.raw_disconnect(mnt_point)
    return if mnt_point.nil?
    FileUtils.rm_rf(mnt_point) if File.exist?(mnt_point)
  end

  def uri_to_local_path(remote_file)
    # Strip off the leading "s3:/" from the URI"
    File.join(@mnt_point, URI(remote_file).host, URI(remote_file).path)
  end

  def uri_to_object_path(remote_file)
    # Strip off the leading "s3://" and the bucket name from the URI"
    # Also remove the leading delimiter.
    URI(remote_file).path[1..-1]
  end

  def add(local_file, uri)
    require 'aws-sdk'
    bucket_name = URI(uri).host
    if (dump_bucket = s3.bucket(bucket_name)).exists?
      logger.debug("Found bucket #{bucket_name}")
    else
      logger.debug("Bucket #{bucket_name} does not exist, creating.")
      dump_bucket.create
    end
    object_file = uri_to_object_path(uri)
    # write dump file to s3
    logger.debug("Writing [#{local_file}] to Bucket [#{bucket_name}] using object file name [#{object_file}]")
    begin
      dump_bucket.object(object_file).upload_file(local_file)
    rescue Aws::S3::Errors::AccessDenied, Aws::S3::Errors::Forbidden => err
      disconnect
      logger.error("Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}")
      msg = "Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      disconnect
      logger.error("Error uploading #{local_file} to S3 bucket #{bucket_name}. #{err}")
      msg = "Error uploading #{local_file} to S3 bucket #{bucket_name}. #{err}"
      raise err, msg, err.backtrace
    end
  end

  def download(local_file, remote_file)
    require 'aws-sdk'
    bucket_name = URI(remote_file).host
    if (dump_bucket = s3.bucket(bucket_name)).exists?
      logger.debug("Found bucket #{bucket_name}")
    else
      logger.error("Bucket #{bucket_name} does not exist, unable to download [#{remote_file}].")
      raise "Bucket #{bucket_name} does not exist, unable to download [#{remote_file}]."
    end
    object_file = uri_to_object_path(remote_file)
    local_file  = File.join(@mnt_point, File.basename(local_file))
    logger.debug("Downloading [#{object_file}] from bucket [#{bucket_name}] to local file [#{local_file}]")
    begin
      dump_bucket.object(object_file).download_file(local_file)
    rescue Aws::S3::Errors::AccessDenied, Aws::S3::Errors::Forbidden => err
      disconnect
      logger.error("Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}")
      msg = "Access to S3 bucket #{bucket_name} restricted.  Try a different name. #{err}"
      raise err, msg, err.backtrace
    rescue => err
      disconnect
      logger.error("Error downloading #{remote_file} from S3. #{err}")
      msg = "Error downloading #{remote_file} from S3. #{err}"
      raise err, msg, err.backtrace
    end
    local_file
  end

  private

  def s3
    @s3 ||= Aws::S3::Resource.new(:region => @settings[:region], :access_key_id => @settings[:username], :secret_access_key => @settings[:password])
  end
end
