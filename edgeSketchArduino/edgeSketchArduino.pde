import processing.serial.*;

Serial myPort;
int linefeed = 10;   // Linefeed in ASCII
int numSensors = 6;  // we will be expecting for reading data from four sensors
int sensors[];       // array to read the 4 values
int pSensors[];      // array to store the previuos reading, usefur for comparing
// actual reading with the last one

color miColor;

void setup() {
  size(1200, 800);
  colorMode(HSB, 360, 100, 100);

  background(360,0,100);
  miColor = color(360,100,100);
  
  // List all the available serial ports in the output pane.
  // You will need to choose the port that the Wiring board is
  // connected to from this list. The first port in the list is
  // port #0 and the third port in the list is port #2.
  println(Serial.list());

  myPort = new Serial(this, Serial.list()[1], 9600);
  // read bytes into a buffer until you get a linefeed (ASCII 10):
  myPort.bufferUntil(linefeed);
}

void draw() {
 //Codigo para sensores
  if ((pSensors != null)&&(sensors != null)) {

    // if valid data arrays are not null
    // compare each sensor value with the previuos reading
    // to establish change

    for (int i=0; i < numSensors; i++) {
      float f = sensors[i] - pSensors[i];  // actual - previous value
      if (f > 0) {
        println("sensor "+i+" increased by "+f);  // value increased
      }
      if (f < 0) {
        println("sensor "+i+" decreased by "+f);  // value decreased
      }
    }
    // now do something with the values read sensors[0] .. sensors[3]
  }

  //Actualiza el color y posiciones
  float potX = map(sensors[0],0,1024,0,width);
  float potY = map(sensors[1],0,1024,0,height);
  float ppotX = map(pSensors[0],0,1024,0,width);
  float ppotY = map(pSensors[1],0,1024,0,height);
  
  float hue = map(sensors[2],0,1023,0,360); //pot
  float sat = map(constrain(sensors[3],30,60),30,60,0,100); //temp
  float bri = map(constrain(sensors[4],500,900),500,900,0,100); //luz

  miColor = color(hue,sat,bri);
  

  //Edge sketch
  //fill(miColor);
  //noStroke();
  //circle(potX,potY,2);

  stroke(miColor);
  strokeWeight(2);
  line(ppotX,ppotY,potX,potY);
  
  if(sensors[5] == 1) {
    background(360,0,100);
  }
  
  //Display de color actual
  fill(miColor);
  stroke(0,0,0);
  strokeWeight(1);

  circle(20,20,25);

}

void serialEvent(Serial myPort) {

  // read the serial buffer:
  String myString = myPort.readStringUntil(linefeed);

  // if you got any bytes other than the linefeed:
  if (myString != null) {

    myString = trim(myString);

    // split the string at the commas
    // and convert the sections into integers:

    pSensors = sensors;
    sensors = int(split(myString, ','));

    // print out the values you got:

    for (int sensorNum = 0; sensorNum < sensors.length; sensorNum++) {
      print("Sensor " + sensorNum + ": " + sensors[sensorNum] + "\t");
    }

    // add a linefeed after all the sensor values are printed:
    println();

  }
}
