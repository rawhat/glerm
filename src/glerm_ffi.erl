-module(glerm_ffi).

-export([init/0, hello/0]).

-on_load(init/0).

init() ->
  io:format("hello from init~n"),
  erlang:load_nif("../c_src/complex", 0),
  io:format("done loadin~n").

hello() ->
  erlang:nif_error("NIF library not loaded").
