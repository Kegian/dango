/**
 * Реализация упрощенного Rpc протокола
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.simple;

private
{
    import std.string : strip;

    import vibe.core.log;

    import dango.service.protocol.core;
    import dango.service.serializer.core;
    import dango.service.transport.core;
}



class SimpleRpcServerProtocol : RpcServerProtocol
{
    private
    {
        Dispatcher _dispatcher;
        Serializer _serializer;
    }


    void initialize(Dispatcher dispatcher, Serializer serializer, Properties config)
    {
        _dispatcher = dispatcher;
        _serializer = serializer;
    }


    ubyte[] handle(ubyte[] data)
    {
        UniNode uniReq;
        try
            uniReq = _serializer.deserialize(data);
        catch (Exception e)
        {
            logInfo("Error deserialize: (%s)", e.msg);
            return createErrorBody(createErrorByCode(
                    ErrorCode.PARSE_ERROR, e.msg));
        }

        string method;
        UniNode* id;
        UniNode params;

        if (uniReq.type != UniNode.Type.object)
            return createErrorBody(createEmptyErrorByCode(
                    ErrorCode.PARSE_ERROR));

        UniNode[string] uniReqMap = uniReq.via.map;
        try
        {
            auto vMethod = "method" in uniReqMap;
            if (!vMethod || !(vMethod.type == UniNode.Type.text
                        || vMethod.type == UniNode.Type.raw))
            {
                logInfo("Not found method");
                return createErrorBody(createErrorByCode!string(
                        ErrorCode.INVALID_REQUEST,
                        "Parameter method is invalid"));
            }

            method = (*vMethod).get!string.strip;
            id = "id" in uniReqMap;
            params = UniNode.emptyObject();
            if (auto pv = "params" in uniReqMap)
                params = *pv;
        }
        catch (Exception e)
        {
            logInfo("Error extract meta info: (%s)", e.msg);
            return createErrorBody(createErrorByCode(
                    ErrorCode.SERVER_ERROR, e.msg));
        }

        if (_dispatcher.existst(method))
        {
            try
            {
                UniNode uniRes = _dispatcher.handler(method, params);
                return createResultBody(id, uniRes);
            }
            catch (RpcException e)
                return createErrorBody(e.error);
            catch (Exception e)
            {
                logInfo("Error execute handler: (%s)", e.msg);
                return createErrorBody(createErrorByCode(
                        ErrorCode.SERVER_ERROR, e.msg));
            }
        }
        else
            return createErrorBody(createEmptyErrorByCode(
                ErrorCode.METHOD_NOT_FOUND));
    }

private:

    ubyte[] createErrorBody(T)(RpcError!T error)
    {
        RpcError!UniNode uniError;
        uniError.code = error.code;
        uniError.message = error.message;
        if (!error.data.isNull)
            uniError.data = marshalObject!T(error.data);
        return createErrorBody(uniError);
    }


    ubyte[] createErrorBody(RpcError!UniNode error)
    {
        UniNode[string] response;
        response["id"] = UniNode();
        UniNode[string] err;
        err["code"] = UniNode(error.code);
        err["message"] = UniNode(error.message);
        if (!error.data.isNull)
            err["data"] = error.data.get;
        response["error"] = UniNode(err);
        return _serializer.serialize(UniNode(response));
    }


    ubyte[] createResultBody(UniNode* id, UniNode result)
    {
        if (id is null)
            return [];

        UniNode[string] response;
        response["id"] = *id;
        response["result"] = result;
        return _serializer.serialize(UniNode(response));
    }
}


class SimpleRpcClientProtocol : RpcClientProtocol
{
    private
    {
        Serializer _serializer;
        ClientTransport _transport;
    }


    this() {}


    this(Serializer serializer, ClientTransport transport)
    {
        initialize(serializer, transport);
    }


    void initialize(Serializer serializer, ClientTransport transport)
    {
        _serializer = serializer;
        _transport = transport;
    }


    UniNode request(string cmd, UniNode params)
    {
        UniNode[string] request;
        request["id"] = UniNode(1);
        request["method"] = UniNode(cmd);
        request["params"] = params;

        ubyte[] resData;
        try
        {
            auto reqData = _serializer.serialize(UniNode(request));
            resData = _transport.request(reqData);
        }
        catch (Exception e)
            throw new RpcException(ErrorCode.SERVER_ERROR, e.msg);

        if (resData.length <= 0)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Empty response");

        auto response = _serializer.deserialize(resData);
        if (response.type != UniNode.Type.object)
            throw new RpcException(ErrorCode.INTERNAL_ERROR, "Error response");

        auto responseMap = response.via.map;
        if (auto error = "error" in responseMap)
        {
            int errorCode;
            string errorMsg;
            auto errorMap = (*error).via.map;

            if (auto codePtr = "code" in errorMap)
                errorCode = (*codePtr).get!int;

            if (auto msgPtr = "message" in errorMap)
                errorMsg = (*msgPtr).get!string;

            if (auto dataPtr = "data" in errorMap)
                throw new RpcException(errorCode, errorMsg, *dataPtr);
            else
                throw new RpcException(errorCode, errorMsg);
        }
        else if (auto result = "result" in responseMap)
            return *result;

        throw new RpcException(ErrorCode.INTERNAL_ERROR, "Not found result");
    }
}
