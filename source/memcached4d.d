module memcached4d;

// TODO: 
//	documentation
// 	unit tests
//  


/**
Memcached client for the D programming language.
memcached is a distributed caching system (http://www.memcached.org)

The basic idea is this: if you need to share/cache objects between applications you dump them into memcache in a serialized form.
the data can be read back from other programs - even from other programming language - provided that the reader knows how to deserialize the data.
a common way to serialize data is json. Memcached4d uses vibe serialization library to dump your data to json, but you can provide your own serialization method 
by implementing a JSON toJson method in your objects.



A similar tool - with a lot more features is Redis - you may have a look at vibe.db.redis


usage
	auto cache = memcachedConnect('127.0.0.1');
	auto cache = memcachedConnect('127.0.0.1:11211');
	auto cache = memcachedConnect( ['127.0.0.1', '127.0.0.1'] ); // you can connect the the same server multiplie times 
	auto cache = memcachedConnect( '127.0.0.1, 127.0.0.1' ); 
	auto cache = memcachedConnect( '127.0.0.1:11211, 127.0.0.1:11212' ); 
	


   if( cache.store("str_var", "lorem ipsum") == RETURN_STATE.SUCCESS ) {
		writeln("stored successfully");
		writeln( " get back the stored data : {", cache.get!string("str_var") , "}" );
   }else {
   		writeln("not stored")
	}


*/


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
	TCPConnection conn;
	this(string hostString){
		if( hostString.indexOf(':') != -1){
			auto parts = split(hostString, ':');
			this.host = strip(parts[0]);
			this.port = strip(parts[1]).to!ushort;
		} else {
			this.host = strip(hostString);
		}
	}
}

alias MemcachedServer[] MemcachedServers;


/**
 * Use this to connectect to a memcached cluster
 *
 * 
*/
class MemcachedClusterClient : MemcachedClient {


	protected  MemcachedServers servers;

	this(MemcachedServers servers) {
		this.servers = servers;
	}


	override void connect(string key) {
		auto server  = getServer(key);
		this.conn = server.conn;
		if (!conn || !conn.connected) {
			try conn = connectTCP(server.host, server.port);
			catch (Exception e) {
				throw new Exception(format("Failed to connect to memcached server at %s:%s.", server.host, server.port), __FILE__, __LINE__, e);
			}
		}
	}

	override void disconnect() {
		foreach(server; servers) {
			if (server.conn && server.conn.connected)
				server.conn.close();
		}
	}



	MemcachedServer getServer(string key) {
		return servers[ determineServer(key) ];
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
		return md5Of(key)[$-1] % servers.length;
	}

}

enum RETURN_STATE {  SUCCESS, ERROR, STORED, EXISTS, NOT_FOUND, NOT_STORED };

/**
 * Use this to connect and query a memcached server
 * 
 * 
 */ 
class MemcachedClient {
	TCPConnection conn;
	protected MemcachedServer server;

	this() {} // allow adding a different constructor in subclasses
	
	this(string host, ushort port = 11211) {
		server.host = host;
		server.port = port;
		conn = server.conn;
	}

	this(MemcachedServer server){
		this.server = server;
		conn = server.conn;
	}


	void connect(string key) {
		if (!conn || !conn.connected) {
			try conn = connectTCP(server.host, server.port);
			catch (Exception e) {
				throw new Exception(format("Failed to connect to memcached server at %s:%s.", server.host, server.port), __FILE__, __LINE__, e);
			}
		}
	}

	void disconnect() {
		if( conn && conn.connected ){
			conn.close();
		}		
	}


