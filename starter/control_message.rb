require_relative 'message'

module Ctrl

	#receives the message from the client
	def Ctrl.receive(client)
		message = client.gets
		if (message.length >= Message::HEADER_LENGTH + 1)
			$sync.synchronize {
				msg = Message.new(message.chop)
				STDOUT.puts(msg.toString())
				seq = msg.getField("frag_seq")
				num = msg.getField("frag_num")
				if (seq == 0) 
					Ctrl.handle(msg, client)
				else 
					$buffer << msg
					if (num == seq) 
						payload_str = ""
						full_msg = Message.new
						full_msg.setHeader($buffer[0].getHeader())
						full_msg.setField("frag_seq", 0)
						full_msg.setField("frag_num", 0)
						$buffer.each do |packet|
							payload_str += packet.getPayload()
						end
						full_msg.setPayload(payload_str)
						Ctrl.handle(full_msg, client)
					end
				end
			}
		end
	end

	def Ctrl.handle(msg, client)
		type = msg.getField("type")
		STDOUT.puts(type)
		if (type == 0) 
			Ctrl.edgeb(msg, client)
		else
			Ctrl.handleFlood(msg, client)
		end
	end

	def Ctrl.edgeb(message, client)
		msg = message.getPayload().split(",")
		srcip = msg[0]
		dstip = msg[1]
		dst = msg[2]
		$routing_table[dst] = [$hostname, dst, dst, 1]
		$socketToNode[client] = dst
	end

	def Ctrl.flood()
		msg = Message.new
		msg.setField("seq_num", $seq_num)
		$seq_num += 1
		message = $hostname + "\t"
		if ($routing_table.length > 0)
			$routing_table.each do |key, value|
				dist = value[3]
				message += key + "," + dist.to_s + "\t"
			end
			msg.setPayload(message)
			$socketToNode.each do |key, value|
				Ctrl.sendMsg(msg, key)
			end
		end
	end

	def Ctrl.handleFlood(msg, client)
		STDOUT.puts("Here")
		num = msg.getField("seq_num")
		payload_list = msg.getPayload.split("\t")
		curr_node = payload_list[0]
		if ($flood_table[curr_node] == nil or 
			num > $flood_table[curr_node])

			$flood_table[curr_node] = num
			$socketToNode.each do |key, value|
				Ctrl.sendMsg(msg, key)
			end
			dist_table = Hash.new()
			for index in 1..(payload_list.length - 1)
				neighbor = payload_list[index].split(",") 
				dist_table[neighbor[0]] = neighbor[1].to_i
			end

			visited = []

			while (visited.length < dist_table.length)
				dist_table.each do |key, value|
					temp = $routing_table[curr_node]
					curr_dist = temp[3]
					new_dist = curr_dist + value
					neighbor = $routing_table[key]
					if (new_dist < neighbor[3])
						if (curr_node != $hostname)
							next_hop = $routing_table[curr_node]
							$routing_table[key] = [neighbor[0], neighbor[1], 
								next_hop[2], new_dist]
						else 
							$routing_table[key] = [neighbor[0], neighbor[1],
								neighbor[2], new_dist]
						end
					end
				end
			end
		end
	end

	def Ctrl.sendMsg(msg, client)
		#list = msg.fragment()
		#list.each do |packet|
			STDOUT.puts(msg.toString())
			client.puts msg.toString()
		#end
	end
end	
