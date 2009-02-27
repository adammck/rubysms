#!/usr/bin/env ruby
# vim: noet


module SMS
	class Outgoing
		attr_accessor :recipient, :text, :in_response_to
		attr_reader :backend, :sent
		
		def initialize(backend, recipient=nil, text=nil)
			@backend = backend
			@recipient = recipient
			@text = text
		end
		
		# Sends the message via _@backend_ NOW, and
		# prevents any further modifications to self,
		# to avoid the object misrepresenting reality.
		def send!
			backend.send_sms(self)
			@sent = Time.now
			
			# once sent, allow no
			# more modifications
			freeze
		end
	end
end
