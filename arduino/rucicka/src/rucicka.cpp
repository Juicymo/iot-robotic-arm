#include "Arduino.h"

#include "ServoEasing.h"
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

#define MIN_ELBOW 19
#define MIN_SHOULDER 50
#define MIN_WRIST 0
#define MIN_BASE 40
#define MIN_GRIPPER 30
#define MIN_WRIST_ROTATE 0

#define MAX_ELBOW 90
#define MAX_SHOULDER 170
#define MAX_WRIST 180
#define MAX_BASE 120
#define MAX_GRIPPER 110
#define MAX_WRIST_ROTATE 86

#define MAX_STRING_LEN  20

// Arm Servo pins
#define Base_pin 2
#define Shoulder_pin 3
#define Elbow_pin 4
#define Wrist_pin 10
#define Gripper_pin 11
#define WristR_pin 12

// Onboard Speaker
#define Speaker_pin 5
#define PIN_LED 13

// ServoEasing
#define SERVOS_SPEED 75 // Dangerous speeds - 1, 20, 50, 87
                         // Safe speeds - 75, 100, 450, 550   
// #define PROVIDE_ONLY_LINEAR_MOVEMENT
#define SERVO_DURATION 1250
// Radians to Degrees constant
const float rtod = 57.295779;

//Servo Objects
ServoEasing Elb;
ServoEasing Shldr;
ServoEasing Wrist;
ServoEasing Base;
ServoEasing Gripper;
ServoEasing WristR;

// elbow shoulder wrist base gripper wrist_rotate
// 85 110 90 75 40 86 = pravouhly
// 50 140 90 75 40 86 = default

struct Result {
  float elbow;
  float shoulder;
  float wrist;
};

int move(int elbow, int shoulder, int wrist, int z, int g, int wr) {
#ifdef DIGITAL_RANGE
  Elb.writeMicroseconds(map(180 - elbow, 0, 180, 900, 2100));
  Shldr.writeMicroseconds(map(shoulder, 0, 180, 900, 2100));
#else
  Elb.setEaseToD(180 - elbow, SERVO_DURATION);
  Shldr.setEaseToD(shoulder, SERVO_DURATION);
#endif

  Wrist.setEaseToD(180 - wrist, SERVO_DURATION/2);
  Base.setEaseToD(z, SERVO_DURATION);
  WristR.setEaseToD(wr, SERVO_DURATION/2);
  
#ifndef FSRG
  Gripper.setEaseToD(g, SERVO_DURATION/2);
#endif
  synchronizeAllServosStartAndWaitForAllServosToStop();
  return 0;
}

const byte numChars = 32;
char receivedChars[numChars];
char *i;

boolean newData = false;

long lastReferenceTime;

void setup() {
  Serial.begin(9600);
  
  pinMode(PIN_LED, OUTPUT);
  
  Base.attach(Base_pin);
  Shldr.attach(Shoulder_pin);
  Elb.attach(Elbow_pin);
  Wrist.attach(Wrist_pin);
  Gripper.attach(Gripper_pin);
  WristR.attach(WristR_pin);

  Base.setEasingType(EASE_CUBIC_IN_OUT);
  Shldr.setEasingType(EASE_CUBIC_IN_OUT);
  Elb.setEasingType(EASE_CUBIC_IN_OUT);
  Wrist.setEasingType(EASE_CUBIC_IN_OUT);
  Gripper.setEasingType(EASE_CUBIC_IN_OUT);
  WristR.setEasingType(EASE_CUBIC_IN_OUT);

  int elbow = 19;
  int shoulder = 170;
  int wrist = 80;
  int z = 75;
  int g = 40;
  int wr = 86;
  
  // move(elbow, shoulder, wrist, z, g, wr);
  while(!Serial.available()) { 
    // Serial.print("While loop\n");
    // delay(2000);
    // move(85, 110, 90, 100, 40, 86);
    // delay(2000);
    // move(elbow, shoulder, wrist, z, g, wr);
  }
  
  // Display position
  // Serial.print(elbow, DEC);
  // Serial.print(" ");
  // Serial.print(shoulder, DEC);
  // Serial.print(" ");
  // Serial.print(wrist, DEC);
  // Serial.print(" ");
  // Serial.print(z, DEC);
  // Serial.print(" ");
  // Serial.print(g, DEC);
  // Serial.print(" ");
  // Serial.println(wr, DEC);
  
  // Move arm
  move(elbow, shoulder, wrist, z, g, wr);
  
  // Serial.println("Arm is Ready");
  // exit(0);
}

void recvWithStartEndMarkers() {
    static boolean recvInProgress = false;
    static byte ndx = 0;
    char startMarker = '<';
    char endMarker = '>';
    char rc;

    while (Serial.available() > 0 && newData == false) {
        rc = Serial.read();

        if (recvInProgress == true) {
            if (rc != endMarker) {
                receivedChars[ndx] = rc;
                ndx++;
                if (ndx >= numChars) {
                    ndx = numChars - 1;
                }
            }
            else {
                receivedChars[ndx] = '\0'; // terminate the string
                recvInProgress = false;
                ndx = 0;
                newData = true;
            }
        }

        else if (rc == startMarker) {
            recvInProgress = true;
        }
    }
}

