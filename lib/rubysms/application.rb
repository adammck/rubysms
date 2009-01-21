#!/usr/bin/env ruby
# vim: noet

module SMS
	class App < Thing
		
		# Creates and starts a router to serve only
		# this application using the offline DRB and
		# HTTP backends. Handy during development.
		def self.serve!
			r = SMS::Router.new
			r.add SMS::Backend::HTTP.new
			r.add SMS::Backend::DRB.new
			r.add self.new
			r.serve_forever
		end
		
		def incoming(msg)
			if services = self.class.instance_variable_get(:@services)
				text = msg.text					
				
				# lock threads while handling this message, so we don't have
				# to worry about being interrupted by other incoming messages
				# (in theory, this shouldn't be a problem, but it turns out
				# to be a frequent source of bugs)
				Thread.exclusive do
					while true
						services.each do |service|
							method, pattern, priority = *service
						
							# if this pattern looks like a regex,
							# attempt to match the incoming message
							if pattern.respond_to?(:match)
								if m = pattern.match(text)
									
									# we have a match! log, and call
									# the method with the captures
									log_dispatch(method, m.captures)
									send(method, msg, *m.captures)
								
									# the method accepted the text, but it may not be interested
									# in the whole message. so crop off just the part that matched
									text.sub!(pattern, "")
								
									# stop processing if we have
									# dealt with all of the text
									return true unless text =~ /\S/
								
									# there is text remaining, so
									# (re-)start iterating services
									# (jumps back to services.each)
									retry
								end
					
							# the special :anything pattern can be used
							# as a default service. once this is hit, we
							# are done processing the entire message
							elsif pattern == :anything
								log_dispatch(method, [text])
								send(method, msg, text)
								
								# stop processing
								return true
							end
						end#each
					end#while
				end#exclusive
			end#if
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
		
		private
		
		# Adds a log message detailing which method is being
		# invoked, with which arguments (if any)
		def log_dispatch(method, args=[])
			meth_str = self.class.to_s + "#" + method.to_s
			meth_str += " #{args.inspect}" unless args.empty?
			log "Dispatching to: #{meth_str}"
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
