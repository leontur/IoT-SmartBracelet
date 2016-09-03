#include "smartBracelet.h"

configuration smartBraceletAppC {}

implementation {

	////////////////////////////////////////////////////////
	//Components

	//Main
	components MainC, smartBraceletC as App;
	components new AMSenderC(AM_DATAGRAM);
	components new AMReceiverC(AM_DATAGRAM);
	components ActiveMessageC;
	components RandomC;

	//Timers
	components new TimerMilliC() as Timer1;
	components new TimerMilliC() as Timer2;
	components new TimerMilliC() as Timer3;
	//components new TimerMilliC() as Timer4;
	
	//Various
	components LedsC;

	//Prints
	components SerialStartC;
	components SerialActiveMessageC as AM;
	
	/////////////////////////////////////////////////////////
	//Interfaces

	//Boot
	App.Boot -> MainC.Boot;

	//Transmitter
	App.Receive -> AMReceiverC;
	App.AMSend -> AMSenderC;
	App.SplitControl -> ActiveMessageC;

	//Datagrams
	App.Packet -> AMSenderC;
	App.PacketAcknowledgements->ActiveMessageC;

	//Timers
	App.Timer1 -> Timer1;
	App.Timer2 -> Timer2;
	App.Timer3 -> Timer3;
	//App.Timer4 -> Timer4;

	//Random
	App.Random -> RandomC;
	RandomC <- MainC.SoftwareInit;

	//Leds
	App.Leds-> LedsC;
	
}