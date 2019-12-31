-module(server).
% Funciones exportadas
-export([start/0, start/1]).

% Funciones para encender el servidor
start() ->
    ServerPid = spawn(fun() -> init_server() end),
    register(myserver, ServerPid).

start(BootServer) ->
    ServerPid = spawn(fun() -> init_server(BootServer) end),
    register(myserver, ServerPid).

init_server() ->
    process_requests([], [], [self()]).

init_server(BootServer) ->
    BootServer ! {server_join_req, self()},
    process_requests([], [], []).

process_requests(Clients,ClientsName, Servers) ->
    receive
        %% Messages between client and server
        {client_join_req, Name, From} ->
            NewClients = [From|Clients],
            NewClientsName = [Name|ClientsName],
            broadcast(Servers, {join, Name}),
            process_requests(NewClients, NewClientsName, Servers);
        {client_leave_req, Name, From} ->
            NewClients = lists:delete(From, Clients),
            NewClientsName = lists:delete(Name,ClientsName),
            broadcast(Servers, {leave, Name}),
            From ! exit,
            process_requests(NewClients, NewClientsName, Servers);
        {send, Name, Text} ->
            broadcast(Servers, {message,Name,Text}),
            process_requests(Clients, ClientsName, Servers);
        {client_send_file, Name, ClientPid, Nombre} ->
            Mnsaje="Socket preparado para archivo con nombre: \n"  ++ Nombre,
            mensaje(ClientPid,{message,Name,Mnsaje}),
            {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            {ok, Sock} = gen_tcp:accept(LSock),
            file_receiver_loop(Sock,Nombre,[]),
            ok = gen_tcp:close(Sock),
            ok = gen_tcp:close(LSock),

            %%Fun = fun(ServerPid2) -> ServerPid2 ! {server_send_file, Nombre} end,
            %%lists:map(Fun, Servers),

            process_requests(Clients, ClientsName, Servers);

        {client_download_file, Name, ClientPid, Nombre, Ip} ->
            Mnsaje="Socket preparado para archivo con nombre: \n" ++ Nombre,
            mensaje(ClientPid,{message,Name,Mnsaje}),
            Otro = "./script/" ++ Nombre,
            send_file(Ip, Otro, 5678),
            process_requests(Clients, ClientsName, Servers);

        {files_to_Download, Name, ClientPid} ->
            {ok, Lista}=file:list_dir("./script/"),
            Mnsaje=lists:flatten(io_lib:format("~p",[Lista])),
            Add="\n",
            mensaje(ClientPid,{message,Name,Mnsaje}),
            mensaje(ClientPid,{message,Name,Add}),
            process_requests(Clients, ClientsName, Servers);

        {users_in_server, Name, ClientPid} ->
            Mnsaje=lists:flatten(io_lib:format("~p",[ClientsName])),
            mensaje(ClientPid,{message,Name,Mnsaje}),
            process_requests(Clients, ClientsName, Servers);

        {envia_usuario, Name, Texto, Username} ->
            Contador = 1,
            Size = lists:flatlength(Clients)+1,
            func_rec(Contador,ClientsName,Clients,Username,Name,Texto,Servers, Size); 
        %% Messages between servers
        disconnect ->
            NewServers = lists:delete(self(), Servers),
            broadcast(NewServers, {update_servers, NewServers}),
            unregister(myserver);

        %%{server_send_file, Nombre} ->
            %%{ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            %%{ok, Sock} = gen_tcp:accept(LSock),
            %%file_receiver_loop(Sock,Nombre,[]),
            %%ok = gen_tcp:close(Sock),
            %%ok = gen_tcp:close(LSock),
            %%process_requests(Clients, ClientsName, Servers);

        {server_join_req, From} ->
            NewServers = [From|Servers],
            broadcast(NewServers, {update_servers, NewServers}),
            process_requests(Clients, ClientsName, NewServers);
        {update_servers, NewServers} ->
            io:format("[SERVER UPDATE] ~w~n", [NewServers]),
            process_requests(Clients, ClientsName, NewServers);

        RelayMessage -> %% Whatever other message is relayed to its clients
            broadcast(Clients, RelayMessage),
            process_requests(Clients, ClientsName, Servers)
    end.

%% Local Functions
broadcast(PeerList, Message) ->
    Fun = fun(Peer) -> Peer ! Message end,
    lists:map(Fun, PeerList).

mensaje(ClientPid, Mnsaje) ->
    ClientPid ! Mnsaje .

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
    {ok, Fd} = file:open("./descargas/"++Filename, write),
    file:write(Fd, Bs),
    file:close(Fd),
    io:format("~nTransmision finalizado~n").

send_file(Host,FilePath,Port)->
    {ok, Socket} = gen_tcp:connect(Host, Port,[binary, {packet, 0}]),
    Ret=file:sendfile(FilePath, Socket),
    ok = gen_tcp:close(Socket).

% Funcion auxiliar para enviar mensajes "privados".
func_rec(Contador,ClientsName,Clients,Username,Name,Texto,Servers,Size) ->
    case Contador<Size of
      true->
        Val = lists:nth(Contador,ClientsName),
        Val2 = lists:nth(Contador,Clients),
          if
            Val == Username ->
            mensaje(Val2,{message,Name,Texto}),
            process_requests(Clients, ClientsName, Servers);
            true ->
              func_rec(Contador+1,ClientsName,Clients,Username,Name,Texto,Servers,Size)
          end;
      false->process_requests(Clients, ClientsName, Servers)
    end.
