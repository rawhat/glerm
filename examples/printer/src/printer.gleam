import gleam/bit_array
import gleam/erlang/process
import gleam/option.{Some}
import gleam/otp/actor
import gleam/string
import glerm.{Character, Control, Key}

pub fn main() {
  // Create a subject to use as an "exit" signal
  let subject = process.new_subject()

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
    glerm.start_listener(0, fn(state, msg) {
      case msg {
        // We need to provide some way for a user to quit the application.
        Key(Character("c"), Some(Control)) -> {
          // Turn off some of the things we set above
          let assert Ok(_) = glerm.disable_raw_mode()
          let assert Ok(_) = glerm.disable_mouse_capture()
          // Tell our subject that we are done, which will unblock the
          // `select_forever` below
          process.send(subject, Nil)
          actor.stop()
        }
        _ -> {
          // Move down to the current row
          glerm.move_to(0, state)
          // Print the message we got to the screen
          let assert Ok(_) =
            glerm.print(bit_array.from_string(string.inspect(msg)))
          // Go down to the next row for the subsequent message
          actor.continue(state + 1)
        }
      }
    })

  // Block until we receive the exit signal from the listener
  process.receive_forever(subject)

  // Return the user to their previous terminal screen and exit
  glerm.leave_alternate_screen()
}
