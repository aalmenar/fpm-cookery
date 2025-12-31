require 'fpm/cookery/facts'
require 'fpm/cookery/log'

PUPPET_AVAILABLE = false

begin
  require 'puppet'

  # Init Puppet before using it
  Puppet.initialize_settings

  # Load required Puppet components
  require 'puppet/resource'
  require 'puppet/transaction/report'

  # Puppet 8.x has a bug where puppet/resource.rb references Puppet::Resource::Type
  # but doesn't explicitly require it. We need to ensure it's loaded before
  # Puppet::Resource.new() is called.
  begin
    require 'puppet/resource/type'
  rescue LoadError => e
    # If the file doesn't exist, try to check if the constant is available anyway
    unless defined?(Puppet::Resource::Type)
      Log.warn "Puppet::Resource::Type could not be loaded: #{e.message}"
      raise "Puppet::Resource::Type is required but not available"
    end
  end

  # Verify the constant is actually defined
  unless defined?(Puppet::Resource::Type)
    raise "Puppet::Resource::Type constant is not defined after loading puppet/resource/type"
  end

  PUPPET_AVAILABLE = true
rescue Exception => e
  # Log the error for debugging
  Log.warn "Failed to load Puppet: #{e.class}: #{e.message}" if defined?(Log)
  Log.warn "Backtrace: #{e.backtrace.first(5).join("\n")}" if defined?(Log) && e.backtrace
end

module FPM
  module Cookery
    class DependencyInspector
      def self.verify!(depends, build_depends)
        unless defined?(Puppet::Resource)
          Log.warn "Unable to load Puppet. Automatic dependency installation disabled."
          return
        end

        Log.info "Verifying build_depends and depends with Puppet"

        missing = missing_packages(build_depends + depends)

        if missing.length == 0
          Log.info "All build_depends and depends packages installed"
        else
          Log.info "Missing/wrong version packages: #{missing.join(', ')}"
          if Process.euid != 0
            Log.error "Not running as root; please run 'sudo fpm-cook install-deps' to install dependencies."
            exit 1
          else
            Log.info "Running as root; installing missing/wrong version build_depends and depends with Puppet"
            missing.each do |package|
              self.install_package(package)
            end
          end
        end

      end

      def self.missing_packages(*pkgs)
        pkgs.flatten.reject do |package|
          self.package_installed?(package)
        end
      end

      def self.package_installed?(package)
        Log.info("Verifying package: #{package}")
        return unless self.package_suitable?(package)

        # Use Puppet in noop mode to see if the package exists
        Puppet[:noop] = true
        resource = Puppet::Resource.new("package", package, :parameters => {
          :ensure => "present"
        })
        result    = Puppet::Resource.indirection.save(resource)[1]
        !result.resource_statuses.values.first.out_of_sync
      end

      def self.install_package(package)
        Log.info("Installing package: #{package}")
        return unless self.package_suitable?(package)

        # Use Puppet to install a package
        Puppet[:noop] = false
        resource = Puppet::Resource.new("package", package, :parameters => {
          :ensure => "present"
        })
        result = Puppet::Resource.indirection.save(resource)[1]
        failed = result.resource_statuses.values.first.failed
        if failed
          Log.fatal "While processing depends package '#{package}':"
          result.logs.each {|log_line| Log.fatal log_line}
          exit 1
        else
          result.logs.each {|log_line| Log.info log_line}
        end
      end

      def self.package_suitable?(package)
        # How can we handle "or" style depends?
        if package =~ / \| /
          Log.warn "Required package '#{package}' is an 'or' string; not attempting to find/install a package to satisfy"
          return false
        end

        # We can't handle >=, <<, >>, <=, <, >
        if package =~ />=|<<|>>|<=|<|>/
          Log.warn "Required package '#{package}' has a relative version requirement; not attempting to find/install a package to satisfy"
          return false
        end
        true
      end

    end
  end
end
