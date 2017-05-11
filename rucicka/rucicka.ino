//#if ARDUINO >= 100
#include "Arduino.h"
//#else
//#include "WProgram.h"
//#end if

#include <Servo.h>
#include <math.h>

//comment to disable the Force Sensitive Resister on the gripper
//#define FSRG

//Select which arm by uncommenting the corresponding line
//#define AL5A
//#define AL5B
#define AL5D

//uncomment for digital servos in the Shoulder and Elbow
//that use a range of 900ms to 2100ms
//#define DIGITAL_RANGE

#ifdef AL5A
const float A = 3.75;
const float B = 4.25;
#elif defined AL5B
const float A = 4.75;
const float B = 5.00;
#elif defined AL5D
const float A = 5.75;
const float B = 7.375;
#endif

//Arm Servo pins
#define Base_pin 2
#define Shoulder_pin 3
#define Elbow_pin 4
#define Wrist_pin 10
#define Gripper_pin 11
#define WristR_pin 12

//Onboard Speaker
#define Speaker_pin 5

//Radians to Degrees constant
const float rtod = 57.295779;

//Arm Speed Variables
float Speed = 1.0;
int sps = 3;

//Servo Objects
Servo Elb;
Servo Shldr;
Servo Wrist;
Servo Base;
Servo Gripper;
Servo WristR;

// Arm Current Pos
float X = 2;
float Y = 1.25;
float Z = 77.5;
int G = 65;
float WA = -10;
int WR = 80;

// Arm temp pos
float tmpx = 2.25;
float tmpy = 5;
float tmpz = 77.5;
int tmpg = 65;
int tmpwr = 80;
float tmpwa = 15;

// Arm park pos
float parkx = 1.25;
float parky = 2.25;
float parkz = 77.5;
int parkg = 65;
int parkwr = 80;
float parkwa = 15;

// Arm target pos
float tarx = 1.50;
float tary = 4.50;
float tarz = 40.0;
int targ = 65;
int tarwr = 80;
float tarwa = 20;

//boolean mode = true;

int Arm(float x, float y, float z, int g, float wa, int wr) // Here's all the Inverse Kinematics to control the arm
{
  float M = sqrt((y*y)+(x*x));
  if(M <= 0)
    return 1;
  float A1 = atan(y/x);
  if(x <= 0)
    return 1;
  float A2 = acos((A*A-B*B+M*M)/((A*2)*M));
  float Elbow = acos((A*A+B*B-M*M)/((A*2)*B));
  float Shoulder = A1 + A2;
  Elbow = Elbow * rtod;
  Shoulder = Shoulder * rtod;
  if((int)Elbow <= 0 || (int)Shoulder <= 0)
    return 1;
  float Wris = abs(wa - Elbow - Shoulder) - 90;
#ifdef DIGITAL_RANGE
  Elb.writeMicroseconds(map(180 - Elbow, 0, 180, 900, 2100  ));
  Shldr.writeMicroseconds(map(Shoulder, 0, 180, 900, 2100));
#else
  Elb.write(180 - Elbow);
  Shldr.write(Shoulder);
#endif
  Wrist.write(180 - Wris);
  Base.write(z);
  WristR.write(wr);
#ifndef FSRG
  Gripper.write(g);
#endif
  Y = tmpy;
  X = tmpx;
  Z = tmpz;
  WA = tmpwa;
#ifndef FSRG
  G = tmpg;
#endif
  return 0; 
}

void reachPosition(float x, float y, float z, int g, float wa, int wr) {
  
}

void setup()
{
  Serial.begin(9600);
  Base.attach(Base_pin);
  Shldr.attach(Shoulder_pin);
  Elb.attach(Elbow_pin);
  Wrist.attach(Wrist_pin);
  Gripper.attach(Gripper_pin);
  WristR.attach(WristR_pin);
  
//  tmpx = parkx;
//  tmpy = parky;
//  tmpz = parkz;
//  tmpg = parkg;
//  tmpwr = parkwr;
//  tmpwa = parkwa;
//  
//  X = parkx;
//  Y = parky;
//  Z = parkz;
//  G = parkg;
//  WR = parkwr;
//  WA = parkwa;

  Arm(tmpx, tmpy, tmpz, tmpg, tmpwa, tmpwr);
  //Arm(parkx, parky, parkz, parkg, parkwa, parkwr);
}

const float posDeltaX = 0.25;
const float posDeltaY = 0.25;
const float posDeltaZ = 2.5;
const float posDeltaWa = 2.5;
const int posDeltaG = 5;
const int posDeltaWr = 5;
long lastReferenceTime;
unsigned char action;

#define actionUp 119                // w
#define actionDown 115              // s
#define actionLeft 97               // a
#define actionRight 100             // d
#define actionRotCW 101             // e
#define actionRotCCW 113            // q
#define actionGripperOpen 114       // r
#define actionGripperClose 116      // t
#define actionWristUp 122           // z
#define actionWristDown 120         // x
#define actionWristRotCW 103        // g
#define actionWristRotCCW 102       // f

void loop()
{
  if(Serial.available() > 0)
  {
    // Read character
    action = Serial.read();
    if(action > 0)
    {
      // Set action
      switch(action)
      {
        case actionUp:
        tmpy += posDeltaY;
        break;
        
        case actionDown:
        tmpy -= posDeltaY;
        break;
        
        case actionLeft:
        tmpx += posDeltaX;
        break;
        
        case actionRight:
        tmpx -= posDeltaX;
        break;
        
        case actionRotCW:
        tmpz += posDeltaZ;
        break;
        
        case actionRotCCW:
        tmpz -= posDeltaZ;
        break;
        
        case actionGripperOpen:
        tmpg += posDeltaG;
        break;
        
        case actionGripperClose:
        tmpg -= posDeltaG;
        break;
        
        case actionWristUp:
        tmpwa += posDeltaWa;
        break;
        
        case actionWristDown:
        tmpwa -= posDeltaWa;
        break;
        
        case actionWristRotCW:
        tmpwr += posDeltaWr;
        break;
        
        case actionWristRotCCW:
        tmpwr -= posDeltaWr;
        break;
      }
      
      // Display position
      Serial.print("tmpx = "); Serial.print(tmpx, DEC); Serial.print("\ttmpy = "); Serial.print(tmpy, DEC); Serial.print("\ttmpz = "); Serial.print(tmpz, DEC); Serial.print("\ttmpg = "); Serial.print(tmpg, DEC); Serial.print("\ttmpwa = "); Serial.print(tmpwa, DEC); Serial.print("\ttmpwr = "); Serial.println(tmpwr, DEC);
      
      // Move arm
      Arm(tmpx, tmpy, tmpz, tmpg, tmpwa, tmpwr);

      //delay(100);
      // Pause for 100 ms between actions
      lastReferenceTime = millis();
      while(millis() <= (lastReferenceTime + 100)){};
    }
  }
  //delay(1000);
}
