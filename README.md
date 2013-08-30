git-review
----------
[![Build Status](https://travis-ci.org/b4mboo/git-review.png?branch=master)](https://travis-ci.org/b4mboo/git-review)

Manage review workflow for projects hosted on GitHub (using pull requests).

## Commands


### list

```
$ git review list
Pending requests for 'b4mboo/git-review/master'
ID      Updated    Comments  Title
42      14-Jul-11  0         [Review] Request from 'mess110' @ 'b4mboo/git-review/documentation
23      13-Jul-11  8         [Review] Request from 'mess110' @ 'b4mboo/git-review/new_feature
```

```
$ git review list --reverse
Pending requests for 'b4mboo/git-review/master'
ID      Updated    Comments  Title
23      13-Jul-11  8         [Review] Request from 'mess110' @ 'b4mboo/git-review/new_feature
42      14-Jul-11  0         [Review] Request from 'mess110' @ 'b4mboo/git-review/documentation
```


### show

```
$ git review show 42
> [summary]
> [diffstat]
> [discussion]
```

```
$ git review show 42 --full
> [summary]
> [full diff]
> [discussion]
```


### browse

```
$ git review browse 42
> go to web page
```


### checkout

```
$ git review checkout 42
> checkout changes from request #42 to your local repository in a headless state
```

```
$ git review checkout 42 --branch
> checkout remote branch from request #42 and create a local branch from it
```


### approve

```
$ git review approve 42
> approve request #42 as reviewed by adding a standard comment
```


### merge

```
$ git review merge 42
> accept request #42 by merging it
```


### close

```
$ git review close 42
> close request #42
```


### prepare

```
$ git review prepare
> create a new local branch to base a new request upon
```


### create

```
$ git review create
> create a new request by creating all necessary local and remote branches

$ git review create --upstream
> send a new request to the upstream when working on a forked repo
```


### clean

```
$ git review clean 42
> delete local and remote branches for that request
```

```
$ git review clean 42 --force
> delete branches even if they contain unmerged commits
```

```
$ git review clean --all
> delete all obsolete branches
```

Installation
------------

To install it via Rubygems.org simply do:

    gem install git-review

(Prefix with `sudo` if necessary)

To be able to use all of git-review's features you have set up your git config for GitHub.

    git config --global github.login your_github_login_1234567890
    git config --global github.password your_github_password_1234567890


Wiki
----

For more information visit the [wiki](https://github.com/b4mboo/git-review/wiki).


Thanks
------

A fork of Scott Chacon's [git-pulls](https://github.com/schacon/git-pulls) was
used as starting point for this gem. Thank you, Scott for the initial work and
above all for open sourcing it and allowing me to play with it.
