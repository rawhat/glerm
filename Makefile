all: term
	mkdir -p priv
	cp native/target/release/libglerm.so priv/
	gleam build

term: native/src/lib.rs
	cd native && cargo build --release

clean:
	rm priv/libglerm.so
