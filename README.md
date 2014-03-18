memcached4d
===========

Memcached client for the D programming language.

memcached is a distributed caching system (http://www.memcached.org)

The basic idea is this: if you need to share/cache objects between applications you dump them into memcache in a serialized form.
the data can be read back from other programs - even from other programming language - provided that the reader knows how to deserialize the data.
a common way to serialize data is json. Memcached4d uses vibe serialization library to dump your data to json, but you can provide your own serialization method 
by implementing a JSON toJson method in your objects.



A similar tool - with a lot more features is Redis - you may have a look at vibe.db.redis


usage
```d
	auto cache = memcachedConnect("127.0.0.1");
	auto cache = memcachedConnect("127.0.0.1:11211");
	auto cache = memcachedConnect( ["127.0.0.1", "127.0.0.1"] ); // you can connect the the same server multiplie times 
	auto cache = memcachedConnect( "127.0.0.1, 127.0.0.1" ); 
	auto cache = memcachedConnect( "127.0.0.1:11211, 127.0.0.1:11212" ); 
	


   if( cache.store("str_var", "lorem ipsum") == RETURN_STATE.SUCCESS ) {
		writeln("stored successfully");
		writeln( " get back the stored data : {", cache.get!string("str_var") , "}" );
   }else {
   		writeln("not stored");
	}
```

