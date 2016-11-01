#include <avr/io.h>

int input_pin = A0;
int pwm_pin = 9;

void setup()
{
  pinMode(pwm_pin, OUTPUT);
  
  TCCR1A = 0x00;
  TCCR1A = _BV(WGM11) | _BV(COM1A1);
  TCCR1B = 0x00;
  TCCR1B = _BV(WGM13) | _BV(WGM12) | _BV(CS11);
  
  // Set the TOP value. 16MHz/8 = 2MHz. 2HMz/(0x9C3F+1) = 50Hz.
  ICR1 = 0x9C3F;
  
  // This should equate to a 50% duty cycle.
  OCR1A = 0x4E1F;
}

void loop()
{
  int input = analogRead(input_pin);
  
   if (input < 1000)
   {
     int pwm_value = 2*input + 2000;
     OCR1A = pwm_value;
   }
}
