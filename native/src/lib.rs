use std::io::{stdout, Write};
use std::sync::mpsc::channel;

use crossterm::cursor::MoveTo;
use crossterm::event::{
    self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyModifiers, MouseButton,
    MouseEventKind,
};
use crossterm::event::{KeyEvent, MouseEvent};
use crossterm::style::Print;
use crossterm::terminal::{Clear, ClearType, EnterAlternateScreen, LeaveAlternateScreen};
use crossterm::{execute, queue, terminal};
use rustler::types::tuple::{self, make_tuple};
use rustler::{thread, Binary, Encoder, Env, LocalPid, Term};

mod atoms {
    rustler::atoms! {
        // Regular gleam atoms
        ok,
        error,
        none,
        some,

        // Key modifiers
        control,
        shift,
        alt,

        // Event types
        focus,
        key,
        mouse,
        paste,
        resize,

        // Key event properties
        // Special keys
        enter,
        left,
        right,
        down,
        up,
        backspace,

        // Regular key
        character,

        // Mouse event properties
        // Event types
        mouse_down,
        mouse_up,
        drag,
        moved,
        scroll_down,
        scroll_up,

        // Mouse buttons
        mouse_left,
        mouse_right,
        mouse_middle,

        // Focus event properties
        // Focus types
        gained,
        lost,

        // Placeholder
        unsupported,
    }
}

struct TermKeyModifier {
    modifier: KeyModifiers,
}

#[derive(Debug)]
struct TermKeyEvent {
    key: KeyEvent,
}

impl Encoder for TermKeyModifier {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        // TODO:  Handle other modifiers?
        match self.modifier {
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
        }
    }
}

// TODO:  Handle repeat/release?
impl Encoder for TermKeyEvent {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let modifier = TermKeyModifier {
            modifier: self.key.modifiers,
        }
        .encode(env);
        let character = match self.key.code {
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

struct Resize {
    columns: u16,
    rows: u16,
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

struct TermMouseButton {
    button: MouseButton,
}

impl Encoder for TermMouseButton {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        match self.button {
            MouseButton::Left => atoms::mouse_left().encode(env),
            MouseButton::Right => atoms::mouse_right().encode(env),
            MouseButton::Middle => atoms::mouse_middle().encode(env),
        }
    }
}

struct TermMouseEvent {
    event: MouseEvent,
}

impl Encoder for TermMouseEvent {
    fn encode<'a>(&self, env: Env<'a>) -> Term<'a> {
        let event_type = atoms::mouse().to_term(env);
        let modifier = TermKeyModifier {
            modifier: self.event.modifiers,
        }
        .encode(env);
        match self.event.kind {
            MouseEventKind::Down(button) => {
                let button = TermMouseButton { button }.encode(env);
                make_tuple(
                    env,
                    &[
                        event_type,
                        make_tuple(env, &[atoms::mouse_down().to_term(env), button, modifier]),
                    ],
                )
            }
            MouseEventKind::Up(button) => {
                let button = TermMouseButton { button }.encode(env);
                make_tuple(
                    env,
                    &[
                        event_type,
                        make_tuple(env, &[atoms::mouse_down().to_term(env), button, modifier]),
                    ],
                )
            }
            MouseEventKind::Drag(button) => {
                let button = TermMouseButton { button }.encode(env);
                make_tuple(
                    env,
                    &[
                        event_type,
                        make_tuple(env, &[atoms::drag().to_term(env), button, modifier]),
                    ],
                )
            }
            MouseEventKind::Moved => make_tuple(env, &[event_type, atoms::moved().to_term(env)]),
            MouseEventKind::ScrollDown => make_tuple(
                env,
                &[event_type, atoms::scroll_down().to_term(env), modifier],
            ),
            MouseEventKind::ScrollUp => make_tuple(
                env,
                &[event_type, atoms::scroll_up().to_term(env), modifier],
            ),
        }
    }
}

