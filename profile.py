"""Experiment from motivating example of [1].

[1] Paul Emmerich, Sebastian Gallenmueller, Gianni Antichi, Andrew W. Moore, Georg Carle, "Mind the Gap - A Comparison of Software Packet Generators,"" in ACM/IEEE Symposium on Architectures for Networking and Communications Systems (ANCS 2017), Beijing, China, May 2017.

Instructions:
Wait for setup services to be finished. Then login to loadgen and execute `/local/repository/loadgen/measurement.sh`.
"""

from geni import portal
from geni.rspec.pg import RawPC, Link, Execute

# Emulab specific extensions.
import geni.rspec.emulab as emulab

pc = portal.Context()

disk_image = "UBUNTU22-64-BETA"

hardware_type = "c220g2"

request = pc.makeRequestRSpec()

node1 = RawPC("loadgen")
node1.disk_image = disk_image
node1.hardware_type = hardware_type
node1eth1 = node1.addInterface("eth1")
node1eth2 = node1.addInterface("eth2")
request.addResource(node1)

node2 = RawPC("dut")
node2.disk_image = disk_image
node2.hardware_type = hardware_type
node2eth1 = node2.addInterface("eth1")
node2eth2 = node2.addInterface("eth2")
request.addResource(node2)

link1 = Link()
link1.addInterface(node1eth1)
link1.addInterface(node2eth1)
link1.setNoInterSwitchLinks()
request.addResource(link1)

link2 = Link()
link2.addInterface(node1eth2)
link2.addInterface(node2eth2)
link2.setNoInterSwitchLinks()
request.addResource(link2)

# install services
node1.addService(Execute(shell="sh", command="/local/repository/loadgen/setup-wrap.sh"))
node2.addService(Execute(shell="sh", command="/local/repository/dut/setup-wrap.sh"))

pc.printRequestRSpec(request)