	/**
	 * convert User data type to a string representation
	 */
	protected string serialize(T)(T data) {
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
			value = vibe.data.serialization.serialize!JsonSerializer(data).toString;
		}
		return value;
	}

	/**
	 * store data with key, make it expire after expires secconds
	 * if expires == 0 - data will not expire
	 * 
	 */
	RETURN_STATE store(T)(string key, T data, int expires = 0) {
		connect(key);
		string value = serialize(data);
		conn.write( format("set %s 0 %s %s\r\n%s\r\n", key, expires, value.length.to!string, value) );		
		auto retval = cast(string) conn.readLine();

		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else { return RETURN_STATE.ERROR; }
	}



	RETURN_STATE add(T)(string key, T data, int expires = 0){
		connect(key);
		string value = serialize(data);
		conn.write( format("add %s 0 %s %s\r\n%s\r\n", key, expires, value.length.to!string, value) );

		auto retval = cast(string) conn.readLine();

		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_STORED") { return RETURN_STATE.NOT_STORED ; }
		else { return RETURN_STATE.ERROR; }
	}

	RETURN_STATE replace(T)(string key, T data, int expires = 0){
		connect(key);
		string value = serialize(data);
		conn.write( format("replace %s 0 %s %s\r\n%s\r\n", key, expires, value.length.to!string, value) );

		auto retval = cast(string) conn.readLine();

		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_STORED") { return RETURN_STATE.NOT_STORED ; }
		else { return RETURN_STATE.ERROR; }
	}


	RETURN_STATE append(T)(string key, T data){
		connect(key);
		string value = serialize(data);
		conn.write( format("append %s 0 0 %s\r\n%s\r\n", key, value.length.to!string, value) );

		auto retval = cast(string) conn.readLine();
		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_STORED") { return RETURN_STATE.NOT_STORED ; }
		else { return RETURN_STATE.ERROR; }
	}

	RETURN_STATE prepend(T)(string key, T data){
		connect(key);
		string value = serialize(data);
		conn.write( format("prepend %s 0 0 %s\r\n%s\r\n", key, value.length.to!string, value) );

		auto retval = cast(string) conn.readLine();
		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_STORED") { return RETURN_STATE.NOT_STORED ; }
		else { return RETURN_STATE.ERROR; }
	}


	RETURN_STATE cas(T)(string key, T data, int casId, int expires = 0){
		connect(key);
		string value = serialize(data);
		conn.write( format("cas %s 0 %s %s %s\r\n%s\r\n", key, expires, value.length.to!string, casId, value) );

		auto retval = cast(string) conn.readLine();
		if(retval == "STORED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_FOUND") { return RETURN_STATE.NOT_FOUND ; }
		else if(retval == "EXISTS") { return RETURN_STATE.EXISTS ; }
		else { return RETURN_STATE.ERROR; }
	}


	RETURN_STATE remove(string key, int time = 0){
		connect(key);
		conn.write( format("delete %s %s\r\n", key, time));

		auto retval = cast(string) conn.readLine();
		if(retval == "DELETED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_FOUND") { return RETURN_STATE.NOT_FOUND ; }
		else { return RETURN_STATE.ERROR; }
	}
	alias remove del;

	RETURN_STATE increment(string key, int inc){
		connect(key);
		conn.write( format("incr %s %s\r\n", key, inc));

		auto retval = cast(string) conn.readLine();
		if( retval.isNumeric() ) { return RETURN_STATE.SUCCESS; }
		else if(retval == "NOT_FOUND") { return RETURN_STATE.NOT_FOUND ; }
		else if(retval.startsWith("CLIENT_ERROR")) { return RETURN_STATE.ERROR ; }
		else if(retval == "ERROR" ) { return RETURN_STATE.ERROR ; }
		else { return RETURN_STATE.ERROR; }

	}
	alias increment incr;
	
	
	RETURN_STATE decrement(string key, int dec){
		connect(key);
		conn.write( format("decr %s %s\r\n", key, dec));

		auto retval = cast(string) conn.readLine();
		if( retval.isNumeric() ) { return RETURN_STATE.SUCCESS; }
		else if(retval == "NOT_FOUND") { return RETURN_STATE.NOT_FOUND ; }
		else if(retval.startsWith("CLIENT_ERROR")) { return RETURN_STATE.ERROR ; }
		else if(retval == "ERROR" ) { return RETURN_STATE.ERROR ; }
		else { return RETURN_STATE.SUCCESS; }
	}
	alias decrement decr;
	
	
	RETURN_STATE touch(string key, int expires){
		connect(key);
		conn.write( format("touch %s %s\r\n", key, expires) );

		auto retval = cast(string) conn.readLine();
		if(retval == "TOUCHED") { return RETURN_STATE.SUCCESS ; }
		else if(retval == "NOT_FOUND") { return RETURN_STATE.NOT_FOUND ; }
		else { return RETURN_STATE.ERROR; }
	}


	/**
	 * convert data stored in memcached to the requested type
	 */ 
	protected T deserialize(T)(string data) {
		alias Unqual!T Unqualified;
		
		static if(is(Unqualified: string)){
			return data;
		}else static if(is(Unqualified : int) 
		                || is(Unqualified == bool)
		                || is(Unqualified == double)
		                || is(Unqualified == float)
		                || is(Unqualified : long)
		                ){
			
			return chomp(data).to!T;
		} else {
			Json j = parseJsonString( data);
			return deserializeJson!T(j);
		}
	}



	/**
	 *  get back data from the memcached server,
	 *  return it as type T
	 *  
	 * if the key is not found, it will return an empty string
	 */
	T get(T)(string key){
		connect(key);
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

		return deserialize!T( tmp.data );
	}


	/**
	 * get back data form the memcached server,
	 * return it as type T,
	 * 
	 * populate the casId variable with the cas_unique_id 
	 * 
	 */ 
	T gets(T)(string key, out int casId) {
		connect(key);
		conn.write( std.string.format("gets %s \r\n", key ) );

		auto tmp = std.array.appender!string;
		do{
			string ln = cast(string) conn.readLine();
			if(ln.startsWith("VALUE " ~ key)) {
				auto parts = split(ln);
				casId = parts[ $-1 ].to!int;
				continue;
			} else if(ln == "END") {
				break;
			}
			
			tmp.put(ln ~ "\r\n");
			
		} while( true); 
		
		return deserialize!T( tmp.data );
	}
	
}

/**
 * connect to a memcached server or server cluster
 * 
 * 
 */ 
MemcachedClient memcachedConnect(string hostString){
	if( hostString.indexOf(',') >=0 ) {
		auto hosts = split(hostString, ',');
		return memcachedConnect( hosts);
	}
	return new MemcachedClient( MemcachedServer(hostString) );
}

/**
 * connect to a memcached cluster
 * 
 * 
 */ 
MemcachedClusterClient memcachedConnect( string[] hostStrings ){
	MemcachedServers servers;
	foreach(host; hostStrings){
		servers ~= MemcachedServer(host);
	}
	return new MemcachedClusterClient(servers);
}

