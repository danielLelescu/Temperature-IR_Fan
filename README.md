## Temperature-Reactive Remote-Controlled Fan 🪭
Embedded systems project to simulate a smart ceiling fan
<br><br><br>
**Demo -** https://youtu.be/5JTl2SQssU4?si=PG7SxPEiQByE4sl_ 

**Project Report -** docs/MCU2026-G056.pdf (in French)
<br><br>
### Overview
Modular firmware system with an FSM for switching between modes and handling requests <br>
Automatic mode (temperature-based, with variable reference temperature) and Manual mode (remote-based, speeds 1-9) <br> 
LCD Screen and Buzzer for visual and audio interfaces, Servo motor to simulate fan spin <br>
EPFL project required 4 peripheral modules, and for all code to be written in Assembly ☑️ <br>

### Hardware ⚙️
- Atmel STK300 AVR Development Board
with ATMega128 Microcontroller<br>
- DS18B20 1-Wire Digital Thermometer<br>
- RC5 Vivanco TV/DVB Controller URZ2<br>
- TSOP22 Vishay IR Receiver<br>
- MCKPT-G1712A-3921 Piezo Transducer (Buzzer)<br>
- HD44780U Hitachi LCD Screen<br>
- SG90 9g Micro Servo<br>

### Setup 💻
- Atmel Studio 7 for code editing and debugging in Assembly<br>
- AVRISP-U to program STK300<br>
- Attachment of peripheral modules<br>
  - Digital Thermometer - PORT D, Pin 5
  - IR Receiver - PORT E, Pin 7
  - Buzzer - PORT E, Pin 2
  - Servo - PORT B, Pin 5
  - LCD Screen - complementary row of pins near ATMega128


### Usage 💡
**Manual Mode: Channel UP**<br>
**Automatic Mode: Channel DOWN**<br>
<br>
**Controls in Manual Mode**<br>
Fan Speed: buttons 1-9<br>
Toggle pause/play: MUTE<br>
<br>
**Controls in Automatic Mode**<br>
Increase Ref Temperature: Volume UP<br>
Decrease Ref Temperature: Volume DOWN<br>
Toggle pause/play: MUTE<br>
<br>
For details on usage, project structure, protocols, and more, kindly reference our Project Report<br>
<br>
#### Authors/Acknowledgements
De Boi, Lucas<br>
Lelescu, Daniel<br>
Ecole Polytechnique de Lausanne (EPFL), 2026
