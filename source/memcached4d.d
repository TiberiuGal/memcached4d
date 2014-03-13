module memcached4d;

// TODO: memcached cluster
//	documentation
// 	unit tests
//  add expiration info
//  error handling and reporting
//  optionally implement all commands


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



/**
 * Use this to connectect to a memcached cluster
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
		// compute hash
		// determine server 
		// connect client to server
		// return client.store 
	}

	T get(T)(string key) {
		// compute hash
		// determine server 
		// connect client to server
		// return client.get 
	}

}

/**
 * Use this to connect and query a memcached server
 * 
 * 
 */ 
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



	/**
	 * store a data 
	 * 
	 */
	void store(T)(string key, T data, int expires = 0) {
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
		conn.write( format("set %s 0 %s %s\r\n%s\r\n", key, expires, value.length.to!string, value) );
		
		//auto retval = cast(string) conn.readLine();
		//if(retval == "STORED") ;
		//if(retval == "ERROR") ;
	}

	void remove(string key, int time = 0){
		connect();
		conn.write( format("delete %s %s\r\n", key, time));
		conn.readLine;
	}
	
	void increment(string key, int inc){
		connect();
		conn.write( format("incr %s %s\r\n", key, inc));
		conn.readLine;
	}
	alias increment incr;
	
	
	void decrement(string key, int dec){
		connect();
		conn.write( format("decr %s %s\r\n", key, dec));
		conn.readLine;
	}
	alias decrement decr;
	
	
	void touch(string key, int expires){
		connect();
		conn.write( format("touch %s %s\r\n", key, expires) );
		conn.readLine();
	}



	void remove(string key, int time = 0){
		connect();
		conn.write( format("delete %s %s\r\n", key, time));
		conn.readLine;
	}
	alias remove del;

	void increment(string key, int inc){
		connect();
		conn.write( format("incr %s %s\r\n", key, inc));
		conn.readLine;
	}
	alias increment incr;
	
	
	void decrement(string key, int dec){
		connect();
		conn.write( format("decr %s %s\r\n", key, dec));
		conn.readLine;
	}
	alias decrement decr;
	
	
	void touch(string key, int expires){
		connect();
		conn.write( format("touch %s %s\r\n", key, expires) );
		conn.readLine();
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



