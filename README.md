# IoT Robotic Arm
----
## How to flash controll board
 - Install Arduino IDE
 - Open Arduino IDE
 - Open `Tools` tab
 - Set:
   - `Board` to `Arduino Duemilanove or Diecimila`
   - `Processor` to `ATmega328P`
   - `Port` to first available
- make cahnges - optional
- click on `Upload`
## Architecture overview

![Alt text](https://g.gravizo.com/source/architecture?https%3A%2F%2Fraw.githubusercontent.com%2FJuicymo%2Fiot-robotic-arm%2Fmaster%2FREADME.md)
<details>
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
