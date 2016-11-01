/*
 *
 * CableCamController
 *
 * This program is meant to handle the serial commuication of the BlueGiga 
 * bluetooth module. It will receive instructions from the module, process
 * data, perform the controls and calculations and return information and 
 * data to the module to be send back to the phone.
 *
 */
 
#define _BV(bit) (1<<(bit));
 
#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/wdt.h>

// Create a software serial port for ble input.
//SoftwareSerial cable_serial(5,6);
#define battery_pin A0
#define speed_pin 9
#define yaw_pin 5
#define roll_pin 10
#define pitch_pin 6

int previous_battery_value;
int battery;
int battery_count;
double battery_ave;
volatile int timer_battery_count;
byte send_battery_value;

byte input_type;
byte input_value;

byte roll_value;
byte yaw_value;
byte pitch_value;

/*
 *
 *  Type code for serial communication.
 *  Gimbal yaw/pitch    1
 *  Gimbal roll         3
 *  speed               2
 *  battery             4
 *  end                 5
 *
 */
const int GIMBAL_OTHER_TYPE = 1;
const int GIMBAL_ROLL_TYPE = 3;
const int SPEED_TYPE = 2;
const int BATTERY_TYPE = 4;
const int END_SET_TYPE = 5;
const int BATTERY_AVERAGE = 16;
const int DISCONNECT = 255;

enum States
{
  STATE_INIT,
  STATE_WAIT_FOR_COMMAND,
  STATE_UART_READ,
  STATE_UPDATE_PWM,
  STATE_UPDATE_BATTERY
} state;

class SpeedMeasure
{
  int endingRotation;
  long previousMils;
  long timeInterval;
  long count;
  
  public:
  SpeedMeasure()
  {
    count = 0;
    previousMils = 0;
  }
  
  void resetCount()
  {
    count = 0;
  }
  
  void setEnding()
  {
    endingRotation = count;
  }
  
  void update(long currentMils)
  {
    // Depends on direction!!!
    count++;
    timeInterval = currentMils - previousMils;
    previousMils = currentMils;
  }
};

SpeedMeasure speedMeasure;
 
void setup()
{
  //////////////////////////////////////////////////////
  // ATMEGA 328 without the arduino board is clocked at
  // 8MHz, not 16MHz. But the bootloader requires a 
  // requires a crystal for timing precies enough for
  // serial communication.
  //////////////////////////////////////////////////////
  
  // Set up the pwm code.
  pinMode(speed_pin, OUTPUT);
  pinMode(roll_pin, OUTPUT);
  pinMode(yaw_pin, OUTPUT);
  pinMode(pitch_pin, OUTPUT);

  //////////////////////////////////////////////////////
  //  Timer 1 Setup
  //////////////////////////////////////////////////////
  // Set fast pwm mode, with inverted mode. (pulse high)
  TCCR1A = 0x00;
  TCCR1A = _BV(WGM11) | _BV(COM1A1) | _BV(COM1B1);
  TCCR1B = 0x00;
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS11);
  
  // Set the TOP value. 16MHz/8 = 2MHz. 2HMz/(0x9C3F+1) = 50Hz.
  ICR1 = 0x9C3F;
  
  // This should equate to a 50% duty cycle.
  OCR1A = 0x4E1F;   // Pin9
  OCR1B = 0x4E1F;   // Pin10

  //////////////////////////////////////////////////////
  //  Timer 0 Setup
  //////////////////////////////////////////////////////
  // Setup pwm for Timer0 for the gimbal measure.
  TCCR0A = 0x00;
  TCCR0A = _BV(COM0A1) | _BV(COM0B1) | _BV(WGM00) | _BV(WGM01);
  TCCR0B = 0x00;
  TCCR0B = _BV(CS00) | _BV(CS02);
  cli();
  TIMSK0 = 0x00;
  TIMSK0 = _BV(OCIE0A);
  sei();

  // Set TOP value. 16MHz/1024 = 15.625KHz. 15.625KHz/256 = 61Hz (8bit timer)
  OCR0A = 16;     // Pin6

  // 50% duty cycle.
  OCR0B = 16;     // Pin5
  
  Serial.begin(9600);
  
  state = STATE_WAIT_FOR_COMMAND;
  previous_battery_value = 0;
  battery_count = 0;
  timer_battery_count = 0;

  Serial.flush();
}

void loop()
{
  
  switch (state)
  {   
    case STATE_WAIT_FOR_COMMAND:
      if (Serial.available() >= 1)
      {
        state = STATE_UART_READ;
        break;
      }

      battery_ave += analogRead(battery_pin);
      battery_count += 1;
      if (timer_battery_count >= 610)
      {
        timer_battery_count = 0;
        state = STATE_UPDATE_BATTERY;
        break;
      }
      
      break;
      
    case STATE_UPDATE_BATTERY:
    {
      // The difference between full battery and empty battery is roughly 256 points.
      // Just send that value through and let xcode deal with the percentage.
      int diff_value = 1023 - (battery_ave/battery_count);
//      int diff_value = 1023 - previous_battery_value;
      send_battery_value = 256-diff_value;
//      Serial.println(send_battery_value, HEX);

      
      Serial.write(BATTERY_TYPE);
      Serial.write(send_battery_value);

      battery_ave = 0;
      battery_count = 0;
      state = STATE_WAIT_FOR_COMMAND;
      break;
    }
      
    case STATE_UART_READ:
      input_type = Serial.read();
      if (input_type == GIMBAL_OTHER_TYPE)
      { 
        pitch_value = Serial.read();
        delay(10);
        yaw_value = Serial.read();

        int yaw_pwm = ((2*yaw_value) >> 4) + 16;
        int pitch_pwm = ((2*pitch_value) >> 4) + 16;
        OCR0A = yaw_pwm;          // Pin6 || 12
        OCR0B = pitch_pwm;        // Pin5 || 11
      }
      else if (input_type == GIMBAL_ROLL_TYPE)
      {
        // Roll is controlled by a slider, so it will have a 200 top value.
        roll_value = Serial.read();
        OCR1B = 10*roll_value + 2000;   // Pin10 || 16
      }
      else if (input_type == SPEED_TYPE)
      {
        input_value = Serial.read();
        OCR1A = 10*input_value + 2000;  // Pin9 || 15
      }
      else if (input_type == END_SET_TYPE)
      {
        // This will have to take into account the direction of the motor.
        // Can be determined from pwm value.
        speedMeasure.setEnding();
      }
      else if (input_type == DISCONNECT)
      {
        // Set all the pwm pins to a 50% duty cycle.
        OCR1A = 0x4E1F;   // Pin9
        OCR1B = 0x4E1F;   // Pin10 
        OCR0B = 16;     // Pin5
      }
      
      state = STATE_WAIT_FOR_COMMAND;
      break;
  }
}

ISR(TIMER0_COMPA_vect)
{
  timer_battery_count++;
}
