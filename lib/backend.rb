#!/usr/bin/env ruby
# vim: noet


# part of the ruby stdlib
require "singleton.rb"


module SMS
	class Backend
		include Singleton
		
		# stubs to avoid respond_to?
		# or NoMethodError on subclasses
		def start(*args); end
		def stop(*args); end
		
		def send_sms(msg)
			log_with_time "#{msg.recipient}: #{msg.text} (#{msg.text.length})", :out
			
			# notify each app of the outgoing sms
			# note that the sending can still fail
			SMS::apps.each_value do |app|
				if app.respond_to? :outgoing
					app.outgoing msg
				end
			end
		end
		
		def label
			return @label\
				unless @label.nil?
			
			# auto populate label as
			# its class name and index
			i = SMS::backends.index(self.class.instance)
			label = self.class.to_s.upcase.split("::")[-1]
			"#{label}/#{i}"
		end
		
		protected
		
		# proxy method(s) to the SMS module, so
		# backends can use them without the prefix
		def log(*args)
			SMS::log(*args)
		end
		
		def log_with_time(*args)
			SMS::log_with_time(*args)
		end
	end
end
