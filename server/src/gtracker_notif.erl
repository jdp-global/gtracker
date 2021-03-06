-module(gtracker_notif).

-behaviour(mds_gen_server).

-include("common_defs.hrl").

-export([start/1, stop/0, on_start/1, on_stop/2, on_msg/3, on_amsg/2, on_info/2]).

-import(mds_utils, [get_param/2, get_param/3]).
-import(mds_unicode, [utf8_to_cp1251/1]).
-import(gtracker_common, [list_to_urlencoded/1]).

-define(MOD, {global, ?MODULE}).

-record(state, {sms_username, sms_password}).

start(Opts) ->
   mds_gen_server:start(?MOD, Opts).

stop() ->
   mds_gen_server:stop(?MOD).

on_start(Opts) ->
   inets:start(),
   SelfOpts = get_param(self, Opts),
   SmsUsername = get_param(sms_username, SelfOpts),
   SmsPassword = get_param(sms_password, SelfOpts),
   {ok, #state{sms_username = SmsUsername, sms_password = SmsPassword}}.

on_stop(Reason, _State) ->
   log(info, "Stopped <~p>.", [Reason]),
   ok.

on_msg(Msg, _From, State) ->
   log(info, "Unknown sync received ~p", [Msg]),
   {reply, ok, State}.

on_amsg(Msg = {eMail, To, Subj, Body}, State) ->
   log(debug, "Async message ~p was received.", [Msg]),
   send_email(To, Subj, Body),
   {noreply, State};
on_amsg(Msg = {sms, PhoneList, DevName, Text}, State) ->
   log(debug, "Async message ~p was received.", [Msg]),
   send_sms(PhoneList, DevName, Text, State#state.sms_username, State#state.sms_password),
   {noreply, State};
on_amsg(Msg = {twitter, TA, DevName, BinText}, State) ->
   log(debug, "Async message ~p was received.", [Msg]),
   send_twit(TA, DevName, BinText),
   {noreply, State}.

on_info(?MSG(_From, _GroupName, Msg), _State) ->
   log(info, "Unknown info message ~p.", [Msg]).


send_sms(undef, _DevName, _Text, _UserName, _Password) ->
   ok;
send_sms(PhoneList, DevName, Text, UserName, Password) ->
   Message =
   lists:flatten(io_lib:format("http_username=~s&http_password=~s&phone_list=~s&fromPhone=gtracker.ru&message=~s",
         [UserName, Password, PhoneList, list_to_urlencoded(utf8_to_cp1251(unicode:characters_to_list(Text)))])),
   Res = {ok, {{_, Error, _}, _, Body}} = httpc:request(
      post, {"http://www.websms.ru/http_in5.asp", [], "application/X-www-form-urlencoded", Message}, [], []),
   case Error of
      200 ->
         log(debug, "SMS ~p was send from ~p to ~p", [PhoneList, DevName, Text]),
         check_balance(Body);
      _ ->
         log(error, "Unable to send SMS. Result ~p", [Res])
   end.

check_balance(Body) ->
   {ok, RE} = re:compile(".*balance_after=([0-9,]+).*"),
   Res = re:run(Body, RE),
   case Res of
      nomatch ->
         log(error, "Unable to find balance_after in ~s", [Body]);
      {match, [{_, _},{Start, Len}]} ->
         Balance = erlang:list_to_float(string:sub_string(Body, Start + 1, Start + Len)),
         case Balance =< 100 of
            true ->
               log(warning, "Balance ~p of WebSMS service is too low!", [Balance]);
            _ ->
               log(info, "Balance after sending is ~p.", [Balance])
         end
   end.

send_email(undef, _Subj, _Body) ->
   ok;
send_email(To, Subj, Body) ->
   mds_utils:send_email(To, Subj, Body),
   log(debug, "eMail ~p was send to ~p", [Body, To]).

send_twit({{consumer, Key, Secret}, {access, Token, TokenSecret}}, DevName, BinText) ->
   Consumer = {Key, Secret, hmac_sha1},
   Text = erlang:binary_to_list(BinText),
   Res = {ok, {{_, Error, _}, _, _}} = oauth:post(
         "http://api.twitter.com/1/statuses/update.xml", [{"status", Text}], Consumer, Token, TokenSecret),
   case Error of
     200 ->
        log(debug, "Twitter update ~p was sent for ~p.", [Text, DevName]);
     _ ->
        log(error, "Unable to send twit for device ~p. Result ~p.", [DevName, Res])
   end.

%=======================================================================================================================
%  log helpers
%=======================================================================================================================
log(LogLevel, Format, Data) ->
   mds_gen_server:log(?MODULE, LogLevel, Format, Data).

log(LogLevel, Text) ->
   mds_gen_server:log(?MODULE, LogLevel, Text).