#[rustler::nif(schedule = "DirtyIo")]
fn listen(env: Env, pid: LocalPid) {
    let (tx, rx) = channel::<()>();

    thread::spawn::<thread::ThreadSpawner, _>(env, move |new_env| {
        loop {
            match event::read() {
                Ok(Event::FocusLost) => {
                    let val = make_tuple(
                        new_env,
                        &[
                            atoms::focus().to_term(new_env),
                            atoms::lost().to_term(new_env),
                        ],
                    );
                    new_env.send(&pid, val);
                }
                Ok(Event::FocusGained) => {
                    let val = make_tuple(
                        new_env,
                        &[
                            atoms::focus().to_term(new_env),
                            atoms::gained().to_term(new_env),
                        ],
                    );
                    new_env.send(&pid, val);
                }
                Ok(Event::Key(event)) => {
                    let val = TermKeyEvent { key: event };

                    new_env.send(&pid, val.encode(new_env));
                }
                Ok(Event::Mouse(event)) => {
                    let val = TermMouseEvent { event };
                    new_env.send(&pid, val.encode(new_env))
                }
                Ok(Event::Resize(columns, rows)) => {
                    let val = Resize { columns, rows };
                    new_env.send(&pid, val.encode(new_env));
                }
                Ok(Event::Paste(data)) => {
                    let val = make_tuple(
                        new_env,
                        &[atoms::paste().to_term(new_env), data.encode(new_env)],
                    );

                    new_env.send(&pid, val.encode(new_env))
                }
                Err(err) => {
                    eprint!("Received error from TTY:  {err}");
                    break;
                } // msg => {
                  //     println!("got some unknown message: {:?}", msg);
                  //     continue;
                  // }
            }
        }
        let _ = tx.send(());
        atoms::ok().to_term(new_env)
    });

    let _resp = rx.recv();
}

#[rustler::nif]
fn enable_raw_mode() -> Result<(), ()> {
    let res = terminal::enable_raw_mode();

    res.map_err(|_| ())
}

#[rustler::nif]
fn disable_raw_mode() -> Result<(), ()> {
    terminal::disable_raw_mode().map_err(|_| ())
}

#[rustler::nif]
fn print(data: Binary) -> Result<(), ()> {
    execute!(stdout(), Print(String::from_utf8_lossy(data.as_slice()))).map_err(|_| ())
}

#[rustler::nif]
fn size() -> Result<(u16, u16), ()> {
    terminal::size().map_err(|_| ())
}

#[rustler::nif]
fn clear() -> Result<(), ()> {
    execute!(stdout(), Clear(ClearType::All)).map_err(|_| ())
}

#[rustler::nif]
fn move_to(column: u16, row: u16) -> Result<(), ()> {
    execute!(stdout(), MoveTo(column, row)).map_err(|_| ())
}

#[rustler::nif]
fn draw(commands: Vec<(u16, u16, String)>) -> Result<(), ()> {
    let mut stdout = stdout();
    for (column, row, data) in commands.iter() {
        queue!(stdout, MoveTo(*column, *row), Print(data)).map_err(|_| ())?;
    }
    stdout.flush().map_err(|_| ())
}

#[rustler::nif]
fn enter_alternate_screen() -> Result<(), ()> {
    execute!(stdout(), EnterAlternateScreen).map_err(|_| ())
}

#[rustler::nif]
fn leave_alternate_screen() -> Result<(), ()> {
    execute!(stdout(), LeaveAlternateScreen).map_err(|_| ())
}

#[rustler::nif]
fn enable_mouse_capture() -> Result<(), ()> {
    execute!(stdout(), EnableMouseCapture).map_err(|_| ())
}

#[rustler::nif]
fn disable_mouse_capture() -> Result<(), ()> {
    execute!(stdout(), DisableMouseCapture).map_err(|_| ())
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
        disable_raw_mode,
        enter_alternate_screen,
        leave_alternate_screen,
        enable_mouse_capture,
        disable_mouse_capture,
    ]
);
