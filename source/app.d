import std.stdio;

import memcached4d;
import vibe.d;
void main(string[] args)
{
	// connect to a memcached server

	auto d = memcachedConnect("192.168.1.215, 192.168.1.215, 192.168.1.215");

	/* 
	 // connect to a cluster 
	MemcachedServer s;
	s.host = "192.168.1.215";

	MemcachedServers servers;
	servers ~= s;

	auto d = new MemcachedClusterClient(servers);
	*/

	// store a string;
	d.store("geta1", "Hello World!");
	// get back the stored string
	writeln( d.get!string("geta1"));

	//append data to a stored string
	d.append("geta1", " from memcached");
	writeln( d.get!string("geta1"));




	// store and int
	d.store("int_value", 2);
	// increment
	d.increment("int_value", 4);
	assert( d.get!int("int_value") == 6, "int value incremented");
	//decrement
	d.decr("int_value", 3);
	assert(d.get!int("int_value") == 3, "int value decremented" );


	Test t;
	// store a User defined type
	d.store("p1", t);
	// get back the stored data
	writeln( d.get!Test("p1"));

	int casId;
	//get back a casID
	auto p2 = d.gets!Test("p1", casId);
	writefln("casId for p1 %s", casId); 

	p2.a = 4;
	// update an object if not modified since the last query
	d.cas("p1", p2, casId);
	writeln( d.get!Test("p1"));

}


struct Test {
	public int a = 3;
	public string b = "geta";
}