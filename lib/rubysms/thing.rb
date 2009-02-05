#!/usr/bin/env ruby
# vim: noet

module SMS
	class Thing
		attr_accessor :router, :label
		
		
		# stubs to avoid respond_to? or
		# NoMethodError on subclasses
		def incoming(*args); end
		def outgoing(*args); end
		def start(*args); end
		def stop(*args); end
		
		def label
			@label or self.class.to_s.scan(/[a-z]+\Z/i).first
		end
		
		
		protected
		
		# proxy method(s) back to the router, so
		# apps and backends can log things merrily
		
		def log(*args)
			router.log(*args)
		end
		
		def log_with_time(*args)
			router.log_with_time(*args)
		end
		
		def log_exception(error)
			router.log_exception(*args)
		end
	end
end
