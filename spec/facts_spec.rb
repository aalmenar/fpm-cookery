require 'spec_helper'
require 'fpm/cookery/facts'

shared_context "mock facts" do |facts = {}|
  before do
    facts.each_pair do |k, v|
      allow(Facter).to receive(:value).with(k).and_return(v)
    end
  end
end

describe "Facts" do
  before do
    FPM::Cookery::Facts.reset!
  end

  describe "arch" do
    include_context "mock facts", { :architecture => 'x86_64' }

    it "returns the current architecture" do
      expect(FPM::Cookery::Facts.arch).to eq(:x86_64)
    end
  end

  describe "lsbcodename" do
    context "where lsbcodename is present" do
      include_context "mock facts", { :lsbcodename => 'trusty' }

      it "returns the current platforms codename" do
        expect(FPM::Cookery::Facts.lsbcodename).to eq :trusty
      end
    end

    context "where lsbcodename is not present but lsbdistcodename is" do
      include_context "mock facts", { :lsbcodename => nil, :lsbdistcodename => 'trusty' }

      it "returns nil" do
        expect(FPM::Cookery::Facts.lsbcodename).to eq :trusty
      end
    end
  end

  describe "platform" do
    include_context "mock facts", { :operatingsystem => 'CentOS' }

    it "is using Facter to autodetect the platform" do
      expect(FPM::Cookery::Facts.platform).to eq(:centos)
    end

    it "can be set" do
      FPM::Cookery::Facts.platform = 'CentOS'
      expect(FPM::Cookery::Facts.platform).to eq(:centos)
    end
  end

  describe "osrelease" do
    include_context "mock facts", { :operatingsystemrelease => '6.5' }

    it "returns the operating system release version" do
      expect(FPM::Cookery::Facts.osrelease).to eq('6.5')
    end
  end

  describe "osmajorrelease" do
    include_context "mock facts", { :operatingsystemmajrelease => '6' }

    it "returns the operating system major release version" do
      expect(FPM::Cookery::Facts.osmajorrelease).to eq('6')
    end
  end

  describe "target" do

    describe "with platform Scientific" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'Scientific'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform CentOS" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'CentOS'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform RedHat" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'RedHat'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform Fedora" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'Fedora'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform Amazon" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'Amazon'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform OracleLinux" do
      it "returns rpm" do
        FPM::Cookery::Facts.platform = 'OracleLinux'
        expect(FPM::Cookery::Facts.target).to eq(:rpm)
      end
    end

    describe "with platform Debian" do
      it "returns deb" do
        FPM::Cookery::Facts.platform = 'Debian'
        expect(FPM::Cookery::Facts.target).to eq(:deb)
      end
    end

    describe "with platform Ubuntu" do
      it "returns deb" do
        FPM::Cookery::Facts.platform = 'Ubuntu'
        expect(FPM::Cookery::Facts.target).to eq(:deb)
      end
    end

    describe "with platform Darwin" do
      it "returns osxpkg" do
        FPM::Cookery::Facts.platform = 'Darwin'
        expect(FPM::Cookery::Facts.target).to eq(:osxpkg)
      end
    end

    describe "with platform Alpine" do
      it "returns apk" do
        FPM::Cookery::Facts.platform = 'Alpine'
        expect(FPM::Cookery::Facts.target).to eq(:apk)
      end
    end

    describe "with an unknown platform" do
      it "returns nil" do
        FPM::Cookery::Facts.platform = '___X___'
        expect(FPM::Cookery::Facts.target).to eq(nil)
      end
    end

    it "can be set" do
      FPM::Cookery::Facts.target = 'rpm'
      expect(FPM::Cookery::Facts.target).to eq(:rpm)
    end
  end
end
