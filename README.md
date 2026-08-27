## Temperature-Reactive Remote-Controlled Fan
Embedded systems project to simulate a smart ceiling fan
<br><br><br>
**Demo -** https://youtu.be/5JTl2SQssU4?si=PG7SxPEiQByE4sl_ 

**Project Report -** docs/MCU2026-G056.pdf (in French)
<br><br>
### Overview
Modular firmware system with an FSM for switching between modes and handling requests <br>
Automatic mode (temperature-based, with variable reference temperature) and Manual mode (remote-based, speeds 1-9) <br>
LCD Screen and Buzzer for visual and audio interfaces, Servo motor to simulate fan spin <br>
University project required that 4 peripherals must be used, and for all code to be written in Assembly <br>

### Hardware
- Atmel STK300 AVR Development Board
with ATMega128 Microcontroller<br>
- DS18B20 1-Wire Digital Thermometer<br>
- RC5 Vivanco TV/DVB Controller URZ2<br>
- TSOP22 Vishay IR Receiver<br>
- MCKPT-G1712A-3921 Piezo Transducer (Buzzer)<br>
- HD44780U Hitachi LCD Screen<br>
- SG90 9g Micro Servo<br>
