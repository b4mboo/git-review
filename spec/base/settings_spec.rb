require 'spec_helper'

describe Settings do

  subject { Settings.instance }

  let(:home_dir) { '/home/foo/' }
  let(:config_file) { home_dir + '.git_review.yml' }


  it 'reads options from a YML file' do
    assume_config_file_exists
    YAML.should_receive(:load_file).with(config_file)
    subject
  end

  it 'allows to save changes back to the file' do
    assume_config_file_loaded
    File.should_receive(:open).with(config_file, 'w')
    subject.save!
  end

  it 'offers convenient access to config options' do
    assume_config_file_loaded
    value = 'bar'
    subject.foo = value
    subject.instance_variable_get(:@config)['foo'].should == value
    subject.foo.should == value
  end

end
