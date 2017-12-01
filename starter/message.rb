class Message
	HEADER_LENGTH = 20
	#fields in the header that point to [start_index, end_index]

	def initialize(msg = nil) 
		if msg.nil?
			@header = ((0).chr) * HEADER_LENGTH
			@payload = ""
		else 
			@msg = msg
			@header = msg[0..(HEADER_LENGTH - 1)]
			@payload = msg[HEADER_LENGTH..(msg.length - 1)]
		end
	end

	def setHeader(header)
		@header = header
	end

	def getHeader()
		return @header
	end

	def setField(name, n) 
		if (name == "type")
			@header[0] = n.chr 
		elsif (name == "frag_num")
			@header[1] = n.chr
		elsif (name == "frag_seq")
			@header[2] = n.chr
		elsif (name == "seq_num")
			@header[3] = n.chr
		end
	end

	def getField(name)
		if (name == "type")
			return @header[0]
		elsif (name == "frag_num")
			return @header[1]
		elsif (name =="frag_seq")
			return @header[2]
		elsif (name == "seq_num")
			return @header[3]
		end
	end

	def setPayload(payload)
		@payload = payload
	end

	def getPayload()
		return @payload
	end

	#to be added when necessary
	def fragment()
		packet_list = []
		message = @payload
		size = @payload.bytesize
		packet_size = $mtu
		if (@payload.bytesize() < $mtu)
			packet_list = [self]
		else 
			num_frag = (size / packet_size).ceil
			#found this way of splitting a message in this stackoverflow post
			#https://stackoverflow.com/questions/754407/what-is-the-best-way-to-chop-a-string-into-chunks-of-a-given-length-in-ruby
			list = message.chars.each_slice(num_frag).map(&:join)
			num_of_frag = packet_list.length
			fragment_seq = 1

			list.each do |payload|
				msg = Message.new
				msg.setHeader(@header)
				msg.setHeaderField("frag_num", num_of_frag)
				msg.setHeaderField("frag_seq", fragment_seq)
				msg.setPayload(payload)
				packet_list << msg
				fragment_seq += 1
			end
		end
		return packet_list
	end
end
