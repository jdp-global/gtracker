-module(index).
-compile(export_all).
-include_lib("nitrogen/include/wf.hrl").
-include("records.hrl").

main() ->
   #template { file="./site/templates/index.html" }.

title() ->
   "GTracker - Index".

body() ->
   #panel { body=["Hi friend, it's a welcome page"] }.
