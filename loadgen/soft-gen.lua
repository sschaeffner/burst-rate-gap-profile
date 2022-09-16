--- Generates MoonSniff traffic, i.e. packets contain an identifier and a fixed bit pattern
--- Live mode and MSCAP mode require this type of traffic

local lm     = require "libmoon"
local device = require "device"
local memory = require "memory"
local ts     = require "timestamping"
local hist   = require "histogram"
local timer  = require "timer"
local log    = require "log"
local stats  = require "stats"
local bit    = require "bit"
local limiter = require "software-ratecontrol"

function configure(parser)
	parser:description("Generate traffic which can be used by moonsniff to establish latencies induced by a device under test.")
	parser:argument("dev", "Devices to use."):args(2):convert(tonumber)
	parser:option("-v --fix-packetrate", "Approximate send rate in pps."):convert(tonumber):default(100000):target('fixedPacketRate')
	parser:option("-s --src-mac", "Overwrite source MAC address of every sent packet"):default(''):target("srcMAC")
	parser:option("-d --dst-mac", "Overwrite destination MAC address of every sent packet"):default(''):target("dstMAC")
	parser:option("-i --src-ip", "Overwrite src IP address of every sent packet"):default('10.0.0.1'):target("srcIP")
	parser:option("-j --dst-ip", "Overwrite dst IP address of every sent packet"):default('10.0.1.1'):target("dstIP")
	parser:option("-p --packets", "Send only the number of packets specified"):default(1000000):convert(tonumber):target("numberOfPackets")
	parser:option("-x --size", "Packet size in bytes."):convert(tonumber):default(48):target('packetSize')
	parser:option("-o --ip-chksum", "IP chksum calculation flag to enable (1) / disable (0) software calculation of IP checksum"):default(0):target("ipChksum")
	parser:option("-c --chksum-offload", "Enable (1) / disable (0) offloading of checksums"):default(1):target("offloadChksum")
	parser:option("-b --burst", "Generated traffic is generated with the specified burst size (default burst size 1)"):default(1):target("burstSize")
	parser:option("-w --warm-up", "Warm-up device by sending 1000 pkts and pausing n seconds before real test begins."):convert(tonumber):default(0):target('warmUp')

	return parser:parse()
end

function master(args)
	rxdevid = args.dev[2]
	args.dev[1] = device.config { port = args.dev[1], txQueues = 2 }
	args.dev[2] = device.config { port = args.dev[2], rxQueues = 2 }
	device.waitForLinks()
	local dev0tx0 = args.dev[1]:getTxQueue(0)
	local dev1rx0 = args.dev[2]:getRxQueue(0)

	local dev0tx1 = args.dev[1]:getTxQueue(1)
	local dev1rx1 = args.dev[2]:getRxQueue(1)

	stats.startStatsTask { txDevices = { args.dev[1] }, rxDevices = { args.dev[2] } }
	-- stats.startStatsTask { txDevices = { args.dev[1] } }

        dstmc = parseMacAddress(args.dstMAC, 0)
	srcmc = parseMacAddress(args.srcMAC, 0)

        dstip = parseIPAddress(args.dstIP)
	srcip = parseIPAddress(args.srcIP)

	rateLimiter = limiter:new(dev0tx0, "custom")
	local loadTask = lm.startTask("generateTraffic", dev0tx0, args, rateLimiter, dstmc, srcmc, dstip, srcip, args.ipChksum, args.offloadChksum)
	local dumperTask = lm.startTask("dumper", dev1rx0, rxdevid)

	local stamperTask = lm.startTask("stamper", dev0tx1, dev1rx1, args.packetSize, dstmc, srcmc, dstip, srcip, "histogram.csv")

	if args.warmUp > 0 then
		print('warm up active')
	end

	loadTask:wait()
	dumperTask:wait()
	stamperTask:wait()
	lm.stop()
	lm.waitForTasks()
end

