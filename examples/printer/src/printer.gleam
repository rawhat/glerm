import gleam/bit_string
import gleam/erlang/process
import gleam/function
import gleam/option.{Some}
import gleam/string
import glerm.{Character, Control, Key}
import gleam/otp/actor

pub fn main() {
  // Create a subject to use as an "exit" signal
  let subject = process.new_subject()

  let selector =
    process.new_selector()
    |> process.selecting(subject, function.identity)

  // Create a new screen for our application
  let assert Ok(_) = glerm.enter_alternate_screen()
  // Enable raw mode to allow capturing all input, and free-form
  // output
  let assert Ok(_) = glerm.enable_raw_mode()
  // Also grab mouse events
  let assert Ok(_) = glerm.enable_mouse_capture()

  // Clear the terminal screen
  glerm.clear()
  // Place the cursor at the top-left
  glerm.move_to(0, 0)

  // Start the terminal NIF to begin receiving events
  let assert Ok(_subj) =
    glerm.start_listener(
      0,
      fn(msg, state) {
        case msg {
          // We need to provide some way for a user to quit the application.
          Key(Character("c"), Some(Control)) -> {
            // Turn off some of the things we set above
            let assert Ok(_) = glerm.disable_raw_mode()
            let assert Ok(_) = glerm.disable_mouse_capture()
            // Tell our subject that we are done, which will unblock the
            // `select_forever` below
            process.send(subject, Nil)
            actor.Stop(process.Normal)
          }
          _ -> {
            // Move down to the current row
            glerm.move_to(0, state)
            // Print the message we got to the screen
            let assert Ok(_) =
              glerm.print(bit_string.from_string(string.inspect(msg)))
            // Go down to the next row for the subsequent message
            actor.continue(state + 1)
          }
        }
      },
    )

  // Block until we receive the exit signal from the listener
  process.select_forever(selector)

  // Return the user to their previous terminal screen and exit
  glerm.leave_alternate_screen()
}
