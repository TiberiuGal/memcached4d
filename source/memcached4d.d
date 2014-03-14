module memcached4d;

// TODO: memcached cluster
//	documentation
// 	unit tests
//  add expiration info
//  error handling and reporting
//  optionally implement all commands


import std.stdio;
import std.string, 
	std.conv,
	std.digest.md;



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
 * this is confusing, but ...
 * a MemcachedCluster is a a client to a cluser of server
 * it holds a collection of clients ( each client connects to one server )
 * so client and server here are used interchangeably - but they mean the same thing.
 * 
*/
class MemcachedCluster {


	protected MemcachedClient[] clients;

	this(MemcachedServers servers) {
		foreach(server; servers){
			clients ~= new MemcachedClient(server);
		}
	}



	/**
	 *  store the value with one of the server
	 * 
	 *  compute hash
	 *  determine server 
	 *	connect client to server
	 *	run client.store
	*/
	void store(T)(string key, T data, int expires = 0){
		return getServer.get(key, data, expires);
	}


	/**
	 * 	get the value form one of the servers
	 * 
	 *  compute hash
	 *  determine server 
	 *	connect client to server
	 *	return client.get
	*/
	T get(T)(string key) {
		return getServer.get(key);
	}

	void remove(string key, int time = 0){
		getServer(key).remove(key, time);
	}
	alias remove del;
	
	void increment(string key, int inc){
		getServer(key).increment(key, inc);
	}
	alias increment incr;	
	
	void decrement(string key, int dec){
		getServer(key).decrement(key, dec);
	}
	alias decrement decr;	
	
	void touch(string key, int expires){
		getServer(key).touch(key, expires); 
	}



	MemcachedClient getServer(string key) {
		return   clients[ determineServer(key) ];
	}

	int determineServer(string key){
		return equalWeights(key);
	}

	/**
	 * use this for sharding - when all servers have equal weights	 * 
	 * 
	 * hash the key, get the last byte
	 * get the modulo of that last byte to the length of servers
	 */ 
	int equalWeights(string key){
		return md5Of(key)[$-1] % clients.length;
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
		
		auto retval = cast(string) conn.readLine();
		//if(retval == "STORED") ;
		//if(retval == "ERROR") ;
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

		//writefln("dumping data for key %s = {%s}", key, tmp.data);

		static if(is(Unqualified: string)){
			return tmp.data;
		}else static if(is(Unqualified : int) 
		                || is(Unqualified == bool)
		                || is(Unqualified == double)
		                || is(Unqualified == float)
		                || is(Unqualified : long)
		                ){

			return chomp(tmp.data).to!T;
		} else {
			Json j = parseJsonString( tmp.data);
			return deserializeJson!T(j);
		}


	}
	
}



