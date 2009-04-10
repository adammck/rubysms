Gem::Specification.new do |s|
	s.name     = "rubysms"
	s.version  = "0.8.2"
	s.date     = "2009-04-10"
	s.summary  = "Develop and deploy SMS applications with Ruby"
	s.email    = "amckaig@unicef.org"
	s.homepage = "http://github.com/adammck/rubysms"
	s.authors  = ["Adam Mckaig"]
	s.has_rdoc = true
	
	s.files = [
		"rubysms.gemspec",
		"README.rdoc",
		"lib/rubysms.rb",
		
		# drb clients
		"bin/rubysms-gtk-drb-client",
		"bin/rubysms-drb-client",
		"lib/drb-client.glade",
		
		# core
		"lib/rubysms/application.rb",
		"lib/rubysms/backend.rb",
		"lib/rubysms/logger.rb",
		"lib/rubysms/router.rb",
		"lib/rubysms/errors.rb",
		"lib/rubysms/person.rb",
		"lib/rubysms/thing.rb",
		
		# backends
		"lib/rubysms/backend/cellphone.ico",
		"lib/rubysms/backend/clickatell.rb",
		"lib/rubysms/backend/drb.rb",
		"lib/rubysms/backend/gsm.rb",
		"lib/rubysms/backend/http.rb",
		
		# messages
		"lib/rubysms/message/incoming.rb",
		"lib/rubysms/message/outgoing.rb",
	]
	
	s.executables = [
		"rubysms-gtk-drb-client",
		"rubysms-drb-client"
	]
	
	s.add_dependency("adammck-rubygsm")
	s.add_dependency("mongrel")
	s.add_dependency("rack")
end
