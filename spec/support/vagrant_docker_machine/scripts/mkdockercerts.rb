require 'uri'
require 'fileutils'
require 'openssl'

# Many of the cert configuration steps for this generator can be found here:
#
#   https://github.com/docker/machine/blob/b170508b/libmachine/cert/cert.go#L90
#
# Obviously, they have been adapted to work with the ruby OpenSSL interface,
# but they *should* generate equivalent keys.
#
class DockerMachineCertGenerator
  DEFAULT_VM_IP    = '192.168.99.99'

  VAGRANT_DIR      = File.expand_path('..', __dir__)
  CERTS_DIR        = File.join(VAGRANT_DIR, '.docker-certs')  # ~/.docker/machine/certs/
  CA_PATH          = File.join(CERTS_DIR, "ca.pem")           #   \ ca.pem
  CA_KEY_PATH      = File.join(CERTS_DIR, "ca-key.pem")       #   \ ca-key.pem
  CLIENT_CERT_PATH = File.join(CERTS_DIR, "cert.pem")         #   \ cert.pem
  CLIENT_KEY_PATH  = File.join(CERTS_DIR, "key.pem")          #   \ key.pem

                                                              # ~/docker/machine/machines/[NAME]/
  SERVER_CERT_PATH = File.join(CERTS_DIR, "server.pem")       #   \ server.pem
  SERVER_KEY_PATH  = File.join(CERTS_DIR, "server-key.pem")   #   \ server-key.pem

  CERT_FILES = [
    CA_PATH,
    CA_KEY_PATH,
    CLIENT_CERT_PATH,
    CLIENT_KEY_PATH,
    SERVER_CERT_PATH,
    SERVER_KEY_PATH,
  ]

  attr_accessor :cert_org

  def self.bootstrap(machine_ip = DEFAULT_VM_IP)
    new(machine_ip).generate if generate?
  end

  def self.generate?
    if Dir.exist? CERTS_DIR
      CERT_FILES.any? { |file| not File.exist? file }
    else
      true
    end
  end

  def self.clobber
    FileUtils.rm_rf CERTS_DIR
  end

  def initialize(machine_ip)
    @machine_ip = machine_ip
  end

  def generate
    mk_cert_dir
    generate_ca_cert
    generate_client_cert
    generate_server_cert
  end

  private

  def mk_cert_dir
    FileUtils.mkdir_p(CERTS_DIR, mode: 0700)
  end

  # defines a CA cert org of "$USER.<bootstrap>"
  def cert_org
    @cert_org ||= OpenSSL::X509::Name.parse("/O=#{File.basename(Dir.home)}.<bootstrap>")
  end

  def generate_ca_cert
    @root_ca, @root_key    = generate_base_cert
    @root_ca.issuer        = @root_ca.subject

    ef                     = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = @root_ca
    ef.issuer_certificate  = @root_ca

    key_usage_args = "digitalSignature, keyEncipherment, keyAgreement, keyCertSign"
    @root_ca.add_extension(ef.create_extension("keyUsage", key_usage_args, true))
    @root_ca.add_extension(ef.create_extension("basicConstraints", "CA:TRUE", true))
    @root_ca.sign(@root_key, OpenSSL::Digest::SHA256.new)

    File.open(CA_PATH, "wb")     { |f| f.write @root_ca.to_pem }
    File.open(CA_KEY_PATH, "wb") { |f| f.write @root_key.to_pem }
  end

  def generate_client_cert
    generate_generic_cert CLIENT_CERT_PATH, CLIENT_KEY_PATH
  end

  def generate_server_cert
    generate_generic_cert SERVER_CERT_PATH, SERVER_KEY_PATH, %W[localhost #{@machine_ip}]
  end

  def generate_generic_cert cert_path, cert_key_path, hosts = nil
    subject_alt_name_args  = ""
    cert, key              = generate_base_cert
    cert.issuer            = @root_ca.subject

    ef                     = OpenSSL::X509::ExtensionFactory.new
    ef.subject_certificate = cert
    ef.issuer_certificate  = @root_ca

    if hosts # server
      key_usage_args        = "digitalSignature, keyEncipherment, keyAgreement"
      subject_alt_name_args = generate_subject_alt_name_args hosts

      cert.add_extension(ef.create_extension("keyUsage", key_usage_args, true))
      cert.add_extension(ef.create_extension("extendedKeyUsage", "serverAuth", false))
    else     # client
      cert.add_extension(ef.create_extension("keyUsage", "digitalSignature", true))
      cert.add_extension(ef.create_extension("extendedKeyUsage", "clientAuth", false))
    end

    cert.add_extension(ef.create_extension("basicConstraints", "CA:FALSE", true))
    cert.add_extension(ef.create_extension("subjectAltName", subject_alt_name_args, false)) if hosts
    cert.sign(@root_key, OpenSSL::Digest::SHA256.new)

    File.open(cert_path, "wb")     { |f| f.write cert.to_pem }
    File.open(cert_key_path, "wb") { |f| f.write key.to_pem }
  end

  def generate_base_cert
    cert_key        = OpenSSL::PKey::RSA.new(2048)
    cert            = OpenSSL::X509::Certificate.new
    cert.version    = 2
    cert.serial     = OpenSSL::BN.new(rand(1 << 128))
    cert.subject    = cert_org.dup
    cert.public_key = cert_key.public_key
    cert.not_before = Time.now - 5 * 60 * 60                 # handles VM skew issues
    cert.not_after  = cert.not_before + 1080 * 24 * 60 * 60  # ~3 years validity

    [cert, cert_key]
  end

  def generate_subject_alt_name_args hosts = []
    hosts.each_with_object([]) do |host, subject_alt_name_args|
      begin
        IPAddr.new(host) # if this doesn't error, it is an IP Address
        subject_alt_name_args << "IP:#{host}"
      rescue IPAddr::InvalidAddressError # otherwise, it is a DNS based address
        subject_alt_name_args << "DNS:#{host}"
      end
    end.join(",")
  end
end
