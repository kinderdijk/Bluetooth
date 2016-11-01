//#define _BV(bit) (1<<(bit));

#include <avr/interrupt.h>
#include <avr/io.h>
#include "SoftwareSerial.h"
#include <math.h>

#define E 2.718
#define constant -0.14

int countPin      = 2;     //PD2, Bread 4, Proto 32
int stopPin       = 3;     //PD3, Bread 5, Proto 1
int endSetPin     = 4;     //PD4, Bread 6, Proto 2
int homeSetPin    = 5;     //PD5, Bread 11, Proto 9
int speedPin      = 9;     //PB1, Bread 15, Proto 13

int serialPin = 13;

int volatile currentPosition = 0;
int volatile camDirection = 1;
int currentCount = 0;

int requestDirection = 1;
int requestSpeed = 0;

bool volatile isStopped = false;

int homePoint = 0xFFFF;
int endPoint = 0xFFFF;
int homeSetState = 0x0;
int endSetState = 0x0;
bool isHomeSet = false;
bool isEndSet = false;

int maxPwmValue = 0x0FA0;
int minPwmValue = 0x07D0;
int neutralPwmValue = 0x0BB8;

int pwmSpread = (maxPwmValue-minPwmValue)/2;
int pwmInterval = pwmSpread/7;

int endRemaining = 0x7FFF;
int homeRemaining = 0x7FFF;

int slowPoint = 100;
int setCount = 0x7FFF;

byte input_value;

//SoftwareSerial softSerial(A0, serialPin);

enum States
{
  STATE_WAIT_FOR_COMMAND,
  STATE_SERIAL_READ,
  STATE_ESTOP,
  STATE_SET_HOME,
  STATE_SET_END,
  STATE_SET_END_SPEED_LIMIT,
  STATE_SET_HOME_SPEED_LIMIT
} state;

void setup() {
  // put your setup code here, to run once:
  pinMode(speedPin, OUTPUT);
  pinMode(countPin, INPUT);
  pinMode(stopPin, INPUT);

  // Set pin PD4 and PD5 to inputs. Doing it this way is an attempt to reduce time.
  DDRD &= 0b11001111;
  
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
  
  // Working duty cycle is between 5-10%. (2000-4000)
  OCR1A = neutralPwmValue;   // Pin9 (A)

  // Begin the serial connection.
  Serial.begin(57600);
  Serial.flush();

//  softSerial.begin(115200);

  attachInterrupt(0, count, RISING);
  attachInterrupt(1, eStop, RISING);

  interrupts();

  state = STATE_WAIT_FOR_COMMAND;
}

