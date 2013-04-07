$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'


def assume(name, value)
  subject.instance_variable_set name, value
end

def assume_added_to(collection, new_item)
  array = subject.instance_variable_get(collection) || []
  array << new_item
  subject.instance_variable_set collection, array
end

def assume_on_github(request)
  github.stub(:pull_request).with(source_repo, request_id).and_return(request)
end

def assume_on_master
  subject.stub(:git_call).with('branch').and_return("* master\n")
end

def assume_merged(value)
  subject.stub(:merged?).with(head_sha).and_return(value)
end

def assume_change_branches
  subject.stub(:git_call).with('branch').twice.and_return(
    "* master\n", " master\n* #{branch_name}\n"
  )
  subject.stub(:git_call).with(include 'checkout')
end

def assume_a_valid_request_id
  assume :@args, [request_id]
  assume :@current_requests, [request]
end

def assume_uncommitted_changes(change_exists)
  changes = change_exists ? ['changes'] : []
  subject.stub(:git_call).with('diff HEAD').and_return(changes)
end
