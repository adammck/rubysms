#!/usr/bin/env ruby
# vim: noet

module SMS
	class App
		
		# stubs to avoid
		# NoMethodError
		def start; end
		def stop; end
		
#		def respond(*msg)
#			raise SMS::Respond, msg
#		end
		
		#def incoming(from, dt, msg)
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
								#send(method, msg.sender, msg.sent, *m.captures)
								send(method, msg, *m.captures)
								return true
							end
						end
					
					# the special :anything pattern
					# can be used as a default service
					elsif pattern == :anything
						#send(method, msg.sender, msg.sent, msg.text)
						send(method, msg)
					end
				end
			end
		end
		
#		def send_sms(to, *msgs)
#
#			# iterate multiple arguments, to resolve
#			# messages in each of them separately,
#			parts = msgs.collect do |msg|
#				
#				# if the message is a symbol, then attempt to
#				# resolve it via the self.class::Messages hash
#				if msg.is_a? Symbol
#					if self.class.const_defined?(:Messages)				
#						if msg_str = self.class.const_get(:Messages)[msg]
#							log "Resolved message #{msg.inspect} to #{msg_str.inspect}"
#							msg = msg_str
#						else
#							log "No such message as #{msg.inspect} for #{self.class}", :warn
#							msg = msg.to_s
#						end
#					else
#						# no messages const in this app, but receiving
#						# a cryptic message name is better than nothing
#						log "No Messages for #{self.class}", :warn
#						msg = msg.to_s
#					end
#				end
#				
#				msg
#			end
#			
#			# send all parts joined with no separator,
#			# for maximum control over formatting
#			SMS::send_sms(to, parts.join(""))
#		end
		
		def log(msg, type=:info)
			SMS::log(msg, type)#, self.class)
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