function dumper(queue, ifid)
        local bufs = memory.bufArray()
        -- local dumperPktCtr = stats:newPktRxCounter("DUMPER PKT Device: id=" .. ifid, "plain")
        while lm.running() do
                local rx = queue:tryRecv(bufs, 100)
                for i = 1, rx do
                        local buf = bufs[i]
			--buf:dump()
                        -- dumperPktCtr:countPacket(buf)
                end
                bufs:free(rx)
                -- dumperPktCtr:update()
        end
        -- dumperPktCtr:finalize()
end

function generateTraffic(queue, args, rateLimiter, dstMAC, srcMAC, dstIP, srcIP, ipChksum, offloadChksum)
	log:info("Trying to enable rx timestamping of all packets, this isn't supported by most nics")
	local numberOfPackets = args.numberOfPackets
	if args.warmUp > 0 then
		numberOfPackets = numberOfPackets + 945
	end
	local mempool = memory.createMemPool(function(buf)
		buf:getUdpPacket():fill {
			pktLength = args.packetSize,
		}
	end)
	local bufs = mempool:bufArray() -- array containing packet buffers
	counter = 0
	delay = 0
	while lm.running() do
		bufs:alloc(args.packetSize)

		for i, buf in ipairs(bufs) do
			local pkt = buf:getUdpPacket()
			if dstMAC ~= nil then
				pkt.eth:setDst(dstMAC)
			end
			if srcMAC ~= nil then
				pkt.eth:setSrc(srcMAC)
			end
			pkt.ip4:setDst(dstIP)
			pkt.ip4:setSrc(srcIP)

			-- for setters to work correctly, the number is not allowed to exceed 16 bit
			numberOfPackets = numberOfPackets - 1
			counter = counter + 1
			if (args.warmUp > 0 and counter == 946) then
				delay =  (10000000000 / 8) * args.warmUp
				buf:setDelay(delay)
				delay = 0
			else
				delay =  delay + (10000000000 / args.fixedPacketRate / 8)
				if delay < 0 then
					delay = 0
				end
				if counter % args.burstSize == 0 then
					buf:setDelay(delay)
					delay = 0
				else
					buf:setDelay(0)
				end
			end
			if tonumber(ipChksum) > 0 then
				pkt.ip4:calculateChecksum()
			end
			if numberOfPackets <= 0 then
	                        print(i)
				rateLimiter:sendN(bufs, i)
				lm.sleepMillis(1500)
				print(counter)
				lm.stop()
				lm.sleepMillis(1500)
				os.exit(0)
				return
			end
		end
		if tonumber(offloadChksum) >= 1 then
			bufs:offloadIPChecksums()
			bufs:offloadUdpChecksums()
		end
		rateLimiter:send(bufs)

		if args.warmUp > 0 and counter == 945 then
			lm.sleepMillis(1000 * args.warmUp)
		end
	end
end


function stamper(txQueue, rxQueue, size, dstMAC, srcMAC, dstIP, srcIP, histfile)
	if size < 84 then
		log:warn("Packet size %d is smaller than minimum timestamp size 84. Timestamped packets will be larger than load packets.", size)
		size = 84
	end

	local timestamper = ts:newTimestamper(txQueue, rxQueue)
	local hist = hist:new()
	lm.sleepMillis(1000) -- ensure that the load task is running

	local rateLimit = timer:new(0.001)
	while lm.running() do
		hist:update(timestamper:measureLatency(size, function(buf)
			local pkt = buf:getUdpPacket()
			
			if dstMAC ~= nil then
				pkt.eth:setDst(dstMAC)
			end
			if srcMAC ~= nil then
				pkt.eth:setSrc(srcMAC)
			end
			pkt.ip4:setDst(dstIP)
			pkt.ip4:setSrc(srcIP)
		end))

		rateLimit:wait()
		rateLimit:reset()
	end
	hist:print()
	hist:save(histfile)
end
