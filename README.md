# IoT Robotic Arm
## Codelab
Goal of this Codelab is to harness the power of robotic arm. To achieve this, we prepared Ruby client which comunicates with Ruby server using MQTT protocol. Server then comunicates with the arm via serial link.
Your goal is to move companion cube from point A to the drop zone.
### Get started
To start, create new file in `ruby` folder with `.rb` suffix. We will use `example.rb`.
To use the client, start your file with `require_relative "client"`.
Then create new instance of `Rucicka::Client` class with `client = Rucicka::Client.new`.
Your file should look like this:
```Ruby
require_relative 'client'

client = Rucicka::Client.new
```
### Available commands
`Rucicka::Client` has these available commands:
- `.park` - parks the arm to constant position, is called when creating new instance of `Client`
- each of these following methods accepts optional step size
    - `.forward` - move the arm one step forward
    - `.back` - move the arm one step backward
    - `.left` - rotates the arm to the left
    - `.right` - rotates the arm to the right
    - `.up` - move the arm one step up
    - `.down` - move the arm one step down
    - `.wrist_left` - rotates wrist `step * 10` degrees to the left
    - `.wrist_right` - rotates wrist `step * 10` degrees to the right
    - `.wrist_down` - rotates wrist `step * 10` degrees down
    - `.wrist_up` - rotates wrist `step * 10` degrees up
- `.gripper_on` - closes the gripper
- `.gripper_off` - opens the gripper
- `.manual` - enters manual mode, see Manual section for controls
- `.set_moves` - enables to set multiple moves and call them all at the same time after the block ends
```ruby
client.set_moves do
  client.forward(10)
  client.up(5)
  client.left(20)
  client.wrist_up(4)
end
```
### Manual mode
Manual mode maps keyboard input to various methods.
Keymap: (_key_ --> _method_)
- `space` --> `park`
- `arrow up` / `w` --> `up`
- `arrow down` / `s` --> `down`
- `arrow left` / `a` --> `left`
- `arrow right` / `d` --> `right`
- `+` / `r` --> `forward`
- `-` / `f` --> `back`
- `q` --> `gripper_on`
- `e` --> `gripper_off`
- `j` --> `wrist_left`
- `l` --> `wrist_right`
- `i` --> `wrist_up`
- `k` --> `wrist_down`

Any other input stops manual mode
## Misc.
### How to flash control board
 - Install Arduino IDE
 - Open Arduino IDE
 - Open `Tools` tab
 - Set:
   - `Board` to `Arduino Duemilanove or Diecimila`
   - `Processor` to `ATmega328P`
   - `Port` to first available
- make changes - optional
- click on `Upload`
### Architecture overview

![Alt text](https://g.gravizo.com/source/architecture?https%3A%2F%2Fraw.githubusercontent.com%2FJuicymo%2Fiot-robotic-arm%2Fmaster%2FREADME.md)
<details style="display:none;">
<summary></summary>
architecture
@startuml
package "Ruby" {;
  [Server];
  [Client];
  [ArmLib];
};

package "Arduino" {;
  [rucicka.ino] as ar;
};

[Server] <.. [Client] : MQTT;
[ArmLib] <|-- [Client];
[ArmLib] <|-- [Server];

[Server] ..> HW : Serial link;
ar <.. HW;

@enduml
architecture
</details>
