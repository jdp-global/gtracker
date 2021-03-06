-module(gtracker_format_text).

-export([format_text/8]).

-import(gtracker_common, [datetime_to_string/1]).
-import(mds_xml, [get_tag/2]).
-import(mds_unicode, [list_to_urlencode_string/1]).

-define(email, "dmitryme@gmail.com").
-define(undefLocation, {[{road, "undef"}, {city, "undef"}, {region, "undef"}, {country, "undef"}], "undef, undef,
   undef, undef"}).

%=======================================================================================================================
%  Message builders
%=======================================================================================================================
format_text(_Logger, _TriggerName, DevName, online, Lat, Lon, Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is online in (~p,~p) at ~s", [DevName, Lat, Lon,
               datetime_to_string(Timestamp)])));

format_text(_Logger, _TriggerName, DevName, offline, undef, undef, undef, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is offline", [DevName])));
format_text(_Logger, _TriggerName, DevName, offline, Lat, Lon, Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is offline. Last known position is (~p,~p) at ~s",
            [DevName, Lat, Lon, datetime_to_string(Timestamp)])));

format_text(_Logger, TriggerName, DevName, enter, _Lat, _Lon, _Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is moving at ~s", [DevName, TriggerName])));

format_text(_Logger, TriggerName, DevName, leave, _Lat, _Lon, _Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is leaving ~s", [DevName, TriggerName])));

format_text(_Logger, _TriggerName, DevName, periodic, Lat, Lon, Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("Position of ~s is (~p,~p) at ~s", [DevName, Lat, Lon,
               datetime_to_string(Timestamp)])));

format_text(_Logger, _TriggerName, DevName, sos, undef, undef, undef, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is requesting help!", [DevName])));

format_text(_Logger, _TriggerName, DevName, sos, Lat, Lon, Timestamp, undef) ->
   erlang:list_to_binary(lists:flatten(io_lib:format("~s is requesting help! Last known position is (~p,~p) at ~s",
            [DevName, Lat, Lon, datetime_to_string(Timestamp)])));

format_text(Logger, TriggerName, DevName, _TriggerType, Lat, Lon, Timestamp, Text) when erlang:is_binary(Text) ->
   Coord = lists:flatten(io_lib:format("(~p,~p)", [Lat, Lon])),
   Opts = [{trigger, TriggerName}, {dev_name, DevName}, {timestamp, Timestamp}, {coord, Coord}],
   Location = get_location(Lat, Lon, Text),
   case Location of
      {error, Error, ErrText, Body} ->
         Logger(error, "Unable to fetch location. Error = ~p, ErrText = ~p, Body = ~p", [Error, ErrText, Body]),
         build_text(Text, [{location, ?undefLocation} | Opts]);
      _ ->
         build_text(Text, [{location, Location} | Opts])
   end;

format_text(_, Name, _, _, _, _, _, Text) ->
   ErrTxt = lists:flatten(io_lib:format("Trigger ~p has wrong text ~p format", [Name, Text])),
   throw({error, ErrTxt}).

%=======================================================================================================================
%  Process text pattern and substitude
%    %C -  coordinate
%    %D -  device name
%    %T -  trigger name
%    %W -  timestamp
%    %YYYY - year
%    %M    - month
%    %DD   - day
%    %HH   - hour
%    %MM   - month
%    %SS   - second
%    %A -  geocode address: Road, City, Region, Country
%    %AR - geocode Road
%    %AC - geocode City
%    %AE - geocode Region
%    %AO - geocode Country
%    with values
%=======================================================================================================================
build_text(<<"%%", P:8, Rest/binary>>, Opts) when (P =:= $D) or (P =:= $C) or (P =:= $T) or (P =:=$W)->
   BinRest = build_text(Rest, Opts),
   <<$%, P, BinRest/binary>>;
build_text(<<"%%", P:16/bitstring, Rest/binary>>, Opts) when (P =:= <<"AR">>) or (P =:= <<"AC">>) or (P =:= <<"AE">>) or
(P =:= <<"AO">>) or (P =:= <<"HH">>) or (p =:= <<"DD">>) or (P =:= <<"MM">>) or (P =:= <<"SS">>) ->
   BinRest = build_text(Rest, Opts),
   <<$%, P/bitstring, BinRest/binary>>;
build_text(<<"%%", P:32/bitstring, Rest/binary>>, Opts) when (P =:= <<"YYYY">>) ->
   BinRest = build_text(Rest, Opts),
   <<$%, P/bitstring, BinRest/binary>>;
build_text(<<"%AR", Rest/binary>>, Opts) ->
   BinRoad = address_part_to_binary(road, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinRoad/binary, BinRest/binary>>;
build_text(<<"%AC", Rest/binary>>, Opts) ->
   BinCity = address_part_to_binary(city, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinCity/binary, BinRest/binary>>;
build_text(<<"%AE", Rest/binary>>, Opts) ->
   BinRegion = address_part_to_binary(region, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinRegion/binary, BinRest/binary>>;
build_text(<<"%AO", Rest/binary>>, Opts) ->
   BinCountry = address_part_to_binary(country, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinCountry/binary, BinRest/binary>>;
build_text(<<"%YYYY", Rest/binary>>, Opts) ->
   {value, {_, {{Year, _, _},{_, _, _}}}} = lists:keysearch(timestamp, 1, Opts),
   BinYear = ts_part_to_binary(Year),
   BinRest = build_text(Rest, Opts),
   <<BinYear/binary, BinRest/binary>>;
build_text(<<"%DD", Rest/binary>>, Opts) ->
   {value, {_, {{_, _, Day},{_, _, _}}}} = lists:keysearch(timestamp, 1, Opts),
   BinDay = ts_part_to_binary(Day),
   BinRest = build_text(Rest, Opts),
   <<BinDay/binary, BinRest/binary>>;
build_text(<<"%HH", Rest/binary>>, Opts) ->
   {value, {_, {{_, _, _},{Hour, _, _}}}} = lists:keysearch(timestamp, 1, Opts),
   BinHour = ts_part_to_binary(Hour),
   BinRest = build_text(Rest, Opts),
   <<BinHour/binary, BinRest/binary>>;
build_text(<<"%MM", Rest/binary>>, Opts) ->
   {value, {_, {{_, _, _},{_, Min, _}}}} = lists:keysearch(timestamp, 1, Opts),
   BinMin = ts_part_to_binary(Min),
   BinRest = build_text(Rest, Opts),
   <<BinMin/binary, BinRest/binary>>;
build_text(<<"%SS", Rest/binary>>, Opts) ->
   {value, {_, {{_, _, _},{_, _, Sec}}}} = lists:keysearch(timestamp, 1, Opts),
   BinSec = ts_part_to_binary(Sec),
   BinRest = build_text(Rest, Opts),
   <<BinSec/binary, BinRest/binary>>;
build_text(<<"%M", Rest/binary>>, Opts) ->
   {value, {_, {{_, Month, _},{_, _, _}}}} = lists:keysearch(timestamp, 1, Opts),
   BinMonth = ts_part_to_binary(Month),
   BinRest = build_text(Rest, Opts),
   <<BinMonth/binary, BinRest/binary>>;
build_text(<<"%D", Rest/binary>>, Opts) ->
   BinName = opt_to_binary(dev_name, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinName/binary, BinRest/binary>>;
build_text(<<"%C", Rest/binary>>, Opts) ->
   BinCoord = opt_to_binary(coord, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinCoord/binary, BinRest/binary>>;
build_text(<<"%T", Rest/binary>>, Opts) ->
   BinTrigger = opt_to_binary(trigger, Opts),
   BinRest = build_text(Rest, Opts),
   <<BinTrigger/binary, BinRest/binary>>;
build_text(<<"%W", Rest/binary>>, Opts) ->
   {value, {_, Timestamp}} = lists:keysearch(timestamp, 1, Opts),
   BinTimestamp = erlang:list_to_binary(datetime_to_string(Timestamp)),
   BinRest = build_text(Rest, Opts),
   <<BinTimestamp/binary, BinRest/binary>>;
build_text(<<"%A", Rest/binary>>, Opts) ->
   {location, {_, Address}} = lists:keyfind(location, 1, Opts),
   BinRest = build_text(Rest, Opts),
   <<Address/binary, BinRest/binary>>;
build_text(<<Ch:8, Rest/binary>>, Opts) ->
   BinRest = build_text(Rest, Opts),
   <<Ch, BinRest/binary>>;
build_text(<<>>, _) ->
   <<>>.

ts_part_to_binary(Part) ->
   BinPart = erlang:list_to_binary(erlang:integer_to_list(Part)),
   case size(BinPart) of
      1 ->
         <<$0, BinPart/binary>>;
      _ ->
         BinPart
   end.

opt_to_binary(Key, Opts) ->
   {value, {Key, Value}} = lists:keysearch(Key, 1, Opts),
   erlang:list_to_binary(Value).

address_part_to_binary(PartKey, Opts) ->
   {location, {AddressParts, _}} = lists:keyfind(location, 1, Opts),
   {PartKey, Part} = lists:keyfind(PartKey, 1, AddressParts),
   Part.

geocoding_needed(Pattern) ->
   {ok, RE} = re:compile("([^%]|^)%A"),
   case re:run(Pattern, RE) of
      nomatch ->
         false;
      {match, _} ->
         true
   end.

% get_location(Lat, Lon, Pattern) -> {[{road, String()}, {city, String()}, {region, String()}, {country, String()}],
% String()}
get_location(Lat, Lon, Pattern) ->
   F = fun() ->
         case geocoding_needed(Pattern) of
         true ->
            Request = lists:flatten(io_lib:format(
                  "http://nominatim.openstreetmap.org/reverse?format=xml&lat=~p&lon=~p&zoom=18&addressdetails=1&email=~s",
                  [Lat, Lon, ?email])),
            {ok, {{_, Error, ErrText}, _, Body}} = httpc:request(Request),
            case Error of
               200 ->
                  {XmlRoot, _} = xmerl_scan:string(Body),
                  Road = get_text(get_tag([reversegeocode, addressparts, road], XmlRoot)),
                  City = get_text(get_city(XmlRoot)),
                  Region = get_text(get_tag([reversegeocode, addressparts, state], XmlRoot)),
                  Country = get_text(get_tag([reversegeocode, addressparts, country], XmlRoot)),
                  Address = lists:flatten(io_lib:format("~s, ~s, ~s, ~s", [Road, City, Region, Country])),
                  {[{road, Road}, {city, City}, {region, Region}, {country, Country}], Address};
               _ ->
                  {error, Error, ErrText, Body}
            end;
         false ->
            ?undefLocation
         end
      end,
   try F() of
      Res ->
         Res
   catch
      _:Err ->
         {error, Err}
   end.

get_text(XmlElement) ->
   case XmlElement of
      {error_not_found, _} ->
         "undef";
      undef ->
         "undef";
      XmlElement ->
         unicode:characters_to_binary(mds_xml:get_text(XmlElement))
   end.

get_city(XmlElement) ->
   case get_tag([reversegeocode, addressparts, hamlet], XmlElement) of
      {error_not_found, hamlet} ->
         case get_tag([reversegeocode, addressparts, town], XmlElement) of
            {error_not_found, town} ->
               case get_tag([reversegeocode, addressparts, city], XmlElement) of
                  {error_not_found, _} ->
                     undef;
                  Child ->
                     Child
               end;
            Child ->
               Child
         end;
      Child ->
         Child
   end.

%=======================================================================================================================
%  unit testing facilities
%=======================================================================================================================
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

geocoding_needed_test() ->
   Pattern = "%A some text",
   ?assertEqual(true, geocoding_needed(Pattern)),
   Pattern1 = "%%A some text",
   ?assertEqual(false, geocoding_needed(Pattern1)),
   Pattern2 = "%%AT some text",
   ?assertEqual(false, geocoding_needed(Pattern2)),
   Pattern3 = "%AT some text",
   ?assertEqual(true, geocoding_needed(Pattern3)),
   Pattern4 = "another %%A some text",
   ?assertEqual(false, geocoding_needed(Pattern4)),
   Pattern5 = "another %A some text",
   ?assertEqual(true, geocoding_needed(Pattern5)).

build_text_test() ->
   Pattern = <<"This is a simple pattern">>,
   ?assertEqual(Pattern, build_text(Pattern, [])),
   Pattern1 = <<"%C %D %T %W">>,
   Opts = [{coord, "(57,37)"}, {dev_name, "ABCD"}, {timestamp, {{2010, 6, 7}, {19, 25, 00}}}, {trigger, "TempTrigger"},
      {location, {[{road, <<"Road">>}, {city, <<"City">>}, {region, <<"Region">>}, {country, <<"Country">>}],
            <<"Road, City, Region, Country">>}}],
   ?assertEqual(<<"(57,37) ABCD TempTrigger 07.06.2010 19:25:00">>, build_text(Pattern1, Opts)),
   Pattern2 = <<"This is a device %D">>,
   ?assertEqual(<<"This is a device ABCD">>, build_text(Pattern2, Opts)),
   Pattern3 = <<"This is not a device %%D">>,
   ?assertEqual(<<"This is not a device %D">>, build_text(Pattern3, Opts)),
   Pattern4 = <<"%C%%T%D">>,
   ?assertEqual(<<"(57,37)%TABCD">>, build_text(Pattern4, Opts)),
   Pattern5 = <<"My location is %A">>,
   ?assertEqual(<<"My location is Road, City, Region, Country">>, build_text(Pattern5, Opts)),
   Pattern6 = <<"I am on a road '%AR'">>,
   ?assertEqual(<<"I am on a road 'Road'">>, build_text(Pattern6, Opts)),
   Pattern7 = <<"I am on a road '%%AR'">>,
   ?assertEqual(<<"I am on a road '%AR'">>, build_text(Pattern7, Opts)),
   Pattern8 = <<"I am in city '%AC'. Cool.">>,
   ?assertEqual(<<"I am in city 'City'. Cool.">>, build_text(Pattern8, Opts)),
   Pattern9 = <<"I am in region '%AE'. Cool.">>,
   ?assertEqual(<<"I am in region 'Region'. Cool.">>, build_text(Pattern9, Opts)),
   Pattern10 = <<"%AO.">>,
   ?assertEqual(<<"Country.">>, build_text(Pattern10, Opts)),
   Pattern11 = <<"%YYYY is my year.">>,
   ?assertEqual(<<"2010 is my year.">>, build_text(Pattern11, Opts)),
   Pattern12 = <<"%%YYYY is my year.">>,
   ?assertEqual(<<"%YYYY is my year.">>, build_text(Pattern12, Opts)),
   Pattern13 = <<"day is %M/%DD">>,
   ?assertEqual(<<"day is 06/07">>, build_text(Pattern13, Opts)),
   Pattern14 = <<"%M/%DD/%YYYY">>,
   ?assertEqual(<<"06/07/2010">>, build_text(Pattern14, Opts)),
   Pattern15 = <<"%HH:%MM:%SS">>,
   ?assertEqual(<<"19:25:00">>, build_text(Pattern15, Opts)),
   Pattern16 = <<"%%HH:%%MM:%%SS">>,
   ?assertEqual(<<"%HH:%MM:%SS">>, build_text(Pattern16, Opts)).


format_text_test() ->
   L = fun(_Format, _Args) -> ok end,
   TriggerName = "TempTrigger",
   DevName = "TempDevice",
   Lat  = 57.321,
   Lon = 37.123,
   Timestamp = {{2010,6,9},{12,31,05}},
   ?assertEqual(<<"TempDevice is online in (57.321,37.123) at 09.06.2010 12:31:05">>,
      format_text(L, TriggerName, DevName, online, Lat, Lon, Timestamp, undef)),
   ?assertEqual(<<"TempDevice is offline. Last known position is (57.321,37.123) at 09.06.2010 12:31:05">>,
      format_text(L, TriggerName, DevName, offline, Lat, Lon, Timestamp, undef)),
   ?assertEqual(<<"TempDevice is moving at TempTrigger">>,
      format_text(L, TriggerName, DevName, enter, Lat, Lon, Timestamp, undef)),
   ?assertEqual(<<"TempDevice is leaving TempTrigger">>,
      format_text(L, TriggerName, DevName, leave, Lat, Lon, Timestamp, undef)),
   ?assertEqual(<<"TempDevice is requesting help! Last known position is (57.321,37.123) at 09.06.2010 12:31:05">>,
      format_text(L, TriggerName, DevName, sos, Lat, Lon, Timestamp, undef)),
   ?assertEqual(<<"TempTrigger, 09.06.2010 12:31:05: TempDevice is requesting help at (57.321,37.123)!">>,
      format_text(L, TriggerName, DevName, sos, Lat, Lon, Timestamp, <<"%T, %W: %D is requesting help at %C!">>)).

-endif.
