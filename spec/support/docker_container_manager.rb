require "json"
require "docker-api"

class DockerContainerManager
  @configs    = {}
  @containers = {}

  def self.[](container_name)
    @containers[container_name]
  end

  # Configure a container instance that will be managed by this class
  def self.configure(container_name = nil, &block)
    return @configs[container_name] if @configs[container_name]

    @configs[container_name] = ContainerConfig.new(container_name, &block)
  end

  def self.start(container_name)
    container = @containers[container_name]
    config    = @configs[container_name]

    return if container # already started (TODO:  status check?)

    # TODO:  Add if needed
    # if config.dockerfile
    # end

    fetch_image config.image
    container = Docker::Container.create(config.create_params)

    unless config.files.empty?
      config.files.each do |filename, content|
        container.store_file(filename, content)
      end
    end

    container.start
    container.exec(["chmod", "644", config.files.keys.join(" ")], :detach => true)

    @containers[config.name] = container
  end

  def self.stop(container_name)
    container = @containers[container_name]

    return unless container

    container.delete("force" => true)
    @containers.delete(container_name)
  end

  def self.fetch_image(image)
    image_exists = Docker::Image.all("filters" => {"reference"=> {image => true}}.to_json).first

    return if image_exists

    image = Docker::Image.create('fromImage' => image)
  end

  # DSL for a container instance configuration
  class ContainerConfig
    attr_accessor :cmd, :dockerfile, :entrypoint, :image, :name
    attr_reader   :env_vars, :files, :ports, :volumes

    def initialize(name = nil, &block)
      @name     = name
      @env_vars = {}
      @files    = {}
      @ports    = {}
      @volumes  = {}

      instance_eval(&block) if block_given?
    end

    def create_params
      params = {}

      params["name"]       = name        if name
      params["Image"]      = image       if image
      params["Cmd"]        = cmd         if cmd
      params["Entrypoint"] = entrypoint  if entrypoint

      unless env_vars.empty?
        params["Env"] = []
        env_vars.each do |name, val|
          params["Env"] << "#{name}=#{val}"
        end
      end

      unless ports.empty?
        params["ExposedPorts"]               ||= {}
        params["HostConfig"]                 ||= {}
        params["HostConfig"]["PortBindings"] ||= {}

        ports.each do |docker_port, host_port|
          params["ExposedPorts"]["#{docker_port}/tcp"]               = {}
          params["HostConfig"]["PortBindings"]["#{docker_port}/tcp"] = [
            {"HostPort" => host_port.to_s}
          ]
        end
      end

      puts params.inspect
      params
    end

    def cmd(*args)
      args.empty? ? @cmd : @cmd = args
    end

    def entrypoint(*args)
      args.empty? ? @entrypoint : @entrypoint = args
    end

    # Configure an ENV variable
    #
    def env(var_name, var_value)
      @env_vars[var_name] = var_value
    end

    # Add a file to the container after boot
    def file(filename, content)
      @files[filename] = content
    end

    # Configure or view the @image variable
    #
    def image(image = nil)
      image ? @image = image : @image
    end

    # Configure a port mapping
    #
    # +host_port+ will be configured to the +docker_port+ if it is left blank.
    #
    def port(host_port, docker_port = nil)
      docker_port       ||= host_port
      @ports[docker_port] = host_port
    end

    # Configure a volume mapping
    #
    def volume(host_config, container_bind)
      @volumes[host_config] = container_bind
    end
  end
end
