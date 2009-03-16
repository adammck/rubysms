#!/usr/bin/env ruby
# vim: noet


module SMS::Backend
	
	# TODO: doc
	def self.create(klass, label=nil, *args)
	
		# if a class name was passed (rather
		# than a real class), attempt to load
		# the ruby source, and resolve the name
		unless klass.is_a?(Class)
			begin
				src = File.dirname(__FILE__) +\
					"/backend/#{klass.to_s.downcase}.rb"
				require src
			
			# if the backend couldn't be required, re-
			# raise the error with a more useful message
			rescue LoadError
				raise LoadError.new(
					"Couldn't load #{klass.inspect} " +\
					"backend from: #{src}")
			end
			
			begin
				klass = SMS::Backend.const_get(klass)
			
			# if the constant couldn't be found,
			# re-raise with a more useful message
			rescue NameError
				raise LoadError.new(
					"Loaded #{klass.inspect} backend from " +\
					"#{src}, but the SMS::Backend::#{klass} "+\
					"class was not defined")
			end
		end
		
		# create an instance of this backend,
		# passing along the (optional) arguments
		inst = klass.new(*args)
	
		# apply the label, if one were provided.
		# if not, the backend will provide its own
		inst.label = label unless\
			label.nil?
		
		inst
	end
	
	class Base < SMS::Thing
		
		# This method should be called (via super)
		# by all backends before sending a message,
		# so it can be logged, and apps are notified
		def send_sms(msg)
			router.outgoing(msg)
		end
	end
end
