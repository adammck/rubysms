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
			og = SMS::Outgoing.new(backend, sender, response_text)
			og.in_response_to = self
			og.send!
		end
	end
end
