print "********************************************";
print "*                                          *";
print "*             TOSSIM Script                *";
print "*                                          *";
print "********************************************";

import sys;
import time;
import os, pty, serial

from TOSSIM import *;

t = Tossim([]);

#Imports
topofile="topology.txt";
modelfile="meyer-heavy.txt";

#Topology init
print "Initializing mac....";
mac = t.mac();
print "Initializing radio channels....";
radio=t.radio();
print "    using topology file:",topofile;
print "    using noise file:",modelfile;
print "Initializing simulator....";
t.init();

#Simulation output file opening
simulation_outfile = "simulation.txt";
print "Saving sensors simulation output to:", simulation_outfile;
simulation_out = open(simulation_outfile, "w");

#Output selector
print "\n";
print "> Insert output format (1 terminal / 2 file log / 3 serial output) ..";
mode=int(raw_input('format:'))

if mode==1:
    #terminal
    out = sys.stdout;
elif mode==2:
    #file
    out = open(simulation_outfile, "w");
elif mode==3:
    #serial (first file, then forward)
    out = open(simulation_outfile, "w");

#Add debug channel
print "Activate debug message on channel init"
t.addChannel("init",out);
print "Activate debug message on channel boot"
t.addChannel("boot",out);
print "Activate debug message on channel radioTX"
t.addChannel("radioTX",out);
print "Activate debug message on channel radioRX"
t.addChannel("radioRX",out);
print "Activate debug message on channel radioDatagram"
t.addChannel("radioDatagram",out);
print "Activate debug message on channel node"
t.addChannel("node",out);

#Nodes creation
print "Creating node 1...";
node1 =t.getNode(1);
time1 = 0*t.ticksPerSecond();
node1.bootAtTime(time1);
print ">>>Will boot at time",  time1/t.ticksPerSecond(), "[sec]";

print "Creating node 2...";
node2 = t.getNode(2);
time2 = 2*t.ticksPerSecond();
node2.bootAtTime(time2);
print ">>>Will boot at time", time2/t.ticksPerSecond(), "[sec]";

print "Creating node 3...";
node3 = t.getNode(3);
time3 = 3*t.ticksPerSecond();
node3.bootAtTime(time3);
print ">>>Will boot at time", time3/t.ticksPerSecond(), "[sec]";

print "Creating node 4...";
node4 = t.getNode(4);
time4 = 4*t.ticksPerSecond();
node4.bootAtTime(time4);
print ">>>Will boot at time", time4/t.ticksPerSecond(), "[sec]";


#Radio creation
print "Creating radio channels..."
f = open(topofile, "r");
lines = f.readlines()
for line in lines:
  s = line.split()
  if (len(s) > 0):
    print ">>>Setting radio channel from node ", s[0], " to node ", s[1], " with gain ", s[2], " dBm"
    radio.add(int(s[0]), int(s[1]), float(s[2]))


#Channel model creation (and noises)
print "Initializing Closest Pattern Matching (CPM)...";
noise = open(modelfile, "r")
lines = noise.readlines()
compl = 0;
mid_compl = 0;

print "Reading noise model data file:", modelfile;
print "Loading:",
for line in lines:
    str = line.strip()
    if (str != "") and ( compl < 10000 ):
        val = int(str)
        mid_compl = mid_compl + 1;
        if ( mid_compl > 5000 ):
            compl = compl + mid_compl;
            mid_compl = 0;
            sys.stdout.write ("#")
            sys.stdout.flush()
        for i in range(1, 5):
            t.getNode(i).addNoiseTraceReading(val)
print "Done!";

for i in range(1, 5):
    print ">>>Creating noise model for node:",i;
    t.getNode(i).createNoiseModel()

#START
print "Start simulation with TOSSIM! \n\n";

#SIMULATION CONSTRAINTS AND SCENARIOS
for i in range(0,5000):
	if (i == 3000): 
		node2.turnOff();
		print "\n>>SHUTTING DOWN NODE 2..<<\n"
	t.runNextEvent()
	
print "\nSimulation finished!\n";

#serial forwarder
if mode==3:
    #configure the serial connections
    ser = serial.Serial('/dev/ttyS0', 9600, rtscts=True, dsrdtr=True)  # open serial port
    print " >>SERIAL FORWARDER>> serial port used: ", ser.portstr   # check which port was really used
    print "\n >>remind to use this as a root!\n"
    #ser.write("\n >serial test ALARM! \n go go ALARM! go :) ")  # write test string
    with open('simulation.txt') as fp:
        for line in fp:
            ser.write(line);
    ser.close(); # close serial port

#END