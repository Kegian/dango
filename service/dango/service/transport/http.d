/**
 * Модуль транспортного уровня на основе HTTP
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.transport.http;

private
{
    import std.exception : enforce;
    import vibe.stream.operations : readAll;
    import vibe.inet.url : URL;
    import vibe.http.router;
    import vibe.http.client;
    import vibe.core.log;

    import dango.controller.core : createOptionCORSHandler, handleCors;
    import dango.controller.http : loadServiceSettings;

    import dango.service.transport.core;
}


class HTTPServerTransport : ServerTransport
{
    private
    {
        HTTPListener _listener;
    }


    void listen(RpcServerProtocol protocol, Properties config)
    {
        auto router = new URLRouter();
        auto httpSettings = loadServiceSettings(config);
        string entrypoint = config.getOrElse!string("entrypoint", "/");

        void handler(HTTPServerRequest req, HTTPServerResponse res)
        {
            handleCors(req, res);
            ubyte[] data = protocol.handle(req.bodyReader.readAll());
            res.writeBody(data);
        }

        router.post(entrypoint, &handler);
        router.match(HTTPMethod.OPTIONS, entrypoint, createOptionCORSHandler());

        _listener = listenHTTP(httpSettings, router);
    }


    void shutdown()
    {
        _listener.stopListening();
        logInfo("Transport HTTP Stop");
    }
}


class HTTPClientTransport : ClientTransport
{
    private
    {
        URL _entrypoint;
        HTTPClientSettings _settings;
    }


    this(URL entrypoint, HTTPClientSettings settings)
    {
        validateEntrypoint(entrypoint);
        _entrypoint = entrypoint;
        _settings = settings;
    }


    ubyte[] request(ubyte[] bytes)
    {
        HTTPClientResponse res = requestHTTP(_entrypoint, (scope HTTPClientRequest req) {
            req.method = HTTPMethod.POST;
            req.writeBody(bytes);
        }, _settings);
        return res.bodyReader.readAll();
    }


private:


    void validateEntrypoint(URL url)
    {
        version(UnixSocket) {
            enforce(url.schema == "http" || url.schema == "https" || url.schema == "http+unix"
                    || url.schema == "https+unix", "URL schema must be http(s) or http(s)+unix.");
        } else {
            enforce(url.schema == "http" || url.schema == "https", "URL schema must be http(s).");
        }
        enforce(url.host.length > 0, "URL must contain a host name.");
    }
}