void loop() {
  cli();
  currentCount = currentPosition;
  sei();

  // If the home and end points are set, determine how far from them we are.
  if (isEndSet) endRemaining = endPoint-currentCount;
  if (isHomeSet) homeRemaining = currentCount-homePoint;

  // If the cable cam is supposed to be stopped but still gets counts those are not counted.
  if (OCR1A > 3000) camDirection = 1;
  else if (OCR1A < 3000) camDirection = -1;
  
  switch (state)
  {
    
    case STATE_WAIT_FOR_COMMAND:
      // Check if the estop button has been pressed.
      if (isStopped) 
      {
        state = STATE_ESTOP;
        break;
      }

      // Check if the state if the home set button has changed.
      if ((PIND & (1<<PD5)) != homeSetState)
      {
        homeSetState = (PIND & (1<<PD5));
        state = STATE_SET_HOME;
        break;
      }

      // Check if the state of the end set button has changed.
      if ((PIND & (1<<PD4)) != endSetState)
      {
        endSetState = (PIND & (1<<PD4));
        state = STATE_SET_END;
        break;
      }
      
      // If there is data available on the serial port read it.
      if (Serial.available() >= 1)
      {
        state = STATE_SERIAL_READ;
        break;
      }


      if (isEndSet && endRemaining < slowPoint && currentCount != setCount)
      {
        state = STATE_SET_END_SPEED_LIMIT;
        break;
      }

      // Check how close we are to the home point.
      if (isHomeSet && homeRemaining < slowPoint && currentCount != setCount)
      {
        state = STATE_SET_HOME_SPEED_LIMIT;
        break;
      }
      
      break;

    case STATE_SERIAL_READ:
      input_value = Serial.read();
      
      // Make sure these values don't violate the speed limits.
      requestSpeed = 10*input_value + 2000;
      if (requestSpeed == 3000)
      {
        requestDirection = 0;
      }
      else
      {
        requestDirection = requestSpeed > 3000 ? 1 : -1;
      }

      if (requestDirection > 0)
      {
        if (isEndSet && endRemaining < slowPoint)
        {
          setPwmOverrideSpeed(endRemaining);
          state = STATE_WAIT_FOR_COMMAND;
          break;
        }
      }
      else if (requestDirection < 0)
      {
        if (isHomeSet && homeRemaining < slowPoint)
        {
          setPwmOverrideSpeed(homeRemaining);
          state = STATE_WAIT_FOR_COMMAND;
          break;
        }
      }

      OCR1A = requestSpeed;

      state = STATE_WAIT_FOR_COMMAND;
      break;

    case STATE_ESTOP:
      // Stay in this state until the button is released.
      if (isStopped) OCR1A = 0x0BB8; // Neutral duty cycle (3000)

      if (PIND & (1<<PD3))
      {
        isStopped = false;
        state = STATE_WAIT_FOR_COMMAND;
        break;
      }

      break;

    case STATE_SET_HOME:
      if (PIND & (1<<PD5))
      {
        isHomeSet = true;
        homePoint = currentCount;
        softSerial.print(currentCount);
      }
      else
      {
        isHomeSet = false;
        homePoint = 0;
        homeRemaining = 0x7FFF;
      }

      state = STATE_WAIT_FOR_COMMAND;
      break;

    case STATE_SET_END:
      if (PIND & (1<<PD4))
      {
        isEndSet = true;
        endPoint = currentCount;
      }
      else
      {
        isEndSet = false;
        endPoint = 0;
        endRemaining = 0x7FFF;
      }

      state = STATE_WAIT_FOR_COMMAND;
      break;

    case STATE_SET_END_SPEED_LIMIT:
      
      if (camDirection > 0)
      {
        setPwmOverrideSpeed(endRemaining);
      }

      state = STATE_WAIT_FOR_COMMAND;
      break;

    case STATE_SET_HOME_SPEED_LIMIT:
      if (camDirection < 0)
      {
        setPwmOverrideSpeed(homeRemaining);
      }

      state = STATE_WAIT_FOR_COMMAND;
      break;
  }
}

void setPwmOverrideSpeed(int proximity)
{
  setCount = currentCount;

  if (proximity > 20)
  {
    double initialOffset = 2*proximity;
    int pwmOffset = floor(initialOffset);
      
    if (camDirection > 0)
    {
      int pwmLimit = neutralPwmValue + pwmOffset;
      if (pwmLimit < OCR1A)
      {
        OCR1A = pwmLimit;
      }
    }
    else if (camDirection < 0)
    {
      int pwmLimit = neutralPwmValue - pwmOffset;
      if (pwmLimit > OCR1A)
      {
        OCR1A = pwmLimit;
      }
    }
  }
  else
  {
    if (proximity == 0)
    {
      OCR1A = neutralPwmValue;
    }
    else if (proximity > 0)
    {
      if (camDirection > 0)
      {
        int pwmLimit = neutralPwmValue + 40;
        if (pwmLimit < OCR1A)
        {
          OCR1A = pwmLimit;
        }
      }
      else if (camDirection < 0)
      {
        int pwmLimit = neutralPwmValue - 40;
        if (pwmLimit > OCR1A)
        {
          OCR1A = pwmLimit;
        }
      }
    }
  }
}

void count()
{
  currentPosition += camDirection;
//  softSerial.print(currentPosition);
}

void eStop()
{
  isStopped = true;
}

