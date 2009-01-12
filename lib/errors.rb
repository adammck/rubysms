#!/usr/bin/env ruby
# vim: noet


module SMS
	class InvalidBackend < Exception
	end
	
	class CancelIncoming < StandardError
	end
	
	class CancelOutgoing < StandardError
	end
	
	class Respond < Interrupt
	end
end
