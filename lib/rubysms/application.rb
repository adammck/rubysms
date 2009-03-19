#!/usr/bin/env ruby
# vim: noet

module SMS
	class App < Thing
		
		NAMED_PRIORITY = {
			:highest => 100,
			:high    => 90,
			:normal  => 50,
			:low     => 10,
			:lowest  => 0
		}
		
		# Creates and starts a router to serve only
		# this application. Handy during development.
		#
		# This method accepts an arbitrary number of
		# backends, each of which can be provided in
		# numerous ways. This is kind of hard to wrap
		# one's head around, but makes us super flexible.
		# TODO: this magic will all be moved to the
		#       router, one day, so multiple apps
		#       can take advantage of it.
		#
		#   # start the default backends
		#   # (one http, and one drb)
		#   App.serve!
		# 
		#   # just the http backend
		#   App.serve!(:HTTP)
		#   
		#   # the http backend... with configuration option(s)!
		#   # (in this case, a port). it's got to be an array,
		#   # so we know that we're referring to one single
		#   # backend here, not two "HTTP" and "8080" backends
		#   App.serve!([:HTTP, 8080])
		#   
		#   # two GSM backends on separate ports
		#   App.serve!([:GSM, "/dev/ttyS0"], [:GSM, "/dev/ttyS1"])
		#
		# You may notice that these arguments resemble the
		# config options from the Malawi RapidSMS project...
		# this is not a co-incidence.
		def self.serve!(*backends)
			
			# if no backends were explicitly requested,
			# default to the HTTP + DRB offline backends
			backends = [:HTTP, :DRB] if\
				backends.empty?
			
			# create a router, and attach each new backend
			# in turn. because ruby's *splat operator is so
			# clever, each _backend_ can be provided in many
			# ways - see this method's docstring.
			router = SMS::Router.new
			backends.each do |backend|
				router.add_backend(*backend)
			end
			
			router.add_app(self.new)
			router.serve_forever
		end
		
		# Sets or returns the priority of this application **class**. Returning
		# this value isn't tremendously useful by itself, and mostly exists for
		# the sake of completeness, and to be called by Application#priority.
		# The value returned is obtained by finding the first ancestor of this
		# class which has a @priority (yes, it looks inside other classes
		# instance variables. I'm sorry.), and converts it to a number via
		# the SMS::App::NAMED_PRIORITY constant.
		#
		#   class One < SMS::App
		#     priority :high
		#   end
		#   
		#   class Two < One
		#   end
		#   
		#   class Three < Two
		#     priority 36
		#   end
		#
		#   One.priority   => 90 # set via NAMED_PRIORITY
		#   Two.priority   => 90 # inherited from One
		#   Three.priority => 36 # set literally
		#
		def self.priority(priority=nil)
		
			# set the priority of this class if an argument
			# were provided, and allow execution to continue
			# to check it's validity
			unless priority.nil?
				@priority = priority
			end
			
			# find the first ancestor with a priority
			# (Class.ancestors *includes* self)
			self.ancestors.each do |klass|
				if klass.instance_variable_defined?(:@priority)
					prio = klass.instance_variable_get(:@priority)
					
					# literal numbers are okay, although
					# that probably isn't such a good idea
					if prio.is_a?(Numeric)
						return prio
					
					# if this class has a named priority,
					# resolve and return it's value
					elsif prio.is_a?(Symbol)
						if NAMED_PRIORITY.has_key?(prio)
							return NAMED_PRIORITY[prio]
						
						# don't allow invalid named priorites.
						# i can't think of a use case, especially
						# since the constant can be monkey-patched
						# if it's really necessary
						else
							raise(
								NameError,
								"Invalid named priority #{prio.inspect} " +\
								"of {klass}. Valid named priorties are: " +\
								NAMED_PRIORITY.keys.join(", "))
						end
					end
				end
			end
			
			# no ancestor has a priority, so assume
			# that this app is of "normal" priority
			return NAMED_PRIORITY[:normal]
		end
		
		def priority=(level)
			@priority = level
		end
		
		def priority
			@priority or self.class.priority
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
