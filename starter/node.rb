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
    $socketToNode[dst] = sock
    msg = Message.new
    msg.setField("type", 0)
    msg.setPayload(dst_ip + "," + src_ip + "," + $hostname)
    Ctrl.sendMsg(msg, sock)
    neighbors.push(dst)
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

  $routing_table.each {|key, value| 
    file.write("#{value[0]},#{value[1]},#{value[2]},#{value[3]}\n")}
  file.close
end

def shutdown(cmd)
  if $server != nil
    $server.close
  end
  $socketToNode.values.each { |sock|
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
	sock = $socketToNode[dst]
	sock.close()
	$socketToNode.delete(dst)
end

def edgeu(cmd)
	dst = cmd[0]
	cost = cmd[1]
	curr_path = $routing_table[dst]
	next_dst = curr_path[2]
	$routing_table[dst] = [$hostname, dst, next_dst, cost]
end

def status()
  STDOUT.puts "Name: #{$hostname}\nPort: #{$port}\nNeighbors: "
  neighbors.each_with_index do | value, index |
    if index == neighbors.length - 1
      STDOUT.puts " #{value}\n"
    else
      STDOUT.puts " #{value},"
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
				Ctrl.flood()
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
			Thread.start(server.accept) do |client|
				Ctrl.receive(client)
			end
		}
	}

	main()

end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])
