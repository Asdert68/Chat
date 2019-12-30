-module(server).
%% Exported Functions
-export([start/0, start/1]).

-define(TCP_OPTIONS_SERVER, [binary, {packet, 0}, {active, false}]).

%% API Functions
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
            NewClients = [From|Clients],  %% TODO: COMPLETE
            NewClientsName = [Name|ClientsName],
            broadcast(Servers, {join, Name}),  %% TODO: COMPLETE
            process_requests(NewClients, NewClientsName, Servers);  %% TODO: COMPLETE
        {client_leave_req, Name, From} ->
            NewClients = lists:delete(From, Clients),  %% TODO: COMPLETE
            NewClientsName = lists:delete(Name,ClientsName),
            broadcast(Servers, {leave, Name}),  %% TODO: COMPLETE
            From ! exit,
            process_requests(NewClients, NewClientsName, Servers);  %% TODO: COMPLETE
        {send, Name, Text} ->
            broadcast(Servers, {message,Name,Text}),  %% TODO: COMPLETE
            process_requests(Clients, ClientsName, Servers);
        {client_send_file, Name, ClientPid, Nombre} ->
            Mnsaje="Socket preparado para archivo con nombre: \n"  ++ Nombre,
            mensaje(ClientPid,{message,Name,Mnsaje}),
            {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            {ok, Sock} = gen_tcp:accept(LSock),       
            file_receiver_loop(Sock,Nombre,[]),
            ok = gen_tcp:close(Sock),
            ok = gen_tcp:close(LSock),
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
            process_requests(Clients, ClientsName, Servers);  %% TODO: COMPLETE

        {users_in_server, Name, ClientPid} ->
            Mnsaje=lists:flatten(io_lib:format("~p",[ClientsName])),
            mensaje(ClientPid,{message,Name,Mnsaje}),
            process_requests(Clients, ClientsName, Servers);  %% TODO: COMPLETE
        {envia_usuario, Name, Texto, Username} ->
            func_rec(0,ClientsName,Clients,Username,Name,Texto,Servers);
            %%Contador = lists:seq(0,lists:sum(ClientsName)--1),
            %%Val = lists:nth(1,ClientsName),
            %%Val2 = lists:nth(1,Clients),
            %%if
            %%    Val == Username ->
            %%        io:fwrite("true"),
%%
  %%                  mensaje(Val2,{message,Name,Texto}),
    %%                process_requests(Clients, ClientsName, Servers);  %% TODO: COMPLETE

      %%          true ->
        %%            io:fwrite("false")
          %%  end;

            %%while(lists:nth(Contador, ClientsName) != Username)
            %%NewTuple= lists:ukeymerge(0,ClientsName,Clients),
            %%Mnsaje=lists:ukeysort(NewTuple,Username),
            

        %% Messages between servers
        disconnect ->
            NewServers = lists:delete(self(), Servers),  %% TODO: COMPLETE
            broadcast(NewServers, {update_servers, NewServers}),  %% TODO: COMPLETE
            unregister(myserver);
        {server_join_req, From} ->
            NewServers = [From|Servers],  %% TODO: COMPLETE
            broadcast(NewServers, {update_servers, NewServers}),  %% TODO: COMPLETE
            process_requests(Clients, ClientsName, NewServers);  %% TODO: COMPLETE
        {update_servers, NewServers} ->
            io:format("[SERVER UPDATE] ~w~n", [NewServers]),
            process_requests(Clients, ClientsName, NewServers);  %% TODO: COMPLETE

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
    {ok, Fd} = file:open("./script/"++Filename, write),
    file:write(Fd, Bs),
    file:close(Fd),
    io:format("~nTransmision finalizado~n").

send_file(Host,FilePath,Port)->
    {ok, Socket} = gen_tcp:connect(Host, Port,[binary, {packet, 0}]),
    %FilenamePadding = string:left(Filename, 30, $ ), %%Padding with white space
    %gen_tcp:send(Socket,Filename),
    Ret=file:sendfile(FilePath, Socket),
    ok = gen_tcp:close(Socket).

func_rec(Contador,ClientsName,Clients,Username,Name,Texto,Servers) ->
    Val = lists:nth(Contador,ClientsName),
    Val2 = lists:nth(Contador,Clients),
    if
        Val == Username ->
            io:fwrite("true"),
            mensaje(Val2,{message,Name,Texto}),
            process_requests(Clients, ClientsName, Servers);  %% TODO: COMPLETE
        case Contador<lists:sum(ClientsName) of
            true->  io:fwrite("true");%% TODO: COMPLETE
            false->process_requests(Clients, ClientsName, Servers)
        end.
        true ->
            func_rec(Contador,ClientsName,Clients,Username,Name,Texto,Servers)
    end.