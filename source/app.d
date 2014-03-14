import std.stdio;

import memcached4d;
import vibe.d;
void main(string[] args)
{
	Test t;
	auto d = new MemcachedClient("192.168.1.215");
	d.store("geta1", "polonik mare");
	d.store("p1", t);
	
	writeln( d.get!string("geta1"));
	writeln( d.get!Test("p1"));

	d.store("int_value", 2);
	d.increment("int_value", 4);
	assert( d.get!int("int_value") == 6, "int value incremented");
	d.decr("int_value", 3);
	assert(d.get!int("int_value") == 2, "int value decremented" );

}


struct Test {
	public int a = 3;
	public string b = "geta";
}