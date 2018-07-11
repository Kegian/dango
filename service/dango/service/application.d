/**
 * Реализация приложения для содания приложения сервиса
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-24
 */

module dango.service.application;

public
{
    import dango.system.application;
}

private
{
    import std.format : fmt = format;

    import dango.system.properties : getOrEnforce, getNameOrEnforce;
    import dango.system.exception : configEnforce;
    import dango.system.container : resolveFactory;

    import dango.service.serialization;
    import dango.service.protocol;
    import dango.service.transport;
}


/**
 * Приложение позволяет инициализировать веб приложение
 */
interface ServiceApplication : DaemonApplication
{
    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeServiceApplication(Properties config);

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeServiceApplication(int exitCode);
}


/**
 * Приложение позволяет использовать с сервисами
 */
abstract class BaseServiceApplication : BaseDaemonApplication, ServiceApplication
{
    private ServerTransport[] _transports;


    this(string name, string release)
    {
        super(name, release);
    }


    this(string name, SemVer release)
    {
        super(name, release);
    }


    void initializeGlobalDependencies(ApplicationContainer container, Properties config)
    {
        container.registerContext!SerializerContext;
        container.registerContext!ProtocolContext;
        container.registerContext!TransportContext;
    }


    final void initializeDaemon(Properties config)
    {
        initializeServiceApplication(config);

        auto sConfgs = config.getOrEnforce!Properties("service",
                "Not found service configurations");

        foreach (Properties servConf; sConfgs.getArray())
        {
            if (servConf.getOrElse("enabled", false))
            {
                auto container = createContainer(servConf);
                auto tr = createServiceTransport(container, servConf);
                tr.listen();
                _transports ~= tr;
            }
        }
    }


    final int finalizeDaemon(int exitCode)
    {
        foreach (ServerTransport tr; _transports)
            tr.shutdown();
        return finalizeServiceApplication(exitCode);
    }


private:


    ServerTransport createServiceTransport(ApplicationContainer container,
            Properties servConf)
    {
        string serviceName = servConf.getOrElse!string("name", "Undefined");
        logInfo("Configuring service '%s'", serviceName);

        Properties serConf = servConf.getOrEnforce!Properties("serializer",
                "Not defined serializer config for service '" ~ serviceName ~ "'");
        Properties protoConf = servConf.getOrEnforce!Properties("protocol",
                "Not defined protocol config for service '" ~ serviceName ~ "'");
        Properties trConf = servConf.getOrEnforce!Properties("transport",
                "Not defined transport config for service '" ~ serviceName ~ "'");

        string serializerName = getNameOrEnforce(serConf,
                "Not defined serializer name for service '" ~ serviceName ~ "'");
        string protoName = getNameOrEnforce(protoConf,
                "Not defined protocol name for service '" ~ serviceName ~ "'");
        string transportName = getNameOrEnforce(trConf,
                "Not defined transport name for service '" ~ serviceName ~ "'");

        // Т.к. протокол может быть только один, то конфиги сериализатора
        // вынес на верхний уровень
        auto serFactory = container.resolveFactory!Serializer(serializerName);
        configEnforce(serFactory !is null,
                fmt!"Serializer '%s' not register"(serializerName));
        Serializer serializer = serFactory.create(serConf);
        logInfo("Use serializer '%s'", serializerName);

        auto protoFactory = container.resolveFactory!(ServerProtocol,
                ApplicationContainer, Serializer)(protoName);
        configEnforce(protoFactory !is null,
                fmt!"Protocol '%s' not register"(protoName));
        ServerProtocol protocol = protoFactory.create(protoConf, container, serializer);
        logInfo("Use protocol '%s'", protoName);

        auto trFactory = container.resolveFactory!(ServerTransport,
                ApplicationContainer, ServerProtocol)(transportName);
        configEnforce(trFactory !is null,
                fmt!"Transport '%s' not register"(transportName));
        ServerTransport transport = trFactory.create(trConf, container, protocol);
        logInfo("Use transport '%s'", transportName);

        return transport;
    }
}

