# Assumptions are basically stubs that allow the actual specs to focus on what
# is relevant to the test at hand. It improves readability and implies that
# these assumptions have been made to navigate through the code.

def assume_silence
  GitReview.any_instance.stub(:puts)
end

def assume(name, value)
  subject.instance_variable_set name, value
end

def assume_arguments(*arguments)
  assume :@args, arguments
end

def assume_requests(*requests)
  assume :@current_requests, requests
end

def assume_no_requests
  assume :@current_requests, []
end

def assume_added_to(collection, new_item)
  array = subject.instance_variable_get(collection) || []
  array << new_item
  subject.instance_variable_set collection, array
end

def assume_valid_request_id
  assume :@args, [request_id]
  assume :@current_requests, [request]
end

def assume_no_open_requests
  assume :@current_requests, []
end

def assume_on_github(request)
  github.stub(:pull_request).with(source_repo, request_id).and_return(request)
end

def assume_on_master
  subject.stub(:git_call).with('branch').and_return("* master\n")
end

def assume_on_feature_branch
  subject.stub(:git_call).with('branch').and_return(
    " master\n* #{branch_name}\n"
  )
end

def assume_on_master_then_feature_branch
  subject.stub(:git_call).with('branch').twice.and_return(
    "* master\n", " master\n* #{branch_name}\n"
  )
end

def assume_change_branches(direction = nil)
  if direction
    branches = ["* master\n  #{branch_name}\n", "  master\n* #{branch_name}\n"]
    branches.reverse! if direction.keys.first == :feature
    subject.stub(:git_call).with('branch').and_return(*branches)
  end
  subject.stub(:git_call).with(include 'checkout')
end

def assume_merged(merged = true)
  subject.stub(:merged?).with(head_sha).and_return(merged)
end

def assume_uncommitted_changes(changes_exist = true)
  changes = changes_exist ? ['changes'] : []
  subject.stub(:git_call).with('diff HEAD').and_return(changes)
end

def assume_local_commits(commits_exist = true)
  commits = commits_exist ? ['commits'] : []
  subject.stub(:git_call).with('cherry master').and_return(commits)
end

def assume_title_and_body_set
  subject.stub(:create_title_and_body).and_return([title, body])
end

def assume_create_pull_request
  subject.stub(:git_call).with(
    "push --set-upstream origin #{branch_name}", false, true
  )
  subject.stub :update
  github.stub(:create_pull_request).with(
    source_repo, 'master', branch_name, title, body
  )
end

def assume_pruning
  subject.stub(:git_call).with('remote prune origin')
end

def assume_valid_command(valid = true)
  assume_arguments 'command'
  subject.stub(:respond_to?).and_return(valid)
end
