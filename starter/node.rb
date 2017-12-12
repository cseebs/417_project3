require 'socket'

$port = nil
$hostname = nil
$port_table = {}
$socketToNode = {}
$socketSem = Mutex.new
$neighbors = {}
$neighborsSem = Mutex.new
$socToBuffers = {}
$read_buffers = {}
$write_buffers = {}
$readSem = Mutex.new	
$writeSem = Mutex.new
$clock_val = nil
$flood_table = {}
$neighbor = []
$seq_num = 0
$dist_table = {}
$new_table = {}
$flood_packets = {}
$floodSem = Mutex.new
$flood = false
$update = false
$message_buffer = []
$trace_route = {}
$msg_frags = {}

# --------------------- Part 0 --------------------- # 

def edgeb(cmd)
	dst = cmd[2]
	dst_ip = cmd[1]
	src_ip = cmd[0]
	port = $port_table[dst]
	
	sock = TCPSocket.open(dst_ip, port)
	if sock != nil
		$neighborsSem.synchronize {
			$neighbors[dst] = 1;
		}
		$dist_table[dst] = [dst, 1]
		$new_table[dst] = [dst, 1]
		$neighbor.push(dst)
		if ($write_buffers.has_key?(sock))
			while ($write_buffers[sock][1] != 0) do
			end
			$write_buffers[sock][1] = 1
			$write_buffers[sock][0] = "0,#{$hostname},\000"
		else
			$writeSem.synchronize {
				$write_buffers[sock] = ["0,#{$hostname},\000", 1]
			}
		end
		$socketSem.synchronize {
			$socketToNode[sock] = dst;
		}
	end
end

def dumptable(cmd)
	file_name = cmd[0]

	begin
		file = File.open(file_name, "w")

	rescue
		new_file = File.new(file_name)
		file = File.open(file_name)
	end
	Hash[$dist_table.sort_by { |key, val| key} ].each do |n, v|	
		file.write("#{$hostname},#{n},#{v[0]},#{v[1]}\n")
	end
end

def shutdown(cmd)
  if $server != nil
    $server.close
  end
  $socketSem.synchronize {
 	 $socketToNode.keys.each { |sock|
  		sock.flush
    	sock.close
  	}
  }
  STDOUT.flush
  STDERR.flush
  exit(0)
end

# --------------------- Part 1 --------------------- # 
def edged(cmd)
	dst = cmd[0];
	$neighborsSem.synchronize {
		$neighbors.delete(dst)
	}
	$dist_table.delete(dst)
	$new_table.delete(dst)
	sock = 	$socketToNode.key(dst)
	sock.close
	$socketSem.synchronize {
		$socketToNode.delete(sock)
	}
end

def edgeu(cmd)
	cost = cmd[1].to_i()
	dst = cmd[0]
	$neighborsSem.synchronize {
		$neighbors[dst] = cost
	}
	$dist_table[dst] = [dst, cost]
	$new_table[dst] = [dst, cost]
end

def status()
	STDOUT.puts "Name: #{$hostname}\nPort: #{$port}\nNeighbors: "
  	$neighbor.sort!
  	output = ""
  	$neighbor.each_with_index do | value, index |
    	if index == $neighbor.length - 1
     	 	output +=  "#{value}"
   	 	else
     		output += "#{value},"
  		end
	end
	STDOUT.puts(output)
end


# --------------------- Part 2 --------------------- #
def sendmsg(cmd)
	dst = cmd[0]
	start_time = $clock_val.to_i
	
	msgSize = cmd[1..-1].join(" ").bytesize
	if(msgSize > $mtu) 
		fragsNeeded = (msgSize/($maxPayload.to_f)).ceil 
		entiremsg = cmd[1..-1].join(" ")
			
		for f in 0..fragsNeeded-1
			if(f == fragsNeeded-1)
				frag = entiremsg.byteslice((f*$mtu), $mtu)
				msg = "2,#{dst},#{start_time},0,#{$hostname},"
				msg << "#{fragsNeeded},#{f+1},"
				msg << frag
				route(dest,msg)
			else
				frag = entiremsg.byteslice((f*$mtu), $mtu)
				msg = "2,#{dst},#{start_time},0,#{$hostname},"
				msg << "#{fragsNeeded},#{f+1},"
				msg << frag
				route(dest,msg)
			end
		end
	else
		msg = "2,#{dst},#{start_time},0,#{$hostname},0,0,"
		msg << cmd[1..-1].join(" ")
		route(dst,msg)
	end
	
	$message_buffer.push([start_time,"2"])
end

def ping(cmd)
	dst = cmd[0]
	num = cmd[1].to_i
	delay = cmd[2].to_i

	for index in 0..num-1
		start = $clock_val
		$message_buffer.push([start, "3"])
		receive(nil, "3,#{start},#{dst},#{$hostname},#{index},0")
		sleep(delay)
	end
end

