require_relative 'message'

module Ctrl

	#receives the message from the client
	def Ctrl.receive(client)
		message = client.gets
		client.flush
		if (message.length >= Message::HEADER_LENGTH + 1)
			$sync.synchronize {
				msg = Message.new(message.chop)
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
		dst.delete! ("\n")
		$routing_table[dst] = [$hostname, dst, dst, 1]
		$dist_table[dst] = 1
		$socketToNode[client] = dst
		$neighbors_dist[dst] = 1
		$hop_table[dst] = dst
		$neighbors.push(dst)
	end

	def Ctrl.flood()
		msg = Message.new
		msg.setField("seq_num", $seq_num)
		msg.setField("type", 1)
		$seq_num = $seq_num + 1
		message = $hostname + "\t"
		if ($neighbors_dist.length > 0)
			$neighbors_dist.each do |key, value|
				dist = value
				message += key + "," + dist.to_s + "\t"
			end
			msg.setPayload(message)
			$socketToNode.each do |key, value|
				Ctrl.sendMsg(msg, key)
			end
		end
	end

	def Ctrl.handleFlood(msg, client)
		num = msg.getField("seq_num")
		payload_list = msg.getPayload.split("\t")
		curr_node = payload_list[0]

		if (curr_node != $hostname && ($flood_table[curr_node] == nil or 
			num > $flood_table[curr_node]["seq_num"]))

			#STDOUT.puts(curr_node)
			dist_table = Hash.new()
			for index in 1..(payload_list.length - 1)
				neighbor = payload_list[index].split(",") 
				dist_table[neighbor[0]] = neighbor[1].to_i
				if (neighbor[0] == $hostname)
					$dist_table[curr_node] = neighbor[1]
					$hop_table[curr_node] = curr_node
				else 
					$dist_table[neighbor[0]] = neighbor[1]
					$hop_table[neighbor[0]] = curr_node
				end
			end

			$flood_table[curr_node] = {"seq_num" => num, 
				"neighbors" => dist_table}

			#Ctrl.dijkstra()	
		end
	end

	def Ctrl.sendMsg(msg, client)
		list = msg.fragment()
		list.each do |packet|
			client.puts msg.toString()
		#	$write_buffers[client] = packet
		end
	end

	def Ctrl.dijkstra()
		$dist_table.each do |curr, dist|
			if (curr != $hostname)
				$dist_table[curr] = 10000 #might need to come up with better system
			end
		end

		visited = []

		while visited.length < $flood_table.length
			curr = Ctrl.minDist(visited)
			visited << curr
			dist_to_curr = $dist_table[curr]
			neighbors = $flood_table[curr]["neighbors"]
			neighbors.each do |neighbor, dist|
				new_dist = dist_to_curr + dist
				if (new_dist < $dist_table[neighbor])
					$dist_table[neighbor] = new_dist
					if curr != $hostname
						temp = $routing_table[neighbor]
						routing_table[neighbor] = [temp[0], temp[1], 
							curr, new_dist]
					else
						temp = $routing_table[neighbor]
						routing_table[neighbor] = [temp[0], temp[1],
							temp[2], new_dist]
					end
				end
			end
		end
	end

	def Ctrl.minDist(visited)
		min = "INF"
		min_node = nil
		$dist_table.each do |curr, dist|
			if (dist < min && !(visited.include? curr))
				min = dist
				min_node = curr
			end
		end
		return min_node
	end
end
