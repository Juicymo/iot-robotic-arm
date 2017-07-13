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
float tmpwa = 15;
int tmpwr = 80;

// elbow shoulder wrist base gripper wrist_rotate
// 85 110 90 70 40 86 = pravouhly
// 50 140 90 70 40 86 = default

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

struct Result {
  float elbow;
  float shoulder;
  float wrist;
};

Result compute(float x, float y, float wa)
{
  float M = sqrt((y*y)+(x*x));
  if(M <= 0)
    return Result { 0, 0, 0 };
  float A1 = atan(y/x);
  if(x <= 0)
    return Result { 0, 0, 0 };
  float A2 = acos((A*A-B*B+M*M)/((A*2)*M));
  float Elbow = acos((A*A+B*B-M*M)/((A*2)*B));
  float Shoulder = A1 + A2;
  Elbow = Elbow * rtod;
  Shoulder = Shoulder * rtod;
  if((int)Elbow <= 0 || (int)Shoulder <= 0)
    return Result { 0, 0, 0 };

  float Wris = abs(wa - Elbow - Shoulder) - 90;

  Result res = { Elbow, Shoulder, Wris };

  return res;
}

int Arm(float x, float y, float z, int g, float wa, int wr) // Here's all the Inverse Kinematics to control the arm
{
  Result res = compute(x, y, wa);

  if (!res.wrist && !res.shoulder && !res.elbow) {
    return 1;
  }

  move(res.elbow, res.shoulder, res.wrist, z, g, wr);
}

void move(float elbow, float shoulder, float wrist, int z, int g, int wr) {
#ifdef DIGITAL_RANGE
  Elb.writeMicroseconds(map(180 - elbow, 0, 180, 900, 2100));
  Shldr.writeMicroseconds(map(shoulder, 0, 180, 900, 2100));
#else
  Elb.write(180 - elbow);
  Shldr.write(shoulder);
#endif

  Wrist.write(180 - wrist);
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

void setup()
{
  Serial.begin(9600);
  Base.attach(Base_pin);
  Shldr.attach(Shoulder_pin);
  Elb.attach(Elbow_pin);
  Wrist.attach(Wrist_pin);
  Gripper.attach(Gripper_pin);
  WristR.attach(WristR_pin);

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
      if(Serial.readString() == "|")
      {      
        float elbow = Serial.parseFloat();
        float shoulder = Serial.parseFloat();
        float wrist = Serial.parseFloat();
        int z = Serial.parseInt();
        int g = Serial.parseInt();
        int wr = Serial.parseInt();
        // Display position
        //Serial.print("tmpx = "); Serial.print(tmpx, DEC); Serial.print("\ttmpy = "); Serial.print(tmpy, DEC); Serial.print("\ttmpz = "); Serial.print(tmpz, DEC); Serial.print("\ttmpg = "); Serial.print(tmpg, DEC); Serial.print("\ttmpwa = "); Serial.print(tmpwa, DEC); Serial.print("\ttmpwr = "); Serial.println(tmpwr, DEC);
        
        // Move arm
        //Arm(tmpx, tmpy, tmpz, tmpg, tmpwa, tmpwr);
        if(Serial.readString() == "|")
        {
          move(elbow, shoulder, wrist, z, g, wr);
    
          //delay(100);
          // Pause for 100 ms between actions
          lastReferenceTime = millis();
          while(millis() <= (lastReferenceTime + 100)){};
        }
      }
  }
  //delay(1000);
}
