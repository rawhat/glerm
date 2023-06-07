-module(glerm_ffi).

-export([listen/1, print/1, size/0, clear/0, move_to/2, draw/1, enable_raw_mode/0,
         disable_raw_mode/0, decode_atom/2]).

-nifs([{listen, 1},
       {print, 1},
       {size, 0},
       {clear, 0},
       {move_to, 2},
       {draw, 1},
       {enable_raw_mode, 0},
       {disable_raw_mode, 0}]).

-on_load init/0.

init() ->
  Priv = code:priv_dir(glerm),
  Path = filename:join(Priv, libglerm),
  erlang:load_nif(Path, 0).

listen(_Pid) ->
  exit(nif_library_not_loaded).

print(_Data) ->
  exit(nif_library_not_loaded).

size() ->
  exit(nif_library_not_loaded).

clear() ->
  exit(nif_library_not_loaded).

move_to(_Column, _Row) ->
  exit(nif_library_not_loaded).

draw(_Commands) ->
  exit(nif_library_not_loaded).

enable_raw_mode() ->
  exit(nif_library_not_loaded).

disable_raw_mode() ->
  exit(nif_library_not_loaded).

decode_atom(Src, Src) when is_atom(Src) ->
  {ok, Src};
decode_atom(Src, Val) ->
  {error, [{decode_error, gleam@string:inspect(Src), gleam@dynamic:classify(Val), []}]}.
