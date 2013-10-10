require_relative '../spec_helper'

describe 'Settings' do

  let(:home_dir) { '/home/foo/' }
  let(:config_file) { home_dir + '.git_review.yml' }

  describe '#initialize' do

    subject { ::GitReview::Settings.new }

    it 'reads options from a YML file' do
      subject.stub(:file).and_return(config_file)
      File.stub(:exists?).with(config_file).and_return(true)
      YAML.should_receive(:load_file).with(config_file)
      subject.foobar
    end

  end

  context 'when config file is loaded' do

    subject { ::GitReview::Settings }
    let(:value) { "foobar" }

    before(:each) do
      Dir.stub(:home).and_return(home_dir)
      File.stub(:exists?).with(config_file).and_return(true)
      YAML.stub(:load_file).with(config_file)
    end

    it 'allows to save changes back to the file' do
      File.should_receive(:write).with(config_file, "--- {}\n")
      subject.new.save!
    end

    it 'offers convenient access to config options' do
      setting = subject.new
      setting.foo = value
      setting.instance_variable_get(:@config)[:foo].should == value
      setting.foo.should eq value
    end

  end

end
