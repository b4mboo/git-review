require_relative '../../spec_helper'

describe 'Provider base' do

  subject { ::GitReview::Provider::Base }

  let(:settings) { ::GitReview::Settings.any_instance }

end
