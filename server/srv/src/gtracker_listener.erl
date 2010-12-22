-module(gtracker_listener).

-author(dmitryme).

-behaviour(mds_gen_server).

-include_lib("stdlib/include/qlc.hrl").
-include("common_defs.hrl").

-export([start/1, stop/0, on_start/1, on_stop/2, on_msg/3, on_amsg/2, on_info/2]).

-export([start_in_shell/0]).

-import(mds_utils, [get_param/2, get_param/3]).


-define(TIMEOUT, 100).
-define(PORT, 7777).
-define(MOD, {global, ?MODULE}).

-record(state, {lsocket, db, protocol, opts}).

start_in_shell() ->
   start([{root_dir, "/tmp/gtracker"}, {db, nodb}, {log_level, debug}]).

start(Opts) ->
   mds_gen_server:start(?MOD, Opts).

stop() ->
   mds_gen_server:stop(?MOD).

on_start(Opts) ->
   SelfOpts = get_param('self', Opts),
   ServerOpts = get_param(mds_server, Opts),
   Port = get_param(port, SelfOpts, ?PORT),
   Db = get_param(db, SelfOpts),
   Proto = get_param(protocol, SelfOpts, gtracker_protocol),
   {ok, ListenSocket} = gen_tcp:listen(Port, [binary, {packet, 1}, {reuseaddr, true}, {active, once}]),
   log(info, "Started"),
   {ok, #state{lsocket = ListenSocket, db = Db, protocol = Proto, opts = Opts}, ?TIMEOUT}.

on_stop(Reason, _State) ->
   log(info, "Stopped <~p>.", [Reason]),
   ok.

on_msg(stop, _From, State) ->
   {stop, normal, stopped, State};

on_msg(_Msg, _Who, State) ->
   {norepy, State, 0}.

on_amsg({log, LogLevel, Text}, State) ->
   log(LogLevel, Text),
   {noreply, State, 0};

on_amsg({log, LogLevel, Format, Params}, State) ->
   log(LogLevel, Format, Params),
   {noreply, State, 0};

on_amsg(_Msg, State) ->
   {norepy, State, 0}.

on_info(_Msg, State) ->
   ListenSocket = State#state.lsocket,
   case gen_tcp:accept(ListenSocket, 0) of
      {ok, PeerSocket} ->
         {ok, Addr} = inet:peername(PeerSocket),
         log(info, "Device connected from ~p.", [Addr]),
         apply(State#state.protocol, start, [PeerSocket, [{listener, ?MOD}, {opts, State#state.opts}]]),
         {noreply, State, ?TIMEOUT};
      {error, timeout} ->
         {noreply, State, ?TIMEOUT}
   end.

log(LogLevel, Format, Data) ->
   mds_gen_server:log(?MODULE, LogLevel, Format, Data).

log(LogLevel, Text) ->
   mds_gen_server:log(?MODULE, LogLevel, Text).
