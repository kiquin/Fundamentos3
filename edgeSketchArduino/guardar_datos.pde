import processing.serial.*;

Serial myPort;
int linefeed = 10;   // Linefeed in ASCII
int numSensors = 6;  // we will be expecting for reading data from four sensors
int sensors[];       // array to read the 4 values
int pSensors[];      // array to store the previuos reading, usefur for comparing
// actual reading with the last one

int x = 0;

Table misDatos;

void setup() {
  size(1200, 800);

  background(0);
  
  // List all the available serial ports in the output pane.
  // You will need to choose the port that the Wiring board is
  // connected to from this list. The first port in the list is
  // port #0 and the third port in the list is port #2.
  println(Serial.list());

  myPort = new Serial(this, Serial.list()[1], 9600);
  // read bytes into a buffer until you get a linefeed (ASCII 10):
  myPort.bufferUntil(linefeed);
  
  misDatos = new Table();
  
  misDatos.addColumn("id");
  misDatos.addColumn("hora");
  misDatos.addColumn("luz");
  misDatos.addColumn("potA");

}

void draw() {
 //Codigo para sensores
  if ((pSensors != null)&&(sensors != null)) {

     //if valid data arrays are not null
     //compare each sensor value with the previuos reading
     //to establish change

    for (int i=0; i < numSensors; i++) {
      float f = sensors[i] - pSensors[i];  // actual - previous value
      if (f > 0) {
        println("sensor "+i+" increased by "+f);  // value increased
      }
      if (f < 0) {
        println("sensor "+i+" decreased by "+f);  // value decreased
      }
    }
     //now do something with the values read sensors[0] .. sensors[3]
  }

  //Actualiza el color y posiciones

  float luz = map(sensors[4],0,1023,0,2*height/3); //luz
  float pot = map(sensors[2],0,1023,0,2*height/3); //pot
  //background(0);
  stroke(200);
  strokeWeight(1);
  line(x,height*2/3,x,height*2/3 - luz);
    stroke(100);

  line(x+1,height*2/3,x+1,height*2/3 - pot);
  x = x+2;
  if(x>width) {
    background(0);
    x=0;
  }
  
  TableRow newRow = misDatos.addRow();
  newRow.setInt("id", misDatos.getRowCount() - 1);
  newRow.setString("hora", hour()+":"+minute()+":"+second());
  newRow.setInt("luz", sensors[4]);
  newRow.setInt("potA", sensors[2]);

  
  if(sensors[5] == 1) {
      saveTable(misDatos, "data/new.csv");
  }
  

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

     //print out the values you got:

    for (int sensorNum = 0; sensorNum < sensors.length; sensorNum++) {
      print("Sensor " + sensorNum + ": " + sensors[sensorNum] + "\t");
    }

    // add a linefeed after all the sensor values are printed:
    println();

  }
}
