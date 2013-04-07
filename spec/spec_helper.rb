$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'


def assume(name, value)
  subject.instance_variable_set name, value
end

def assume_on_github(request)
  github.stub(:pull_request).with(source_repo, request_id).and_return(request)
end

def assume_merged(value)
  subject.stub(:merged?).with(head_sha).and_return(value)
end

def assume_a_valid_request_id
  assume :@args, [request_id]
  assume :@current_requests, [request]
end

def assume_added_to(collection, new_item)
  array = subject.instance_variable_get(collection) || []
  array << new_item
  subject.instance_variable_set collection, array
end
