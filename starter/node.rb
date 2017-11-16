require 'socket'
require 'thread'

$port = nil
$hostname = nil
$routing_table = Hash.new() 
$sync = Mutex.new
$port_table = Hash.new()


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
		sock.write msg
	end
end

def dumptable(cmd)
	STDOUT.puts "DUMPTABLE: not implemented"
end

def shutdown(cmd)
	STDOUT.puts "SHUTDOWN: not ipmlemented"
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
				message = client.gets
				msg = message.split(",")
				srcip = msg[0]
				dstip = msg[1]
				dst = msg[2]
				$routing_table[dst] = [$hostname, dst, dst, 1]
			end
		}
	}

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