def traceroute(cmd)
	dst = cmd[0]
	start = $clock_val
	$message_buffer.push([start, "4", dst])
	$trace_route[dst] = []
	msg = "4,#{start},#{dst},#{$hostname},1,0"
	$trace_route[dst].push([0,$hostname,0])
	route(dst, msg)
end

# --------------------- Part 4 --------------------- #
#Dont have to implement? not in the spec:
def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
end

def receive(sock, msg) 
	cmd = msg.chomp.split(",");
	type = cmd[0].to_i   
	
	if (type == 0)
		dst = cmd[1]
		$socketToNode[sock] = dst 
		$neighborsSem.synchronize {
			$neighbors[dst] = 1;
		}
		$dist_table[dst] = [dst, 1]
		$new_table[dst] = [dst, 1]
		$neighbor.push(dst)

	elsif (type == 1)	
		num = cmd[1].to_i()
		curr_node = cmd[2]
		
		if($flood_table[curr_node] == nil || num > $flood_table[curr_node]) 
			$flood_table[curr_node] = num
			$floodSem.synchronize {
				$flood_packets[sock] = msg
			}


			info = msg.chomp.split("\t")
			if ($new_table.has_key?(curr_node))
				int_cost = $new_table[curr_node][1].to_i
				next_hop = $new_table[curr_node][0]	
				info.each_with_index do |entry, i|
					if (i != 0 && !entry.include?("\000"))	
						neighbor = entry.chomp.split(",")
						next_dst = neighbor[0]
						next_cost = neighbor[1].to_i
						if (next_dst != $hostname)	
							if ($new_table.has_key?(next_dst))	
								if (int_cost + next_cost < $new_table[next_dst][1])	
									$new_table[next_dst] = [next_hop, next_cost + int_cost]
								end
							else
								$new_table[next_dst] = [next_hop, next_cost + int_cost]	
							end
						end
					end
				end
			end
		end
	elsif (type == 2)
		dst = cmd[1]
		start_time = cmd[2].to_i()
		direction = cmd[3]
		source = cmd[4]
		num_frags = cmd[5].to_i() 
		frag_num = cmd[6].to_i() 
		message = cmd[7]
		if(dst == $hostname) 
			if(direction == "0")
				if(num_frags> 0) 
					if(frag_num == num_frags) 
						$msg_frags[start_time] << message
						receive(nil, "2,#{source},#{start_time},1,#{dst}")
						STDOUT.puts "SENDMSG: #{source} --> #{$msg_frags[start_time]}"	
						$msg_frags.delete(start_time)
					elsif(frag_num == 1) 
						$msg_frags[start_time] = message
					else 
						$msg_frags[start_time] << message
					end
				else
					receive(nil, "2,#{source},#{start_time},1,#{dst}") 
					STDOUT.puts "SENDMSG: #{source} --> #{message}"	
				end
						  
			else 
				time = $clock_val
				rtt = time - start_time
				if(rtt <= $timeout.to_i()) 
					$message_buffer.delete([start_time,"2"])   
				end 
			end
		else 
			route(dst, msg)
		end
	elsif (type == 3)
		start_time = cmd[1].to_i
		dst = cmd[2]
		source = cmd[3]
		num = cmd[4]
		direction = cmd[5].to_i

		if (dst == $hostname)
			if (direction == 1)
				time = $clock_val
				difference = time - start_time

				if (difference <= $timeout)
					$message_buffer.delete([start_time, "3"])
					STDOUT.puts("#{num} #{source} #{difference}")
				end
			else
				receive(nil, "3,#{start_time},#{source},#{dst},#{num},1")
			end
		else
			route(dst, msg)
		end
	elsif (type == 4)
		start_time = cmd[1].to_i
		dst = cmd[2]
		source = cmd[3]
		num = cmd[4].to_i
		direction = cmd[5].to_i
			
		curr_time = $clock_val
		if(curr_time - start_time <= $timeout.to_i()) 
			if($hostname == dst) 
				time = $clock_val
				newMsg = "4,#{start_time},#{dst},#{source},#{num},1,#{time},#{$hostname}"
				route(source, newMsg)
			elsif($hostname == source) 
				node = cmd[7]
				time = cmd[6]
				rt = curr_time - time.to_i()
				$trace_route[dst].push([num, node,rt])
					
				if(dst == node || num == 10) 
					$message_buffer.delete([start_time, "4", dst]) 
					$trace_route[dst].each do |line|
						STDOUT.puts "#{line[0]} #{line[1]} #{line[2]}"
					end
					$trace_route.delete(dst) 
				end
			else 
				if(direction == 1 || num == 10) 
					route(source, msg)
				else 
					time = $clock_val
					fwd = "4,#{start_time},#{dst},#{source},#{num+1},0"                    
					ack = "4,#{start_time},#{dst},#{source},#{num},1,#{time},#{$hostname}" 
						
					route(dst, fwd)
					route(source, ack)
				end
			end
		end
	end
	
	if(sock)
		$read_buffers[sock][1] = 0
		$read_buffers[sock][0] = ""
	end
