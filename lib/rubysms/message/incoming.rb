#!/usr/bin/env ruby
# vim: noet


module SMS
	class Incoming < Gsm::Incoming
		attr_reader :backend, :responses
		attr_writer :text
		
		def initialize(backend, *rest)
			@backend = backend
			@responses = []
			super(nil, *rest)
		end
		
		def respond(response_text)
			og = SMS::Outgoing.new(backend, sender, response_text)
			og.in_response_to = self
			@responses.push(og)
			og.send!
		end
	end
end
