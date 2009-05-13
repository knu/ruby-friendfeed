Gem::Specification.new do |s|
  s.specification_version = 2
  s.name = "friendfeed"
  s.version = "0.1.0"
  s.required_rubygems_version = Gem::Requirement.new(">= 0")
  s.authors = ["Akinori MUSHA"]
  s.date = %q{2009-05-14}
  s.summary = "A Ruby module that provides access to FriendFeed API's."
  s.description = s.summary
  s.email = "knu@idaemons.org"
  s.homepage = %q{http://github.com/knu/ruby-friendfeed}
  s.files = Dir.glob("lib/**/*.rb") + Dir.glob("samples/**/*")
  s.require_paths = ["lib"]
  s.has_rdoc = true
  s.rdoc_options = ["--inline-source", "--charset=UTF-8"]
end
