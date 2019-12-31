-module(client).
%% Exported Functions
-export([start/2]).


%% API Functions
start(ServerPid, MyName) ->
    ClientPid = spawn(fun() -> init_client(ServerPid, MyName) end),
    process_commands(ServerPid, MyName, ClientPid).

init_client(ServerPid, MyName) ->
    ServerPid ! {client_join_req, MyName, self()},
    process_requests().

%% Local Functions
%% This is the background task logic
process_requests() ->
    receive
        {join, Name} ->
            io:format("[JOIN] ~s se unió al chat~n", [Name]),
            process_requests();

        {leave, Name} ->
            io:format("[LEAVE] ~s dejó el chat~n", [Name]),

            process_requests();
        {message, Name, Text} ->
            io:format("[~s] ~s", [Name, Text]),
            process_requests();

        exit ->
            ok
    end.

%% This is the main task logic
process_commands(ServerPid, MyName, ClientPid) ->
    %% Read from standard input and send to server
    Text = io:get_line("-> "),
    if
        Text  == "exit\n" ->
            ServerPid ! {client_leave_req, MyName, ClientPid},
            ok;

        Text == "Subida\n" ->
            Nombre = string:trim(io:get_line("[Introduce Nombre del Archivo]->")),
            ServerPid ! {client_send_file, MyName, ClientPid, Nombre},
            Otro = string:trim(io:get_line("[Introduce Dirección del Archivo]->")),
            send_file("localhost", Otro, 5678),
            process_commands(ServerPid, MyName, ClientPid);

        Text == "ListaArchivos\n" ->
            ServerPid ! {files_to_Download, MyName, ClientPid},
            process_commands(ServerPid, MyName, ClientPid);

        Text == "Descarga\n" ->
            Nombre = string:trim(io:get_line("[Introduce Nombre del Archivo]->")),
            Ip=local_ip_v4(),
            ServerPid ! {client_download_file, MyName, ClientPid, Nombre, Ip},
            {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            {ok, Sock} = gen_tcp:accept(LSock),
            file_receiver_loop(Sock,Nombre,[]),
            ok = gen_tcp:close(Sock),
            ok = gen_tcp:close(LSock),
            process_commands(ServerPid, MyName, ClientPid);

        Text == "Usuarios\n" ->
            ServerPid ! {users_in_server, MyName, ClientPid},
            process_commands(ServerPid,MyName,ClientPid);

        Text == "Envia\n" ->
            Nombre = string:trim(io:get_line("[Introduce Nombre del Usuario]->")),
            Texto = (io:get_line("[Introduce el Mensaje]->")),
            ServerPid ! {envia_usuario, MyName, Texto, Nombre},
            process_commands(ServerPid,MyName,ClientPid);

        true ->
            ServerPid ! {send, MyName, Text},
            process_commands(ServerPid, MyName, ClientPid)
    end.

%Funcion para generar el socket de conexion entre servidor y client_leave_req
send_file(Host,FilePath,Port)->
    {ok, Socket} = gen_tcp:connect(Host, Port,[binary, {packet, 0}]),
    Ret=file:sendfile(FilePath, Socket),
    ok = gen_tcp:close(Socket).

file_receiver_loop(Socket,Filename,Bs)->
    io:format("~nTransmision en curso~n"),
    case gen_tcp:recv(Socket, 0) of
    {ok, B} ->
        file_receiver_loop(Socket, Filename,[Bs, B]);
    {error, closed} ->
        save_file(Filename,Bs)
end.

save_file(Filename,Bs) ->
    io:format("~nFilename: ~p",[Filename]),
    {ok, Fd} = file:open("./descargasCliente/"++Filename, write),
    file:write(Fd, Bs),
    file:close(Fd),
    io:format("~nTransmision finalizado~n").

%Funcion auxiliar que se encarga de enviar la ip del cliente al servidor.
local_ip_v4() ->
    {ok, Addrs} = inet:getifaddrs(),
    hd([
         Addr || {_, Opts} <- Addrs, {addr, Addr} <- Opts,
         size(Addr) == 4, Addr =/= {127,0,0,1}
    ]).
