require 'hashie'

shared_context 'request_context' do

  let(:source_repo) { '/' }
  let(:request_number) { 42 }
  let(:html_url) { 'some/path/to/github' }
  let(:head_sha) { 'head_sha' }
  let(:head_label) { 'head_label' }
  let(:head_repo) { 'path/to/repo' }
  let(:title) { 'some title' }
  let(:body) { 'some body' }
  let(:feature_name) { 'some_name' }
  let(:head_ref) { "review_010113_#{feature_name}"}
  let(:custom_target_name) { 'custom_target_name' }
  let(:branch_name) { head_ref }

  let(:request) {
    Hashie::Mash.new(
        :html_url => html_url,
        :number => request_number,
        :state => 'open',
        :title => title,
        :body => body,
        :updated_at => Time.now.to_s,
        :head => {
          :sha => head_sha,
          :ref => head_ref,
          :label => head_label,
          :repo => head_repo,
          :user => { :login => 'user' }
        },
        :comments => 0,
        :review_comments => 0
    )
  }

end
