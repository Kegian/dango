/**
 * Общий модуль для протоколов
 *
 * Copyright: (c) 2015-2017, Milofon Project.
 * License: Subject to the terms of the BSD license, as written in the included LICENSE.txt file.
 * Author: <m.galanin@milofon.org> Maksim Galanin
 * Date: 2018-01-28
 */

module dango.service.protocol.core;

public
{
    import proped : Properties;
    import dango.system.container : ApplicationContainer;

    import dango.service.types;
    import dango.service.serialization : Serializer;
}

private
{
    import dango.system.container;
}


/**
 * Интерфейс серверного протокола взаимодействия
 */
interface ServerProtocol
{
    /**
     * Метод-обработик входящейго запроса
     * Params:
     * data = Бинарные данные
     * Return: Ответ в бинарном виде
     */
    Bytes handle(Bytes data);
}



abstract class BaseServerProtocol : ServerProtocol
{
    protected Serializer serializer;


    this(Serializer serializer)
    {
        this.serializer = serializer;
    }
}



abstract class BaseServerProtocolFactory(string N) :
    ComponentFactory!(ServerProtocol, ApplicationContainer, Serializer), Named
{
    mixin NamedMixin!N;
}

