require 'spec_helper'

describe GitReview do

  describe 'without any parameters' do

    it 'shows the help page' do
      GitReview.any_instance.should_receive(:puts).with(
        include('Usage: git review <command>')
      )
      GitReview.new
    end

 end

end

