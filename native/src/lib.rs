use std::io::{stdout, Write};
use std::sync::mpsc::channel;

use crossterm::cursor::MoveTo;
use crossterm::event::KeyEvent;
use crossterm::event::{self, Event, KeyCode, KeyEventKind, KeyModifiers};
use crossterm::style::Print;
use crossterm::terminal::{Clear, ClearType};
use crossterm::{execute, queue, terminal};
use rustler::types::tuple::{self, make_tuple};
use rustler::{thread, Binary, Encoder, Env, LocalPid, Term};

mod atoms {
    rustler::atoms! {
        ok,
        error,
        none,
        some,

        control,
        shift,
        alt,

        key,
        resize,

        enter,
        left,
        right,
        down,
        up,
        backspace,
        character,

        unsupported,
    }
}

#[derive(Debug)]
struct KeyPress {
    code: KeyCode,
    modifier: KeyModifiers,
}

struct Resize {
    columns: u16,
    rows: u16,
}

impl Encoder for KeyPress {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let modifier = match self.modifier {
            KeyModifiers::CONTROL => tuple::make_tuple(
                env,
                &[atoms::some().to_term(env), atoms::control().to_term(env)],
            ),
            KeyModifiers::SHIFT => tuple::make_tuple(
                env,
                &[atoms::some().to_term(env), atoms::shift().to_term(env)],
            ),
            KeyModifiers::ALT => tuple::make_tuple(
                env,
                &[atoms::some().to_term(env), atoms::alt().to_term(env)],
            ),
            _ => atoms::none().to_term(env),
        };
        let character = match self.code {
            KeyCode::Char(c) => tuple::make_tuple(
                env,
                &[atoms::character().to_term(env), String::from(c).encode(env)],
            ),
            KeyCode::Enter => atoms::enter().to_term(env),
            KeyCode::Backspace => atoms::backspace().to_term(env),
            KeyCode::Left => atoms::left().to_term(env),
            KeyCode::Right => atoms::right().to_term(env),
            KeyCode::Down => atoms::down().to_term(env),
            KeyCode::Up => atoms::up().to_term(env),
            _ => atoms::unsupported().to_term(env),
        };
        make_tuple(env, &[atoms::key().to_term(env), character, modifier])
    }
}

impl Encoder for Resize {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        make_tuple(
            env,
            &[
                atoms::resize().to_term(env),
                self.columns.encode(env),
                self.rows.encode(env),
            ],
        )
    }
}

// TODO:  `unwrap` in a NIF??? no
#[rustler::nif(schedule = "DirtyIo")]
fn listen(env: Env, pid: LocalPid) {
    let (tx, rx) = channel::<()>();

    thread::spawn::<thread::ThreadSpawner, _>(env, move |new_env| {
        loop {
            match event::read() {
                Ok(Event::Key(KeyEvent {
                    code,
                    kind: KeyEventKind::Press,
                    modifiers: modifier,
                    state: _,
                })) => {
                    let val = KeyPress { code, modifier };

                    new_env.send(&pid, val.encode(new_env));
                }
                Ok(Event::Resize(columns, rows)) => {
                    let val = Resize { columns, rows };
                    new_env.send(&pid, val.encode(new_env));
                }
                Err(err) => {
                    eprint!("Received error from TTY:  {:?}", err);
                    break;
                }
                msg => {
                    println!("got some unknown message: {:?}", msg);
                    continue;
                }
            }
        }
        let _ = tx.send(());
        atoms::ok().to_term(new_env)
    });

    let _resp = rx.recv();
}

#[rustler::nif]
fn enable_raw_mode() -> Result<(), ()> {
    terminal::enable_raw_mode().map_err(|_| ())
}

#[rustler::nif]
fn disable_raw_mode() -> Result<(), ()> {
    terminal::disable_raw_mode().map_err(|_| ())
}

#[rustler::nif]
fn print(data: Binary) -> Result<(), ()> {
    let _ = execute!(stdout(), Print(String::from_utf8_lossy(data.as_slice())));

    Ok(())
}

#[rustler::nif]
fn size() -> Result<(u16, u16), ()> {
    terminal::size().map_err(|_| ())
}

#[rustler::nif]
fn clear() {
    let _ = execute!(stdout(), Clear(ClearType::All));
}

#[rustler::nif]
fn move_to(column: u16, row: u16) {
    let _ = execute!(stdout(), MoveTo(column, row));
}

#[rustler::nif]
fn draw(commands: Vec<(u16, u16, String)>) -> Result<(), ()> {
    let mut stdout = stdout();
    for (column, row, data) in commands.iter() {
        queue!(stdout, MoveTo(*column, *row), Print(data)).map_err(|_| ())?;
    }
    stdout.flush().map_err(|_| ())
}

rustler::init!(
    "glerm_ffi",
    [
        clear,
        draw,
        listen,
        print,
        size,
        move_to,
        enable_raw_mode,
        disable_raw_mode
    ]
);
