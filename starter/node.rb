require 'socket'
require 'thread'

$port = nil
$hostname = nil
$routing_table = Hash.new() 
$sync = Mutex.new
$port_table = Hash.new()
$curr_time = nil


# --------------------- Part 1 --------------------- # 

def edgeb(cmd)
	src_ip = cmd[0]
	dst_ip = cmd[1]
	dst = cmd[2]
	port = $port_table[dst]
	sock = TCPSocket.open(dst_ip, port)
	if sock != nil
		$routing_table[dst] = [$hostname, dst, dst, 1]
		$socketToNode[sock] = dst
		msg = dst_ip + "," + src_ip + "," + $hostname
		sock.puts msg
	end
end

#seems like you just need to write to the file given in cmd
#the way i set up $routing_table is the key is destination and the value is an array
#the first entry in array is source, second is destination, third is nextHop, and fourth is distance
#this works because each node maintains its own routing table, this also means that it doesn't have
#the implicit self edge in the table
def dumptable(cmd)
  filename = cmd[0]
  open(filename, 'w') { |f|
    $routing_table.each do |dst, info|
      f.puts "#{info[0]},#{info[1]},#{info[2]},#{info[3]}"
    end
  }
end

#i think you just need to shutdown the server, all the sockets in socketToNode
#might have to flush STDOUT and some other things like it
def shutdown(cmd)
  $socketToNode.keys.each { |sock|
    sock.flush
    sock.close
  }
  
  STDOUT.flush
  STDERR.flush
  exit(0)
end



# --------------------- Part 2 --------------------- # 
def edged(cmd)
	STDOUT.puts "EDGED: not implemented"
end

def edgeu(cmd)
	STDOUT.puts "EDGEu: not implemented"
end

def status()
	STDOUT.puts "STATUS: not implemented"
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

def receive(client)
	message = client.gets
	msg = message.split(",")
	srcip = msg[0]
	dstip = msg[1]
	dst = msg[2]
	dst.delete! "\n"
	$routing_table[dst] = [$hostname, dst, dst, 1]
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
		when "EDGEU"; edgeU(args)
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
	Thread.new {
		loop {
			$curr_time += 0.01
			sleep(0.01)
		}
	}

	#set up ports, server, buffers
	
	$socketToNode = {} #Hashmap to index node by socket

	f = File.open(nodes, "r")
	f.each_line do |line|
		line = line.strip()
		msg = line.split(',')
		node = msg[0]
		p = msg[1]
		$port_table[node] = p
	end
	f.close

	#add config read later

	#start a thread for accepting messages sent to this server
	server = TCPServer.open(port)
	Thread.new {
		loop {
			Thread.start(server.accept) do |client|
				receive(client)
			end
		}
	}

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
