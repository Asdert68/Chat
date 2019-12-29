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
    process_requests([], [self()]).

init_server(BootServer) ->
    BootServer ! {server_join_req, self()},
    process_requests([], []).

process_requests(Clients, Servers) ->
    receive
        %% Messages between client and server
        {client_join_req, Name, From} ->
            NewClients = [From|Clients],  %% TODO: COMPLETE
            broadcast(Servers, {join, Name}),  %% TODO: COMPLETE
            process_requests(NewClients, Servers);  %% TODO: COMPLETE
        {client_leave_req, Name, From} ->
            NewClients = lists:delete(From, Clients),  %% TODO: COMPLETE
            broadcast(Servers, {leave, Name}),  %% TODO: COMPLETE
            From ! exit,
            process_requests(NewClients, Servers);  %% TODO: COMPLETE
        {send, Name, Text} ->
            broadcast(Servers, {message,Name,Text}),  %% TODO: COMPLETE
            process_requests(Clients, Servers);
        {client_send_file, Name, ClientPid, Nombre} ->
        %%"+Nombre+"
            Mnsaje="Socket preparado para archivo con nombre: \n",
            mensaje(ClientPid,{message,Name,Mnsaje}),
            {ok, LSock} = gen_tcp:listen(5678, [binary, {packet, 0}, {active, false}]),
            {ok, Sock} = gen_tcp:accept(LSock),       
            file_receiver_loop(Sock,Nombre,[]),
            ok = gen_tcp:close(Sock),
            ok = gen_tcp:close(LSock),
            process_requests(Clients, Servers);
        %% Messages between servers
        disconnect ->
            NewServers = lists:delete(self(), Servers),  %% TODO: COMPLETE
            broadcast(NewServers, {update_servers, NewServers}),  %% TODO: COMPLETE
            unregister(myserver);
        {server_join_req, From} ->
            NewServers = [From|Servers],  %% TODO: COMPLETE
            broadcast(NewServers, {update_servers, NewServers}),  %% TODO: COMPLETE
            process_requests(Clients, NewServers);  %% TODO: COMPLETE
        {update_servers, NewServers} ->
            io:format("[SERVER UPDATE] ~w~n", [NewServers]),
            process_requests(Clients, NewServers);  %% TODO: COMPLETE

        RelayMessage -> %% Whatever other message is relayed to its clients
            broadcast(Clients, RelayMessage),
            process_requests(Clients, Servers)
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
