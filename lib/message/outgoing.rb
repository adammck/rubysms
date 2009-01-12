#!/usr/bin/env ruby
# vim: noet


module SMS
	class Outgoing < Gsm::Outgoing
		attr_reader :backend
		
		def initialize(backend, *rest)
			@backend = backend
			super(nil, *rest)
		end
		
		def send!
			backend.send_sms(self)
			@sent = Time.now
			
			# once sent, allow no
			# more modifications
			freeze
		end
	end
end
