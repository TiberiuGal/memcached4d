import std.stdio;

import memcached4d;
import vibe.d;
void main(string[] args)
{
	Test t;
	auto d = new MemcachedClient("192.168.0.11");
	d.store("geta1", "polonik mare");
	d.store("p1", t);
	
	writeln( d.get!string("geta1"));
	writeln( d.get!Test("p1"));
}


struct Test {
	public int a = 3;
	public string b = "geta";
}