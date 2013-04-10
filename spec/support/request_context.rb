unless RSpec.world.shared_example_groups[:request]

  shared_context :request do

    subject { GitReview.new }

    let(:github) { mock :github }
    let(:source_repo) { '/' }
    let(:request_id) { 42 }
    let(:request_url) { 'some/path/to/github' }
    let(:head_sha) { 'head_sha' }
    let(:head_ref) { 'head_ref' }
    let(:head_label) { 'head_label' }
    let(:head_repo) { 'path/to/repo' }
    let(:title) { 'some title' }
    let(:body) { 'some body' }
    let(:feature_name) { 'some_name' }
    let(:branch_name) { "review_#{Time.now.strftime("%y%m%d")}_#{feature_name}"}


    let(:request) {
      request = Request.new(
        :number => request_id,
        :state => 'open',
        :title => title,
        :html_url => request_url,
        :updated_at => Time.now.to_s,
        :head => {
          :sha => head_sha,
          :ref => head_ref,
          :label => head_label,
          :repo => head_repo
        },
        :comments => 0,
        :review_comments => 0
      )
      assume_on_github request
      request
    }

    before :each do
      # Stub external dependency @github (= remote server).
      subject.instance_variable_set(:@github, github)
    end

  end

end
