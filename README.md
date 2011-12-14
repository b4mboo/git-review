git-review
----------

Manage review workflow for projects hosted on GitHub (using pull requests).

    $ git review list
    Pending requests for 'b4mboo/git-review/master'
    ID      Updated    Comments  Title
    42      14-Jul-11  0         [Review] Request from 'mess110' @ 'b4mboo/git-review/documentation
    23      13-Jul-11  8         [Review] Request from 'mess110' @ 'b4mboo/git-review/new_feature

    $ git review list --reverse
    Pending requests for 'b4mboo/git-review/master'
    ID      Updated    Comments  Title
    23      13-Jul-11  8         [Review] Request from 'mess110' @ 'b4mboo/git-review/new_feature
    42      14-Jul-11  0         [Review] Request from 'mess110' @ 'b4mboo/git-review/documentation

    $ git review show 42
    > [summary]
    > [diffstat]

    $ git review show 42 --full
    > [summary]
    > [full diff]

    $ git review browse 42
    > go to web page

    $ git review checkout 42
    > checkout changes from request #42 to your local repository

    $ git review merge 42
    > accept request #42 by merging it

    $ git review close 42
    > close request #42

    $ git review prepare
    > create a new local branch to base a new request upon

    $ git review create
    > create a new request


Installation
------------

To install it via Rubygems, you might need to add Gemcutter to your Rubygems sources:

    gem install gemcutter --source http://gemcutter.org

Afterwards simply do:

    gem install git-review

(Prefix with `sudo` if necessary)

To be able to use all of git-review's features you have set up your git config for GitHub.

    git config --global github.login your_github_login_1234567890
    git config --global github.token your_github_token_1234567890

You can find your API token on the [account](https://github.com/account) page.

If you want to use git-review with a private GitHub instance (http://fi.github.com/), set the github.endpoint config value to your internal host.

    git config --global github.endpoint github.mycompany.com


Wiki
----

For more information visit the [wiki](https://github.com/b4mboo/git-review/wiki).