char* subStr(char* str, char *delim, int index) {
  char *act, *sub, *ptr;
  static char copy[MAX_STRING_LEN];
  int i;

  // Since strtok consumes the first arg, make a copy
  strcpy(copy, str);

  for (i = 1, act = copy; i <= index; i++, act = NULL) {
     //Serial.print(".");
     sub = strtok_r(act, delim, &ptr);
     if (sub == NULL) break;
  }
  
  return sub;
}

void handleNewData() {
    if (newData == true) {
        digitalWrite(PIN_LED, HIGH);
        
        // Serial.print("// ");
        // Serial.println(receivedChars);
        
        int raw_elbow     = atoi(subStr(receivedChars, ",", 1));
        int raw_shoulder  = atoi(subStr(receivedChars, ",", 2));
        int raw_wrist     = atoi(subStr(receivedChars, ",", 3));
        int raw_z         = atoi(subStr(receivedChars, ",", 4));
        int raw_g         = atoi(subStr(receivedChars, ",", 5));
        int raw_wr        = atoi(subStr(receivedChars, ",", 6));
        
        // Serial.print(raw_elbow, DEC);
        // Serial.print(",");
        // Serial.print(raw_shoulder, DEC);
        // Serial.print(",");
        // Serial.print(raw_wrist, DEC);
        // Serial.print(",");
        // Serial.print(raw_z, DEC);
        // Serial.print(",");
        // Serial.print(raw_g, DEC);
        // Serial.print(",");
        // Serial.println(raw_wr, DEC);
        
        int elbow     = constrain(raw_elbow, MIN_ELBOW, MAX_ELBOW);
        int shoulder  = constrain(raw_shoulder, MIN_SHOULDER, MAX_SHOULDER);
        int wrist     = constrain(raw_wrist, MIN_WRIST, MAX_WRIST);
        int z         = constrain(raw_z, MIN_BASE, MAX_BASE);
        int g         = constrain(raw_g, MIN_GRIPPER, MAX_GRIPPER);
        int wr        = constrain(raw_wr, MIN_WRIST_ROTATE, MAX_WRIST_ROTATE);
        
        // Display position
        // Serial.print(elbow, DEC);
        // Serial.print(",");
        // Serial.print(shoulder, DEC);
        // Serial.print(",");
        // Serial.print(wrist, DEC);
        // Serial.print(",");
        // Serial.print(z, DEC);
        // Serial.print(",");
        // Serial.print(g, DEC);
        // Serial.print(",");
        // Serial.println(wr, DEC);
    
        // Move arm
        move(elbow, shoulder, wrist, z, g, wr);
        
        newData = false;
        
        digitalWrite(PIN_LED, LOW);
    }
}

void loop() {
  recvWithStartEndMarkers();
  handleNewData();
  
  // if (Serial.available() > 0) {
  //     digitalWrite(PIN_LED, HIGH);
  //
  //     // byte number[1];
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte elbow     = constrain(number[0], MIN_ELBOW, MAX_ELBOW);
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte shoulder  = constrain(number[0], MIN_SHOULDER, MAX_SHOULDER);
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte wrist     = constrain(number[0], MIN_WRIST, MAX_WRIST);
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte z         = constrain(number[0], MIN_BASE, MAX_BASE);
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte g         = constrain(number[0], MIN_GRIPPER, MAX_GRIPPER);
  //     //
  //     // Serial.readBytes(number, 1);
  //     // byte wr        = constrain(number[0], MIN_WRIST_ROTATE, MAX_WRIST_ROTATE);
  //
  //     int raw_elbow     = Serial.parseInt();
  //     int raw_shoulder  = Serial.parseInt();
  //     int raw_wrist     = Serial.parseInt();
  //     int raw_z         = Serial.parseInt();
  //     int raw_g         = Serial.parseInt();
  //     int raw_wr        = Serial.parseInt();
  //
  //     int elbow     = constrain(raw_elbow, MIN_ELBOW, MAX_ELBOW);
  //     int shoulder  = constrain(raw_shoulder, MIN_SHOULDER, MAX_SHOULDER);
  //     int wrist     = constrain(raw_wrist, MIN_WRIST, MAX_WRIST);
  //     int z         = constrain(raw_z, MIN_BASE, MAX_BASE);
  //     int g         = constrain(raw_g, MIN_GRIPPER, MAX_GRIPPER);
  //     int wr        = constrain(raw_wr, MIN_WRIST_ROTATE, MAX_WRIST_ROTATE);
  //
  //     // Display position
  //     Serial.print(elbow, DEC);
  //     Serial.print(" ");
  //     Serial.print(shoulder, DEC);
  //     Serial.print(" ");
  //     Serial.print(wrist, DEC);
  //     Serial.print(" ");
  //     Serial.print(z, DEC);
  //     Serial.print(" ");
  //     Serial.print(g, DEC);
  //     Serial.print(" ");
  //     Serial.println(wr, DEC);
  //
  //     // Move arm
  //     move(elbow, shoulder, wrist, z, g, wr);
  //
  //     // Pause for 100 ms between actions
  //     lastReferenceTime = millis();
  //     while(millis() <= (lastReferenceTime + 100)){};
  //
  //     digitalWrite(PIN_LED, LOW);
  // }
}
