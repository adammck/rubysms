#!/usr/bin/env ruby
# vim: noet


module SMS::Backend
		
	# TODO: doc
	def self.create(klass, label=nil, *args)

		# if a class name was passed (rather
		# than a real class), resolve it
		klass = SMS::Backend.const_get(klass) unless\
			klass.is_a?(Class)

		# create an instance of this backend,
		# passing along the (optional) arguments
		inst = klass.new(*args)
	
		# apply the label, if one were provided.
		# if not, the backend will provide its own
		inst.label = label unless\
			label.nil?
		
		inst
	end
	
	# Create a new backend instance, and add it to the
	# _router_ in a single call. The arguments are passed
	# straight on to SMS::Backend::create, so check
	# that out for documentation.
	def self.spawn(router, *args)
		backend = create(*args)
		router.add(backend)
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
