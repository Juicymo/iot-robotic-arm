# IoT Robotic Arm
## Codelab
Goal of this Codelab is to harness the power of robotic arm. To achieve this, we prepared Ruby client which communicates with Ruby server using MQTT protocol. Server then communicates with the arm via serial link.
Your goal is to grab a stamp and press it on to clean paper.
Does this seem too easy for you? Go ahead and try draw a line, circle, square or what-ever shape you want with the stamp!
### Get started
#### Ruby
To install ruby on our system, download and install [RVM](https://rvm.io/rvm/install) and then type in our command line:
- `rvm install 2.6.3` - this will take a while
- `rvm use 2.6.3`
- open ruby folder in this repository
- `gem install bundler`
- `bundle install`

And you are good to go!
#### Server
To run server on your computer, you need to install MQTT broker. We suggest [Mosquito](https://mosquitto.org/download/).
If you skip this step, you will not be able to use the Client library.
After install connect the arm to your computer and run `ruby server.rb` in command line.
You should see something like this:
```
rucicka> Connecting...OK
rucicka> Initializing...OK
serial> <-  
serial> <-  
rucicka> Moving to `park` position
serial> -> <19,170,80,75,40,86>
rucicka> I am ready!

rucicka> Type command (or `help`):

``` 
You can try multiple modes available in `help` command, but we need to type `mqtt` to run client.
#### Client
After your server is running, create new file in `ruby` folder with `.rb` suffix. We will use `example.rb`.
To use the client, start your file with `require_relative "client"`.
Then create new instance of `Rucicka::Client` class with `client = Rucicka::Client.new`.
Your file should look like this:
```Ruby
require_relative 'client'

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

# Codelab 2019
## Easy Mode

## Hard Mode
