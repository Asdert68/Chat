-module(client).
%% Exported Functions
-export([start/2]).

%%-define(TCP_OPTIONS_CLIENT, [binary, {packet, 0}, {active, false}]).

%% API Functions
start(ServerPid, MyName) ->
    ClientPid = spawn(fun() -> init_client(ServerPid, MyName) end),
    process_commands(ServerPid, MyName, ClientPid).

init_client(ServerPid, MyName) ->
    ServerPid ! {client_join_req, MyName, self()},  %% TODO: COMPLETE
    process_requests().

%% Local Functions
%% This is the background task logic
process_requests() ->
    receive
        {join, Name} ->
            io:format("[JOIN] ~s joined the chat~n", [Name]),
            process_requests();
            %% TODO: ADD SOME CODE
        {leave, Name} ->
            io:format("[LEAVE] ~s leaved the chat~n", [Name]),
            %% TODO: ADD SOME CODE
            process_requests();
        {message, Name, Text} ->
            io:format("[~s] ~s", [Name, Text]),
            process_requests();
            %% TODO: ADD SOME CODE
        exit ->
            ok
    end.

%% This is the main task logic
process_commands(ServerPid, MyName, ClientPid) ->
    %% Read from standard input and send to server
    Text = io:get_line("-> "),
    if
        Text  == "exit\n" ->
            ServerPid ! {client_leave_req, MyName, ClientPid},  %% TODO: COMPLETE
            ok;
        Text == "message\n" ->
            Nombre = string:trim(io:get_line("[ENTER FILENAME]->")),

            ServerPid ! {client_send_file, MyName, ClientPid, Nombre},  %% TODO: COMPLETE
            Otro = string:trim(io:get_line("[ENTER FILEPATH]->")),
            send_file("localhost", Otro, 5678),
            process_commands(ServerPid, MyName, ClientPid);
        true ->
            ServerPid ! {send, MyName, Text},  %% TODO: COMPLETE
            process_commands(ServerPid, MyName, ClientPid)
    end.

%Funcion para generar el socket de conexion entre servidor y client_leave_req
  send_file(Host,FilePath,Port)->
    {ok, Socket} = gen_tcp:connect(Host, Port,[binary, {packet, 0}]),
    %FilenamePadding = string:left(Filename, 30, $ ), %%Padding with white space
    %gen_tcp:send(Socket,Filename),
    Ret=file:sendfile(FilePath, Socket),
    ok = gen_tcp:close(Socket).
