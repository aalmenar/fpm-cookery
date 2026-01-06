require 'shellwords'
require 'fpm/cookery/facts'
require 'fpm/cookery/log'

module FPM
  module Cookery
    class DependencyInspector
      BACKENDS = {
        :debian => {
          :check   => lambda { |pkg| system("dpkg-query -W -f='${Status}' #{esc(pkg)} 2>/dev/null | grep -q 'install ok installed'") },
          :install => lambda { |pkg| system("apt-get install -y #{esc(pkg)}") }
        },
        :redhat => {
          :check   => lambda { |pkg| system("rpm -q #{esc(pkg)} >/dev/null 2>&1") },
          :install => lambda { |pkg| system("yum install -y #{esc(pkg)}") }
        },
        :suse => {
          :check   => lambda { |pkg| system("rpm -q #{esc(pkg)} >/dev/null 2>&1") },
          :install => lambda { |pkg| system("zypper install -y #{esc(pkg)}") }
        },
        :alpine => {
          :check   => lambda { |pkg| system("apk info -e #{esc(pkg)} >/dev/null 2>&1") },
          :install => lambda { |pkg| system("apk add #{esc(pkg)}") }
        },
        :archlinux => {
          :check   => lambda { |pkg| system("pacman -Q #{esc(pkg)} >/dev/null 2>&1") },
          :install => lambda { |pkg| system("pacman -S --noconfirm #{esc(pkg)}") }
        }
      }.freeze

      class << self
        def verify!(depends, build_depends)
          backend = current_backend

          unless backend
            Log.warn "Unsupported platform '#{Facts.osfamily}'. Automatic dependency installation disabled."
            return
          end

          Log.info "Verifying build_depends and depends"

          missing = missing_packages(build_depends + depends)

          if missing.length == 0
            Log.info "All build_depends and depends packages installed"
          else
            Log.info "Missing/wrong version packages: #{missing.join(', ')}"
            if Process.euid != 0
              Log.error "Not running as root; please run 'sudo fpm-cook install-deps' to install dependencies."
              exit 1
            else
              Log.info "Running as root; installing missing/wrong version build_depends and depends"
              missing.each do |package|
                install_package(package)
              end
            end
          end
        end

        def missing_packages(*pkgs)
          pkgs.flatten.reject do |package|
            package_installed?(package)
          end
        end

        def package_installed?(package)
          Log.info("Verifying package: #{package}")
          return true unless package_suitable?(package)

          backend = current_backend
          return true unless backend

          backend[:check].call(package.to_s)
        end

        def install_package(package)
          Log.info("Installing package: #{package}")
          return unless package_suitable?(package)

          backend = current_backend
          unless backend
            Log.fatal "Cannot install package: unsupported platform '#{Facts.osfamily}'"
            exit 1
          end

          success = backend[:install].call(package.to_s)
          unless success
            Log.fatal "Failed to install package '#{package}'"
            exit 1
          end
        end

        def package_suitable?(package)
          # How can we handle "or" style depends?
          if package.to_s =~ / \| /
            Log.warn "Required package '#{package}' is an 'or' string; not attempting to find/install a package to satisfy"
            return false
          end

          # We can't handle >=, <<, >>, <=, <, >
          if package.to_s =~ />=|<<|>>|<=|<|>/
            Log.warn "Required package '#{package}' has a relative version requirement; not attempting to find/install a package to satisfy"
            return false
          end
          true
        end

        private

        def current_backend
          BACKENDS[Facts.osfamily]
        end

        def esc(str)
          Shellwords.escape(str.to_s)
        end
      end

      # Make esc available to lambdas
      def self.esc(str)
        Shellwords.escape(str.to_s)
      end
    end
  end
end
