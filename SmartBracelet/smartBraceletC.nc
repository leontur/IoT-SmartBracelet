#include "smartBracelet.h"
#include "Timer.h"

module smartBraceletC{

	uses{

		//interfaces
		interface Boot;	
		
		interface AMSend;
		interface Receive;

		interface Random;
		interface SplitControl;

		interface Packet;
		interface PacketAcknowledgements;

		interface Leds;

		//timer1: pairing
		interface Timer<TMilli> as Timer1;

		//timer2: child transmission trigger
		interface Timer<TMilli> as Timer2;

		//timer3: alarm after 60 sec
		interface Timer<TMilli> as Timer3;

		//timer4: reboot after 120 sec
		//interface Timer<TMilli> as Timer4;		
	}
}

implementation{

	//////////////////////////////////////////////////////////////////////////////
	//VARS

	//pre-installed keys
	uint8_t KeyP[K_LEN]; //parent key
	uint8_t KeyC[K_LEN]; //child key

	//unicast address (after a pairing)
	uint16_t unicastConnectedAddress;

	//vars
	bool paired = FALSE;
	bool isParent = FALSE;
	bool ackListener = FALSE;

	//datagram
	message_t packet;

	//coordinates (last known from child)
	uint16_t coord_X;
	uint16_t coord_Y;

	//datagram counters
	uint8_t broadcastDatagramID=0;
	uint8_t infoDatagramID=0;

	//broadcast senders
	task void transmitBroadcastDatagram();
	task void transmitUnicastDatagram();
	task void transmitChildDatagram();

	//alarm senders
	task void alarmFalling();
	task void alarmMissing();

	//////////////////////////////////////////////////////////////////////////////
	//BOOT
	event void Boot.booted(){

		//generating keys
		int i, n;
		dbg("node", "[info] Generating preloaded bracelets' keys..\n");
		for(n=1; n<=N_MAX; n++){
			
			//if the node asigned from TOSSIM is the current
			if (TOS_NODE_ID == n){
				if((n % 2) == 1){
					//odd nodes
					//assignment
					for (i=0; i<K_LEN; i++){
						KeyP[i] = n;
						KeyC[i] = n+1;
					}
					dbg("node", "[info] Node: %i | KeyP: %ux%i | KeyC: %ux%i\n", n, KeyP[0], K_LEN, KeyC[0], K_LEN);
				}else{
					//even nodes
					//assignment
					for (i=0; i<K_LEN; i++){
						KeyC[i] = n-1;
						KeyP[i] = n+1-1;
					}
					dbg("node", "[info] Node: %i | KeyP: %ux%i | KeyC: %ux%i\n", n, KeyP[0], K_LEN, KeyC[0], K_LEN);
				}
			}
		}

		//bracelet type assignment
		if((TOS_NODE_ID % 2) == 1){

			//assign parent only if is odd
			isParent = TRUE;
			dbg("node", "[info] TOS_Node: %i is a PARENT\n", TOS_NODE_ID);

		}else{
			dbg("node", "[info] TOS_Node: %i is a CHILD\n", TOS_NODE_ID);
		}

		//starting radio
		call SplitControl.start();
	}

	//////////////////////////////////////////////////////////////////////////////
	//TIMERS

	//starting timer1
	event void SplitControl.startDone(error_t error){
		if(error == SUCCESS) {
			dbg("radioTX", "[info] Starting Timer1 (every %i ms) for broadcast pairing at %s \n", T_1, sim_time_string());
			call Timer1.startPeriodic(T_1);
		}
		else{	
			dbg("node","[error] Radio starting error\n");
			call SplitControl.start();
		}
	}
	
	//timer1 event (pairing)
	event void Timer1.fired(){
		dbg("radioTX", "[info] Timer1 fired at %s \n", sim_time_string());
		post transmitBroadcastDatagram();
	}

	//timer2 event (child)
	event void Timer2.fired(){
		dbg("radioTX", "[info] Timer2 fired at %s \n", sim_time_string());
		call Leds.led0Off();
		call Leds.led1Off();
		post transmitChildDatagram();
	}

	//timer3 event (alarm)
	event void Timer3.fired(){
		dbg("radioTX", "[info] Timer3 fired at %s (missing messages from child in last %i ms) \n", sim_time_string(), T_3);
		call Leds.led0Off();
		call Leds.led1Off();
		call Leds.led2Off();
		post alarmMissing();
	}


	//////////////////////////////////////////////////////////////////////////////
	//TASKS

	//unicast transmitter for initial pairing phase
	task void transmitUnicastDatagram() {

		//datagram instantiation
		pairing_datagram_ack_t* datagram = (pairing_datagram_ack_t*)(call Packet.getPayload(&packet, sizeof(pairing_datagram_ack_t)));

		//passing datagram type
		datagram->type = UNICAST;
		
		//passing datagram ack value (default ack = true)
		datagram->acknowledgement = 1;

		//log
		dbg("radioDatagram", "[radio>>] Unicast datagram (pairing ack) to Address: %u is under transmission | Time: %s \n", unicastConnectedAddress, sim_time_string());

		//enable ack listener
		ackListener = TRUE;

		//request an explicit ack for this transmission
		call PacketAcknowledgements.requestAck(&packet);

		//transmission result
		if(call AMSend.send(unicastConnectedAddress, &packet, sizeof(pairing_datagram_ack_t)) == SUCCESS){
			//transmission success
			dbg("radioDatagram", "[radio>>] Unicast datagram (pairing ack) to Address: %u | Transmission OK | with content: \n", unicastConnectedAddress);
			dbg("radioDatagram", "\t Acknowledgement: %u \n", datagram->acknowledgement);
			dbg("radioDatagram", "\t Type: %u \n", datagram->type);
			//dbg("radioDatagram", "\n");
		}else{
			//transmission error
			//do nothing (retry next triggering event)
			;
		}
	}

	//broadcast transmitter for initial pairing phase
	task void transmitBroadcastDatagram() {
		
		//var allocation
		int i;

		if(!paired){

			//datagram instantiation
			pairing_datagram_t* datagram = (pairing_datagram_t*)(call Packet.getPayload(&packet, sizeof(pairing_datagram_t)));
			
			//passing datagram id
			datagram->identifier = broadcastDatagramID;
			broadcastDatagramID++;

			//passing datagram type
			datagram->type = BROADCAST;

			//passing key
			for (i=0; i<K_LEN; i++){
				datagram->key[i]= KeyP[i];
			}

			//passing address
			datagram->address = TOS_NODE_ID;

			//log
			dbg("radioDatagram", "[radio>>] Broadcast datagram Id: %u is under transmission | Time: %s \n", datagram->identifier,  sim_time_string());
		
			//transmission result
			if(call AMSend.send(AM_BROADCAST_ADDR, &packet, sizeof(pairing_datagram_t)) == SUCCESS){
				//transmission success
				dbg("radioDatagram", "[radio>>] Broadcast datagram Id: %u | Transmission OK | with content: \n", datagram->identifier);
				dbg("radioDatagram", "\t Key: %ux%i \n", datagram->key[0], K_LEN);
				dbg("radioDatagram", "\t Address: %u \n", datagram->address);
				dbg("radioDatagram", "\t Type: %u \n", datagram->type);
				//dbg("radioDatagram", "\n");
			}else{
				//transmission error
				//do nothing (retry next triggering event)
				;
			}

		}
	}

	//unicast transmitter for info datagrams (from child)
	task void transmitChildDatagram() {
	
		//datagram instantiation
		info_datagram_t* datagram = (info_datagram_t*)(call Packet.getPayload(&packet, sizeof(info_datagram_t)));
	
		//prepairing status
		int sendStatus;

		//random generator (1-10)
		uint16_t rnd = (call Random.rand16() % 10) + 1;

		//random weight assignment
		if(rnd>=1 && rnd<=3){
			
			//is standing
			sendStatus = STANDING;

		}else if(rnd>=4 && rnd<=6){
			
			//is walking
			sendStatus = WALKING;

		}else if(rnd>=7 && rnd<=9){
			
			//is running
			sendStatus = RUNNING;

		}else if(rnd==10){
			
			//is falling
			sendStatus = FALLING;

		}else{

			//default
			//is standing
			sendStatus = STANDING;
		}

		//log
		dbg("radioDatagram", "[radio>>] Random: %u | RndStatus %i\n", rnd, sendStatus);

		//parameters assignment
		datagram->type = INFO;
		datagram->posX = call Random.rand16();
		datagram->posY = call Random.rand16();
		datagram->status = sendStatus;
		datagram->identifier = infoDatagramID;

		//log
		dbg("radioDatagram", "[radio>>] Child Unicast datagram Id: %u is under transmission | Time: %s \n", datagram->identifier,  sim_time_string());

		//transmission result
		if(call AMSend.send(unicastConnectedAddress, &packet, sizeof(info_datagram_t)) == SUCCESS){
			//transmission success
			dbg("radioDatagram", "[radio>>] Child Unicast datagram Id: %u | Transmission OK | with content: \n", datagram->identifier);
			dbg("radioDatagram", "\t Status: %i \n", datagram->status);
			dbg("radioDatagram", "\t PosX: %u \n", datagram->posX);
			dbg("radioDatagram", "\t PosY: %u \n", datagram->posY);
			//dbg("radioDatagram", "\n");
		}else{
			//transmission error
			//do nothing (retry next triggering event)
			;
		}

		//increasing id counter for next transmission 
		infoDatagramID++;
	}

	//task called in case of a falling alarm detected in child message
	task void alarmFalling(){

		//log
		dbg("radioDatagram", "[radio>>] !FALLING ALARM! received from child | Address: %u | PosX: %u / PosY: %u \n", unicastConnectedAddress, coord_X, coord_Y);

		//led blinking
		call Leds.led0Toggle();
	}

	//task called in case of a missing alarm detected in child transmission
	task void alarmMissing(){

		//log
		dbg("radioDatagram", "[radio>>] !MISSING ALARM! received from child | Address: %u | PosX: %u / PosY: %u \n", unicastConnectedAddress, coord_X, coord_Y);

		//led blinking
		call Leds.led0Toggle();
		call Leds.led1Toggle();
		call Leds.led2Toggle();
	}

	//////////////////////////////////////////////////////////////////////////////
	//EVENTS

	//stop radio event
	event void SplitControl.stopDone(error_t error){
		;
	}

	//send success event (for generic transmission)
	event void AMSend.sendDone(message_t *msg, error_t error){
	
		//if success
		if(&packet == msg && error == SUCCESS) {

			//only if the ack listener is set to true
			if(ackListener){

				//acknowledgement received
				if(call PacketAcknowledgements.wasAcked(msg)) {

					//log
					dbg("radioDatagram", "[radio>>] ack received at time %s \n", sim_time_string());

					//deactivate ack listener
					ackListener = FALSE;

				}else{

					//log
					dbg("radioDatagram", "[error] ack was not received at time %s \n", sim_time_string());

					//retry to pair
					post transmitUnicastDatagram();
				}
			}
		}
	}

	//transmission incoming event
	event message_t * Receive.receive(message_t *msg, void *payload, uint8_t len){
	
		//var allocation
		int i;
		bool key_match = TRUE;

		//info - datagram instantiation
		info_datagram_t* info_dat = (info_datagram_t*)payload;

		//pairing - datagram instantiation
		pairing_datagram_t* pairing_dat = (pairing_datagram_t*)payload;

		//pairing ack - datagram instantiation
		pairing_datagram_ack_t* pairing_ack_dat = (pairing_datagram_ack_t*)payload;
		
		//type selector for BROADCAST
		if (pairing_dat->type == BROADCAST) {

			//log
			dbg("radioRX", "[radio<<] Incoming transmission from BROADCAST pairing datagram.\n");
			
			//checking the received key
			for (i=0; i<K_LEN; i++){
				if(pairing_dat->key[i] != KeyC[i]){
					key_match = FALSE;
				}
			}

			//if the two keys matches 
			if(key_match){

				//saving pairing address
				dbg("radioRX","[radio<<] TOS_Node: %u has KeyP: %ux%i | PAIRED | with TOS_Node: %u that has KeyC: %ux%i \n", TOS_NODE_ID, KeyP[0], K_LEN, pairing_dat->address, pairing_dat->key[0], K_LEN);
				unicastConnectedAddress = pairing_dat->address;

				//calling unicast ack send
				dbg("radioRX","[radio>>] Sending UNICAST pairing confirmation.. \n");
				post transmitUnicastDatagram();

			}else{

				//keys does not match
				dbg("radioRX", "[radio<<] Datagram received from node %u has not the correct key\n", pairing_dat->address); 
			}
		}
		
		//type selector for UNICAST
		if (pairing_ack_dat->type == UNICAST) {

			//log
			dbg("radioRX", "[radio<<] Incoming transmission from UNICAST pairing datagram.\n");

			//checking the content (ack)
			if (pairing_ack_dat->acknowledgement == 1){

				//set bracelet as paired
				paired = TRUE;

				//led blinking
				call Leds.led2Toggle();

				//stopping broadcast transmission
				dbg("radioRX", "[radio<<] Pairing ACK received | PAIRED | Stopping broadcast transmission.. \n");
				call Timer1.stop();
	
				//starting operative timers
				if(isParent){

					//is parent, start alarm timer
					call Timer3.startPeriodic(T_3);

				}else{

					//is child, start info timer
					call Timer2.startPeriodic(T_2);
				}
			}
		}

		//if the bracelet is paired
		if(paired && isParent){

			//checking the content of the datagram
			if(info_dat->type == INFO){

				//led blinking
				call Leds.led1Toggle();

				//log
				dbg("radioRX", "[radio<<] Incoming transmission from UNICAST INFO datagram.\n");
				dbg("radioRX", "[radio<<] Child status: %u. \n", info_dat->status);

				//saving last coordinates
				coord_X = info_dat->posX;
				coord_Y = info_dat->posY;

				//restarting alarm timer
				call Timer3.stop();
				call Timer3.startPeriodic(T_3);

				//check if in a critical status
				if ((info_dat->status) == FALLING) {
					post alarmFalling();
				}
			}
		}

		//return
		return msg;
	}

}