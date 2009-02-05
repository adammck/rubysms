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
				
				# duplicate the message text before hacking it
				# into pieces, so we don't alter the original
				text = msg.text.dup
				
				# lock threads while handling this message, so we don't have
				# to worry about being interrupted by other incoming messages
				# (in theory, this shouldn't be a problem, but it turns out
				# to be a frequent source of bugs)
				Thread.exclusive do
					services.each do |service|
						method, pattern, priority = *service
						
						# if the pattern is a string, then assume that
						# it's a case-insensitive simple trigger - it's
						# a common enough use-case to warrant an exception
						if pattern.is_a?(String)
							pattern = /\A#{pattern}\Z/i
						end
						
						# if this pattern looks like a regex,
						# attempt to match the incoming message
						if pattern.respond_to?(:match)
							if m = pattern.match(text)
								
								# we have a match! attempt to
								# dispatch it to the receiver
								dispatch_to(method, msg, m.captures)
							
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
							dispatch_to(method, msg, [text])
							return true
						
						# we don't understand what this pattern
						# is, or how it ended up in @services.
						# no big deal, but log it anyway, since
						# it indicates that *something* is awry
						else
							log "Invalid pattern: #{pattern.inspect}", :warn
						end
					end#each
					
					
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
		
		def dispatch_to(meth_str, msg, captures)
			log_dispatch(meth_str, captures)
			
			begin
				err_line = __LINE__ + 1
				send(meth_str, msg, *captures)
				
			rescue ArgumentError => err
				
				# if the line above (where we dispatch to the receiving
				# method) caused the error, we'll log a more useful message
				if (err.backtrace[0] =~ /^#{__FILE__}:#{err_line}/)
					wanted = (method(meth_str).arity - 1)
					problem = (captures.length > wanted) ? "Too many" : "Not enough"
					log "#{problem} captures (wanted #{wanted}, got #{captures.length})", :warn
					
				else
					raise
				end
			end
		end
		
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