end

def route(dst, msg)
	hop = $dist_table[dst][0]
	socket = $socketToNode.key(hop)
	if(socket)
		if ($write_buffers.has_key?(socket))
			while ($write_buffers[socket][1] != 0) do
			end
			$write_buffers[socket][1] = 2
			$write_buffers[socket][0] = "#{msg},\000"	
			$write_buffers[socket][1] = 1
		else
			$writeSem.synchronize {
				$write_buffers[socket] = ["#{msg},\000", 1]
			}
		end
	end 
end



# do main loop here.... 
def main()
	while(line = STDIN.gets())
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; edged(args)
		when "EDGEU"; edgeu(args)
		when "DUMPTABLE"; dumptable(args)
		when "SHUTDOWN"; shutdown(args)
		when "STATUS"; status()
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args);
		when "CIRCUIT"; circuit(args);
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end

end

def setup(hostname, port, nodes, config)
	$hostname = hostname
	$port = port
	$clock_val = Time.now().to_i()

	f = File.open(config, "r")
	f.each_line do |line|
		line = line.strip()
		msg = line.split("=")
		if (msg[0] == "updateInterval")
			$update_interval = Integer(msg[1])
		elsif (msg[0] == "maxPayload")
			$mtu = Integer(msg[1])
		elsif (msg[0] == "pingTimeout")
			$timeout = Integer(msg[1])
		end
	end
	f.close

	f = File.open(nodes, "r")
	f.each_line do |line|
		line = line.strip()
		msg = line.split(',')
		node = msg[0]
		p = msg[1]
		$port_table[node] = p
	end
	f.close
	
	server = TCPServer.open(port)
	Thread.new {
	  loop {                                      
	     client = server.accept
	      
	      $socketSem.synchronize {
	    	$socketToNode[client] = nil            
	      }
	  }
	}
	
	Thread.new {
		loop{
			read = []
				
			read = IO.select($socketToNode.keys,nil,nil,1)
				
			if(read)   
				socks = read[0]
					
				socks.each do |sock|
					if (!($read_buffers.has_key?(sock)))
						$readSem.synchronize {
							$read_buffers[sock] = ["", 0]
						}
					end
							
					if (!($write_buffers.has_key?(sock)))
						$writeSem.synchronize {
							$write_buffers[sock] = ["", 0]
						}
					end
						
					if ($read_buffers[sock][1] == 0)
						$read_buffers[sock][1] = 2	
						buffer = sock.gets("\0")          
						sock.flush
							
						if(buffer && buffer.length > 2) 
							$read_buffers[sock][0] = buffer;
							$read_buffers[sock][1] = 1;
							receive(sock,$read_buffers[sock][0])
						else
							$read_buffers[sock][1] = 0
						end
					end
				end
			end
		}	
	}
	
	Thread.new {	
		loop {
			$writeSem.synchronize {
				$write_buffers.each do |k, v|
					if (v[1] == 1)
						k.send(v[0], 0)
						v[0] = ""
						v[1] = 0
					end
				end
			}
				
			$floodSem.synchronize {
				$flood_packets.each do |soc, msg|
					$socketSem.synchronize {
						$socketToNode.each do |sock, node|
							if (sock != soc)
								sock.send(msg, 0)
							end
						end
					}
				end
				$flood_packets.clear	
			}
				
			if ($update == true)
				$update = false
		
				$dist_table = $new_table
				$new_table = {}
				$neighborsSem.synchronize {
					$neighbors.each do |n, c|
						$new_table[n] = [n, c]
					end
				}
			end
				
			if ($flood == true)
				$flood = false
				$seq_num += 1
				msg = "1,#{$seq_num},#{$hostname},\t"
				$socketSem.synchronize {
					$socketToNode.each do |sock, node|
						msg << "#{node},#{$neighbors[node]}\t"	
					end
				}
				msg << "\000"
					
				$socketSem.synchronize {
					$socketToNode.each do |sock, node|
						sock.send(msg, 0)

					end
				}
			end

			if($message_buffer[0])
					oldestmsg = $message_buffer[0][0] 
					rtt = $clock_val - oldestmsg
					if(rtt > $timeout.to_i())                
						popped = $message_buffer.shift	
						if(popped[1] == "3")
							STDOUT.puts "PING ERROR: HOST UNREACHABLE"
						elsif(popped[1] == "4")
							dst = popped[0][2]   
							STDOUT.puts "TIMEOUT ON #{$trace_route[dst].length-1}"
							$trace_route.delete(dst) 
						elsif(popped[1] == "2")
							STDOUT.puts "SENDMSG ERROR: HOST UNREACHABLE"
						end
					end
				end
		}
	}

	Thread.new {	
		 while true do
			sleep 1
			$clock_val = $clock_val + 1
			if ($clock_val % $update_interval.to_i() == 0)
				$flood = true
			end
			if ($clock_val % 2 == 0)
				$update = true
			end
		 end
	}
	
	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
