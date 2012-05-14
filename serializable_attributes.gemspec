## This is the rakegem gemspec template. Make sure you read and understand
## all of the comments. Some sections require modification, and others can
## be deleted if you don't need them. Once you understand the contents of
## this file, feel free to delete any comments that begin with two hash marks.
## You can find comprehensive Gem::Specification documentation, at
## http://docs.rubygems.org/read/chapter/20
Gem::Specification.new do |s|
  s.specification_version = 2 if s.respond_to? :specification_version=
  s.required_rubygems_version = Gem::Requirement.new(">= 1.3.5") if s.respond_to? :required_rubygems_version=

  ## Leave these as is they will be modified for you by the rake gemspec task.
  ## If your rubyforge_project name is different, then edit it and comment out
  ## the sub! line in the Rakefile
  s.name              = 'serializable_attributes'
  s.version           = '1.0.0'
  s.date              = '2012-05-14'
  s.rubyforge_project = 'serializable_attributes'

  ## Make sure your summary is short. The description may be as long
  ## as you like.
  s.summary     = "Store a serialized hash of attributes in a single ActiveRecord column."
  s.description = "A bridge between using AR and a full blown schema-free db."

  ## List the primary authors. If there are a bunch of authors, it's probably
  ## better to set the email to an email list or something. If you don't have
  ## a custom homepage, consider using your GitHub URL or the like.
  s.authors  = ["Rick Olson", "Michael Guterl"]
  s.email    = ['technoweenie@gmail.com', 'michael@diminishing.org']
  s.homepage = 'http://github.com/technoweenie/serialized_attributes'

  ## This gets added to the $LOAD_PATH so that 'lib/NAME.rb' can be required as
  ## require 'NAME.rb' or'/lib/NAME/file.rb' can be as require 'NAME/file.rb'
  s.require_paths = %w[lib]

  s.add_dependency "activerecord", [">= 2.2.0", "< 3.3.0"]

  ## Leave this section as-is. It will be automatically generated from the
  ## contents of your Git repository via the gemspec task. DO NOT REMOVE
  ## THE MANIFEST COMMENTS, they are used as delimiters by the task.
  # = MANIFEST =
  s.files = %w[
    LICENSE
    README.md
    Rakefile
    gemfiles/ar-2.2.gemfile
    gemfiles/ar-2.3.gemfile
    gemfiles/ar-3.0.gemfile
    gemfiles/ar-3.1.gemfile
    gemfiles/ar-3.2.gemfile
    init.rb
    lib/serializable_attributes.rb
    lib/serializable_attributes/duplicable.rb
    lib/serializable_attributes/format/active_support_json.rb
    lib/serializable_attributes/schema.rb
    lib/serializable_attributes/types.rb
    rails_init.rb
    script/setup
    serializable_attributes.gemspec
    test/serialized_attributes_test.rb
    test/test_helper.rb
    test/types_test.rb
  ]
  # = MANIFEST =

  ## Test files will be grabbed from the file list. Make sure the path glob
  ## matches what you actually use.
  s.test_files = s.files.select { |path| path =~ %r{^test/*/.+\.rb} }
end
