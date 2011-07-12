git-review
==============

Makes it easy to manage code review on GitHub.

    $ git review list
    Open Pull Requests for schacon/git-reference
    19   10/26 0  Fix tag book link    ComputerDruid:fix-ta
    18   10/21 0  Some typos fixing.   mashingan:master    
    
    $ git review list --reverse
    Open Pull Requests for schacon/git-reference
    18   10/21 0  Some typos fixing.   mashingan:master    
    19   10/26 0  Fix tag book link    ComputerDruid:fix-ta

    $ git review show 1
    > [summary]
    > [diffstat]

    $ git review show 1 --full
    > [summary]
    > [full diff]

    $ git review browse 1
    > go to web page

    $ git review merge 1
    > merge pull request #1

    $ git review create
    > create a new pull request
    
Private repositories
----------------

To manage pull requests for your private repositories you have set up your git config for github 

    $ git config --global github.user your_gitubusername
    $ git config --global github.token your_githubtoken123456789
    
You can find your API token on the [account](https://github.com/account) page.

Using git-review with GitHub Enterprise
--------------------------------------

If you want to use the git-review script with a private GitHub install, set the
github.host config value to your internal host.

    $ git config --global github.host github.mycompany.com

Installation
===============

Simply install it via Rubygems:

    gem install git-review

(Prefix with `sudo` if necessary)
