require 'socket'
require 'thread'
require_relative 'message'
require_relative 'control_message'

$port = nil
$hostname = nil
$routing_table = Hash.new() 
$sync = Mutex.new
$port_table = Hash.new()
$curr_time = nil
$update_interval = nil
$mtu = nil
$timeout = nil
$curr_seq = nil
$flood_table = Hash.new()
$buffer = []
$seq_num = 1
$neighbors_dist = Hash.new()
$dist_table = Hash.new()
$hop_table = Hash.new()
$write_buffers = Hash.new()
$flood = false
$neighbors = []




# --------------------- Part 1 --------------------- # 

def edgeb(cmd)
	src_ip = cmd[0]
	dst_ip = cmd[1]
	dst = cmd[2]
	port = $port_table[dst]
	sock = TCPSocket.open(dst_ip, port)
	if sock != nil
		$routing_table[dst] = [$hostname, dst, dst, 1]
		$dist_table[dst] = 1
		$hop_table[dst] = dst
		$socketToNode[sock] = dst
		msg = Message.new
		msg.setField("type", 0)
		msg.setPayload(dst_ip + "," + src_ip + "," + $hostname)
		Ctrl.sendMsg(msg, sock)
		$neighbors_dist[dst] = 1
		$neighbors.push(dst)
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
	$dist_table.each {|key, value| 
		file.write("#{$hostname},#{key},#{$hop_table[key]},#{value}\n")}
	file.close
end

def shutdown(cmd)
  if $server != nil
    $server.close
  end
  $socketToNode.keys.each { |sock|
  	sock.flush
    sock.close
  }
  STDOUT.flush
  STDERR.flush
  exit(0)
end


#add a table that keeps track of every node you have received a flooded
#packet from and the highest seq number from that node
# --------------------- Part 2 --------------------- # 
def edged(cmd)
	dst = cmd[0]
	$routing_table.delete(dst)
	$dist_table[dst] = "INF"
	$neighbors.delete(dst)
	$hop_table.delete(dst)
	sock = $socketToNode.key(dst)
	sock.close()
	$socketToNode.delete(sock)
end

def edgeu(cmd)
	dst = cmd[0]
	cost = cmd[1]
	curr_path = $routing_table[dst]
	next_dst = curr_path[2]
	$routing_table[dst] = [$hostname, dst, next_dst, cost]
	$dist_table[dst] = cost
	$neighbors_dist[dst] = cost
end

def status()
  	STDOUT.puts "Name: #{$hostname}\nPort: #{$port}\nNeighbors: "
  	$neighbors.sort!
  	$neighbors.each_with_index do | value, index |
    	if index == $neighbors.length - 1
     	 STDOUT.puts " #{value}\n"
   	 	else
      	STDOUT.puts " #{value},"
  		end
	end
end


# --------------------- Part 3 --------------------- # 
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


def ftp(cmd)
	STDOUT.puts "FTP: not implemented"
end

def circuit(cmd)
	STDOUT.puts "CIRCUIT: not implemented"
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
	$curr_time = Time.now
	$flood_timer = 0
	Thread.new {
		loop {
			$curr_time += 0.01
			$flood_timer +=0.01
			if ($flood_timer >= $update_interval)
				$flood_timer = 0
				$flood = true 
				Thread.new {
					$sync.synchronize {
						Ctrl.flood()	
					}
				}
			end
			sleep(0.01)
		}
	}

	#set up ports, server, buffers
	
	$socketToNode = {} #Hashmap to index socket by node

	f = File.open(nodes, "r")
	f.each_line do |line|
		line = line.strip()
		msg = line.split(',')
		node = msg[0]
		p = msg[1]
		$port_table[node] = p
	end
	f.close

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


	#start a thread for accepting messages sent to this server
	server = TCPServer.open(port)
	Thread.new {
		loop {
			client = server.accept 
			$socketToNode[client] = nil
		}
	}

	Thread.new {
		loop {
			read = IO.select($socketToNode.keys,nil,nil,1)

			if(read)
				read[0].each do |sock|
					Ctrl.receive(sock)
				end
			end
		}
	}
	
#	Thread.new {
#		loop {
#			$write_buffers.each do |key, value|
#				if (value != "")
#					key.puts(value.toString())
#					$write_buffers[key] = ""
#				end
#			end
#
#			if ($flood == true)
#				STDOUT.puts("here")
#				$flood = false
#				msg = Message.new
#				msg.setField("seq_num", $seq_num)
#				msg.setField("type", 1)
#				$seq_num = $seq_num + 1
#				message = $hostname + "\t"
#				if ($neighbors.length > 0)
#					$neighbors.each do |key, value|
#						dist = value
#						message += key + "," + dist.to_s + "\t"
#					end
#					msg.setPayload(message)
#					$socketToNode.each do |key, value|
#						key.puts(msg.toString())
#					end
#				end
#			end
#		}
#	}

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
