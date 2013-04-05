$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')
require 'git-review'


def assume(name, value)
  subject.instance_variable_set name, value
end

# Adds given item(s) to an instance variable that holds an array.
# NOTE: Not sure if I will still need this. I'll keep it around for the moment.
def add_to(collection, new_item)
  # Fetch or initialize the instance variable.
  array = subject.instance_variable_get(collection) || []
  # Allow to add an array of items.
  # NOTE: This of course means that we can't add a nested array.
  if new_item.is_a? Array
    array += new_item
  else
    array << new_item
  end
  # Write new value.
  subject.instance_variable_set collection, array
end
