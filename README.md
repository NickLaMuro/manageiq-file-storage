Manageiq::File::Storage
=======================

**VERY WIP and PLACHOLDER-y**

This is currently a place holder commit/branch/README while the project is
imported from `ManageIQ/manageiq` and refactored to work as a standalone gem.

A working branch (most likely named `historical_master`) will be pushed
shortly, and  the extraction and refactoring progress on of this project can be
followed there in the mean time, though expect that branch to be volatile until
that process is complete.  The rational for going with the name
`historical_master` is at the end of the extraction process, the steps taken to
get there have little relevance moving forward, for example:

> https://github.com/ManageIQ/manageiq/commit/40aeadcac0
> 
> > Mass reformat
> > 
> > Run `rubocop -a` across the entire repository.
> > 
> > Hello, and sorry for the inconvenience, future git-blame users!

Has little value for someone looking at this project (aside from the
`git-blame` users) and `git` has the functionality for saving this commits in a
non-devlop branch for the few that might find the context useful.

That said, after having this on my machine with it not pushed anywhere for a
couple of weeks, I figured it made sense to "`git`" this somewhere a little
safer and allow for some collaboration if/when I get stuck.

* * *


This gem provides file storage connection capabilities across multiple
"providers" through a common interface for the [ManageIQ][] application, as
well as other supporting applications and programs.


Installation
------------

Add this line to your application's Gemfile:

```ruby
gem 'manageiq-file-storage'
```

And then execute:

```console
$ bundle
```

Or install it yourself as:

```console
$ gem install manageiq-storage
```


Development
-----------

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`rake spec` to run the tests. You can also run `bin/console` for an interactive
prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To
release a new version, update the version number in `version.rb`, and then run
`bundle exec rake release`, which will create a git tag for the version, push
git commits and tags, and push the `.gem` file to [rubygems.org][].


Contributing
------------

Bug reports and pull requests are welcome on GitHub at
https://github.com/NickLaMuro/manageiq-file-storage.


License
-------

The gem is available as open source under the terms of the [Apache License
2.0][].


[ManageIQ]:           https://github.com/ManageIQ/manageiq
[rubygems.org]:       https://rubygems.org
[Apache License 2.0]: http://www.apache.org/licenses/LICENSE-2.0
