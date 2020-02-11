require 'rake/clean'

VAGRANT_CWD    = File.expand_path(File.join(*%w[.. spec support vagrant_docker_machine]), __dir__)

require_relative File.join(VAGRANT_CWD, "scripts", "mkdockercerts.rb")

NFS_VOLUME_DIR = File.join VAGRANT_CWD, ".volumes", "nfs"
SMB_VOLUME_DIR = File.join VAGRANT_CWD, ".volumes", "smb"

CLEAN.add File.join(NFS_VOLUME_DIR, "*")
CLEAN.add File.join(SMB_VOLUME_DIR, "*")

CLOBBER.add DockerMachineCertGenerator::CERTS_DIR

COMPOSE_FILE = File.expand_path(".docker-compose", __dir__)

namespace :docker do
  namespace :compose do
    task :up => [NFS_VOLUME_DIR, SMB_VOLUME_DIR, 'docker:machine:env'] do
      sh 'docker-compose up -d'
    end

    desc "Remove docker-compose environment"
    task :down => ['docker:machine:env'] do
      sh 'docker-compose stop'
      sh 'docker-compose rm --force'
    end
  end

  desc "Setup container environment in docker"
  task :compose => "docker:compose:up"

  namespace :machine do
    task :up => [NFS_VOLUME_DIR, SMB_VOLUME_DIR, 'docker:machine:env'] do
      sh "vagrant up"
    end

    desc "Destroy docker VM"
    task :down => ['docker:machine:env'] do
      sh "vagrant destroy --force"
    end

    task :env do
      machine_ip = ENV['VAGRANT_DOCKER_MACHINE_IP'] || DockerMachineCertGenerator::DEFAULT_VM_IP

      ENV["VAGRANT_CWD"]       ||= VAGRANT_CWD
      ENV['DOCKER_HOST']       ||= "tcp://#{machine_ip}:2376"
      ENV['DOCKER_TLS_VERIFY'] ||= "1"
      ENV['DOCKER_CERT_PATH']  ||= DockerMachineCertGenerator::CERTS_DIR
    end

    task "env:force" do
      ENV.keys.grep(/DOCKER|VAGRANT_CWD/).each { |key| ENV[key] = nil }
      Rake::Task["docker:machine:env"].invoke
    end
  end

  desc "Spin up a VM to run docker"
  task :machine => "docker:machine:up"

  desc "Source instructions and script to configure docker env"
  task :source_env => ['docker:machine:env'] do
    ENV.keys.grep(/DOCKER|VAGRANT_CWD/).each do |env_key|
      puts %Q{export #{env_key}="#{ENV[env_key]}"}
    end
    puts "# Run this command to configure your shell:"
    puts "# # eval $(rake docker:source_env)"
  end

  # create volume dirs for specs
  directory NFS_VOLUME_DIR
  directory SMB_VOLUME_DIR
end
