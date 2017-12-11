require 'socket'

$port = nil
$hostname = nil
$port_table = Hash.new()
$socketToNode = Hash.new()
$socketSem = Mutex.new
$neighbors = Hash.new()
$neighborsSem = Mutex.new
$socToBuffers = Hash.new()
$read_buffers = Hash.new()
$write_buffers = Hash.new()
$readSem = Mutex.new	
$writeSem = Mutex.new
$clock_val = nil
$flood_table = Hash.new()
$neighbor = []
$seq_num = 0
$dist_table = Hash.new()
$new_table = Hash.new()
$flood_packets = {}
$floodSem = Mutex.new
$flood = false
$update = false

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
			while ($write_buffers[socket][1] != 0) do
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
	STDOUT.puts "SENDMSG: not implemented"
end

def ping(cmd)
	STDOUT.puts "PING: not implemented"
end

def traceroute(cmd)
	STDOUT.puts "TRACEROUTE: not implemented"
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
	end

	if (type == 1)	
		num = cmd[1].to_i()
		curr_node = cmd[2]
		
		if($flood_table[curr_node] == nil || num > $flood_table[curr_node]) 
			$flood_table[curr_node] = num
			$floodSem.synchronize {
				$flood_packets[sock] = msg
			}
			payload_list = msg.chomp.split("\t")
	
			if ($new_table.has_key?(curr_node))
				int_cost = $new_table[curr_node][1]	
				next_hop = $new_table[curr_node][0]	
				for index in 1..(payload_list.length - 1)
					if (!payload_list[index].include?("\000"))	
						neighbor = payload_list[index].chomp.split(",")
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
	end
	
	if(sock)
		$read_buffers[sock][1] = 0
		$read_buffers[sock][0] = ""
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
		 loop {
			    sleep 1
			    $clock_val = $clock_val + 1
			    if ($clock_val % $update_interval.to_i() == 0)
					$flood = true
				end
				if ($clock_val % $update_interval.to_i() == 0)
					$update = true
				end
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
						k.puts(v[0])
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
								sock.puts(msg)
							end
						end
					}
				end
				$flood_packets.clear	
			}
				
			if ($update == true)
				$update = false
		
				$dist_table = $new_table
				$new_table = Hash.new()
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
						sock.puts(msg)

					end
				}
			end
		}
	}
	
	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
