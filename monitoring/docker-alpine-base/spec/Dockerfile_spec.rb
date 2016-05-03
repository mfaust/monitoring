require "docker"
require "serverspec"

describe "Dockerfile" do
  before(:all) do
    @image = Docker::Image.build_from_dir('.')

    set :os, family: :redhat
    set :backend, :docker
    set :docker_image, @image.id
  end

  describe file('/etc/alpine-release') do
    it { should be_file }
  end

end
