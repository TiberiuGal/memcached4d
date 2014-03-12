module memcached4d;

import std.stdio;
import std.string;
import std.conv;


import vibe.core.net,
	vibe.stream.operations,
	vibe.data.serialization,
	vibe.data.json;



struct MemcachedServer {
	string host;
	ushort port = 11211;
}

alias MemcachedServer[] MemcachedServers;

// TODO: memcached cluster
//	documentation
// unit tests


/**
 * 
 * 
*/
class MemcachedCluster {


	protected MemcachedClient[] clients;

	this(MemcachedServers servers) {
		foreach(server; servers){
			clients ~= new MemcachedClient(server);
		}
	}


	void store(T)(string key, T data){
		
	}

}


class MemcachedClient {
	TCPConnection conn;
	protected MemcachedServer server;

	
	this(string host, ushort port = 11211) {
		server.host = host;
		server.port = port;
	}

	this(MemcachedServer server){
		this.server = server;
	}
	
	void connect() {
		if (!conn || !conn.connected) {
			try conn = connectTCP(server.host, server.port);
			catch (Exception e) {
				throw new Exception(format("Failed to connect to memcached server at %s:%s.", server.host, server.port), __FILE__, __LINE__, e);
			}
		}
	}
	
	void store(T)(string key, T data) {
		connect();

		alias Unqual!T Unqualified;

		string value;
		static if (is(Unqualified : string)) {
			 value = data;
		} else static if(is(Unqualified : int) 
		                 || is(Unqualified == bool)
		                 || is(Unqualified == double)
		                 || is(Unqualified == float)
		                 || is(Unqualified : long)
		                 ){
			value = data.to!string;
		}
		else static if( isJsonSerializable!Unqualified ){
			value = data.toJson;
		} else  {
			value = serialize!JsonSerializer(data).toString;
		}
		conn.write("set " ~ key ~ " 0 0 " ~ value.length.to!string ~ "\r\n" ~ value ~"\r\n");
		

	}

	T get(T)(string key){
		connect();
		alias Unqual!T Unqualified;
		conn.write( std.string.format("get %s \r\n", key ) );
		auto tmp = std.array.appender!string;
		do{
			string ln = cast(string) conn.readLine();
			if(ln.startsWith("VALUE " ~ key))
				continue;
			else if(ln == "END") 
				break;

			tmp.put(ln ~ "\r\n");

		} while( true); 

		static if(is(Unqualified: string)){
			return tmp.data;
		}else static if(is(Unqualified : int) 
		                || is(Unqualified == bool)
		                || is(Unqualified == double)
		                || is(Unqualified == float)
		                || is(Unqualified : long)
		                ){
			return tmp.data.to!T;
		} else {
			Json j = parseJsonString( tmp.data);
			return deserializeJson!T(j);
		}


	}
	
}



