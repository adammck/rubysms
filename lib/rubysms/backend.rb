#!/usr/bin/env ruby
# vim: noet


module SMS::Backend
	class Base < SMS::Thing
		
		def send_sms(msg)
			router.outgoing(msg)
		end
	end
end
