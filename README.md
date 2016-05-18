# IoT-SmartBracelet
Politecnico di Milano - Internet of Things Project - TinyOS Smart Bracelet development & simulation with Cooja


### Info ###

The scope is to design, implement and test a software prototype for a
smart bracelet. 
The bracelet is meant to be worn by both a child and her/his
parent to keep track of the child position and trigger alerts when a child goes
too far. 

### How it works ###

The operation of the smart bracelet couple is as follows:<br/>
*Pairing phase, that it used to uniquely couple the
two devices.<br/>
*Operation mode: in this phase, the parent’s bracelet listen for messages
on the radio and accepts only messages coming from the child’s
bracelet.<br/>
*Alert Mode: upon reception of an INFO message, the parent’s bracelet
reads the content of the message. If the kinematic status is FALLING,
the bracelet sends a FALL alarm, reporting the position X,Y of the
children. If the parent’s bracelet does not receive any message, after
one minute from the last received message a MISSING alarm is sent
reporting the last position received.<br/>

### Authors ###

* Everything in this repository was developed by Leonardo Turchi and Massimiliano Paci
