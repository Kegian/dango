/**
 * Реализация приложения для содания веб приложения
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-06-26
 */

module dango.web.application;

public
{
    import dango.system.application;
}

private
{
    import dango.system.properties : getOrEnforce;
    import dango.system.container : registerFactory, resolveFactory;

    import dango.web.server;
    import dango.web.middlewares;
    import dango.web.controllers;
}


/**
 * Приложение позволяет инициализировать веб приложение
 */
interface WebApplication : DaemonApplication
{
    /**
     * Инициализация сервиса
     * Params:
     * config = Общая конфигурация приложения
     */
    void initializeWebApplication(Properties config);

    /**
     * Завершение работы сервиса
     * Params:
     * exitCode = Код возврата
     */
    int finalizeWebApplication(int exitCode);
}


/**
 * Базовая реализация приложения позволяет инициализировать веб приложение
 */
abstract class BaseWebApplication : BaseDaemonApplication, WebApplication
{
    private
    {
        WebApplicationServer[] _servers;
    }


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
        container.registerFactory!(WebApplicationServerFactory, WebApplicationServer);
        container.registerContext!WebMiddlewaresContext;
        container.registerContext!WebControllersContext;
    }


    final void initializeDaemon(Properties config)
    {
        initializeWebApplication(config);

        auto webConfigs = config.getOrEnforce!Properties("web",
                "Not found web application configurations");

        foreach (Properties webConf; webConfigs.getArray())
        {
            if (webConf.getOrElse("enabled", false))
            {
                auto container = createContainer(webConf);
                auto serverFactory = container.resolveFactory!(WebApplicationServer,
                        ApplicationContainer);
                auto server = serverFactory.create(webConf, container);
                server.listen();
                _servers ~= server;
            }
        }
    }


    final int finalizeDaemon(int exitCode)
    {
        foreach (WebApplicationServer server; _servers)
            server.shutdown();
        return finalizeWebApplication(exitCode);
    }
}
