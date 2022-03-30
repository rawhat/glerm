erl_path := `erl -eval 'io:format("~s", [lists:concat([code:root_dir(), "/erts-", erlang:system_info(version), "/include"])])' -s init stop -noshell`

run: build_nif
  gleam run

build_nif:
  gcc -fPIC -shared -o c_src/complex.so c_src/complex.c -I {{erl_path}}
