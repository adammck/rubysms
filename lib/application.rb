#!/usr/bin/env ruby
# vim: noet

module SMS
	class App
		
		# stubs to avoid
		# NoMethodError
		def start; end
		def stop; end
		
		def incoming(msg)
			if services = self.class.instance_variable_get(:@services)
			
				# iterate the services defined for this
				# class, and call the first that matches
				# the incoming message. 
				services.each do |service|
					method, pattern, priority = *service
					
					# if this pattern looks like a regex,
					# attempt to match the incoming message
					if pattern.respond_to?(:match)
						if m = pattern.match(msg.text)
							
							# build a string to clearly log where
							# we're dispatching the message to
							meth_str = self.class.to_s + "#" + method.to_s
							meth_str += " #{m.captures.inspect}"\
								unless m.captures.empty?
							
							log "Dispatching to: #{meth_str}"
							
							# dispatch this message to the matching
							# method, and stop processing (specifically,
							# so services can start specific, and become
							# more and more liberal without checking if
							# the message has already been dispatched
							# --
							# once the method is invoked, it can throw
							# the :do_not_want symbol to refuse the
							# message (for example, if a record was
							# not found), which allows processing to
							# continue as if the method never matched
							catch(:do_not_want) do
								send(method, msg, *m.captures)
								return true
							end
						end
					
					# the special :anything pattern
					# can be used as a default service
					elsif pattern == :anything
						send(method, msg)
					end
				end
			end
		end
		
		def message(msg)
			if msg.is_a? Symbol
				begin
					self.class.const_get(:Messages)[msg]
			
				# something went wrong, but i don't
				# particularly care what, right now.
				# log it, and carry on regardless
				rescue StandardError
					log "Invalid message #{msg.inspect} for #{self.class}", :warn
					"<#{msg}>"
				end
			else
				msg
			end
		end
		
		def assemble(*parts)
			
			# the last element can be an array,
			# which contains arguments to sprintf
			args = parts[-1].is_a?(Array)? parts.pop : []
			
			# resolve each remaining part
			# via self#messge, which can
			# (should?) be overloaded
			parts.collect do |msg|
				message(msg)
			end.join("") % args
		end
		
		def log(msg, type=:info)
			SMS::log(msg, type)
		end
	
		class << self
			def serve(regex)
				@serve = regex
			end
		
			def method_added(meth)
				if @serve
					@services = []\
						unless @services
					
					# add this method, along with the last stored
					# regex, to the map of services for this app.
					# the default 'incoming' method will iterate
					# the regexen, and redirect the message to
					# the method linked here
					@services.push([meth, @serve])
					@serve = nil
				end
			end
		end
	end # App
end # SMS
