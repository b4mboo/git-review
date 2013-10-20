git-review
----------
[![Build Status](https://travis-ci.org/b4mboo/git-review.png?branch=master)](https://travis-ci.org/b4mboo/git-review)

Manage review workflow for projects hosted on GitHub (using pull requests).

## Commands


### list (--reverse)

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


### show ID

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


### browse ID

```
$ git review browse 42
> open a browser and go to request #42's web page
```


### checkout ID (--no-branch)

```
$ git review checkout 42
> checkout remote branch from request #42 and create a local branch from it
```

```
$ git review checkout 42 --no-branch
> checkout changes from request #42 to your local repository in a headless state
```


### approve ID

```
$ git review approve 42
> approve request #42 as reviewed by adding a standard comment
```


### merge ID

```
$ git review merge 42
> accept request #42 by merging it
```


### close ID

```
$ git review close 42
> close request #42
```


### prepare (--new) (feature name)

```
$ git review prepare
> create a new local branch with review prefix to base a new request upon
```


### create (--upstream)

```
$ git review create
> create a new request by creating all necessary local and remote branches

$ git review create --upstream
> send a new request to the upstream repository when working on a forked repo
```


### clean (ID) (--force) / (--all)

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
> delete all obsolete branches (does not allow --force)
```

Installation
------------

To install it via RubyGems.org simply do:

    gem install git-review


Wiki
----

For more information visit the [wiki](https://github.com/b4mboo/git-review/wiki).


Thanks
------

A fork of Scott Chacon's [git-pulls](https://github.com/schacon/git-pulls) was
used as starting point for this gem. Thank you, Scott for the initial work and
above all for open sourcing it and allowing me to play with it.
