#!/usr/bin/env ruby
# vim: noet


module SMS
	class Incoming < Gsm::Incoming
		attr_reader :backend
		
		def initialize(backend, *rest)
			@backend = backend
			super(nil, *rest)
		end
		
		def respond(response_text)
			SMS::Outgoing.new(backend, sender, response_text).send!
		end
	end
end
