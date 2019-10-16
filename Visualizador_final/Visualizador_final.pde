// Este proyecto utiliza el codigo para el A-weighting que se encuentra en la siguiente pregunta de StackOverflow
// con el fin de que la FFT responda de manera más acorde a la percepción humana
// https://stackoverflow.com/questions/20408388/how-to-filter-fft-data-for-audio-visualisation

import ddf.minim.analysis.*;
import ddf.minim.*;

float smoothing = 0.85;
boolean debug = false;
int umbral = 80;
int size;

Visualizer one;
Visualizer two;
Visualizer three;

VisualizerLineIn here;

PFont helv;
PFont hLight;
PImage img;

int selector = 1;

void setup() {
  fullScreen(P2D);
  background(255, 255, 242);
  noCursor();

  img = loadImage("keys.png");
  helv = createFont("HelveticaNeue", 32);
  hLight = createFont("HelveticaNeue-Light", 32);

  size = width/4;

  one = new Visualizer(this, "fopre.wav", size);
  two = new Visualizer(this, "city.wav", size);
  three = new Visualizer(this, "library.wav", size);

  here = new VisualizerLineIn(this, size);

  one.unmute();
}

void draw() {
  background(255, 255, 242);

  here.display(0, height/2 - size/2);

  one.display(width/4, height/2 - size/2);
  two.display(width/2, height/2 - size/2);
  three.display(3*width/4, height/2 - size/2);

  push();
  fill(0);
  textAlign(CENTER);
  textFont(helv);
  fill(255, 172, 51);

  text("Aquí", width/8, height/2+size/2);
  text("Plaza de comidas", width/4+width/8, height/2+size/2);
  text("Calle", width/2+width/8, height/2+size/2);
  text("Biblioteca", 3*width/4 + width/8, height/2+size/2);
  image(img, width/4+64, 5*height/6, 100, 100);
    textFont(hLight);

  text("La exposición prologanda a sonidos de más de 85dB puede llevar a la pérdida auditiva", 
    width/2, height/6);
  fill(0);
  text("Escoge el sonido presionando izquierda o derecha", width/2+100, 5*height/6+64);

  pop();

  //fill(255, 172, 51, 128);
  //        textFont(helv);
  //        text("85dB",20, height/2 - size/3);

  fill(255, 0, 0);
  if (debug) {
    textFont(hLight);
    text("smoothing: " + (int)(smoothing*100)+"\numbral: "+ umbral + "\n" + width + " x " + height + "\nFPS: " + frameRate + "\n", 10, 20);
  }

  push();
  fill(255, 172, 51, 128);
  noStroke();
  triangle(selector*width/4+size/2-25, height/2-size/2, 
    selector*width/4+size/2+25, height/2-size/2, 
    selector*width/4+size/2, height/2-size/2+40);
  pop();
}

void keyPressed() {
  //if (keyCode == UP && umbral < 120) umbral+=1;
  //if (keyCode == DOWN && umbral > 30) umbral-=1;
  if (keyCode == LEFT && selector > 1) selector-=1;
  if (keyCode == RIGHT && selector < 3) selector+=1;
  if (keyCode == TAB) debug = !debug;

  switch(selector) {
  case 1:
    one.unmute();
    two.mute();
    three.mute();
    break;
  case 2:
    one.mute();
    two.unmute();
    three.mute();
    break;
  case 3:
    one.mute();
    two.mute();
    three.unmute();
    break;
  }
}

class Visualizer {
  Minim       minim;
  //AudioInput  in;
  AudioPlayer in;

  FFT         fft;

  PGraphics src;
  PShader blur;
  PGraphics pass1, pass2;

  final boolean useDB = true;
  final boolean useAWeighting = true; // only used in dB mode, because the table I found was in dB 
  final boolean resetBoundsAtEachStep = false;
  final float maxViewportUsage = 0.85;
  final int minBandwidthPerOctave = 200;
  final int bandsPerOctave = 10;
  final float maxCentreFrequency = 18000;
  float[] fftSmooth;
  int avgSize;

  float minVal = 0.0;
  float maxVal = 0.0;
  boolean firstMinDone = false;

  final float[] aWeightFrequency = { 
    10, 12.5, 16, 20, 
    25, 31.5, 40, 50, 
    63, 80, 100, 125, 
    160, 200, 250, 315, 
    400, 500, 630, 800, 
    1000, 1250, 1600, 2000, 
    2500, 3150, 4000, 5000, 
    6300, 8000, 10000, 12500, 
    16000, 20000 
  };

  final float[] aWeightDecibels = {
    -70.4, -63.4, -56.7, -50.5, 
    -44.7, -39.4, -34.6, -30.2, 
    -26.2, -22.5, -19.1, -16.1, 
    -13.4, -10.9, -8.6, -6.6, 
    -4.8, -3.2, -1.9, -0.8, 
    0.0, 0.6, 1.0, 1.2, 
    1.3, 1.2, 1.0, 0.5, 
    -0.1, -1.1, -2.5, -4.3, 
    -6.6, -9.3 
  };

  float[] aWeightDBAtBandCentreFreqs;
  int xsize;

  Visualizer(PApplet p, String file, int size) {

    minim = new Minim(p);
    //in = minim.getLineIn(Minim.STEREO, 512);
    in = minim.loadFile(file, 2048);

    in.loop();
    in.mute();

    xsize = size;

    fft = new FFT(in.bufferSize(), in.sampleRate());

    // Use logarithmically-spaced averaging
    fft.logAverages(minBandwidthPerOctave, bandsPerOctave);
    aWeightDBAtBandCentreFreqs = calculateAWeightingDBForFFTAverages(fft);

    avgSize = fft.avgSize();
    // Only use freqs up to maxCentreFrequency - ones above this may have
    // values too small that will skew our range calculation for all time
    while (fft.getAverageCenterFrequency(avgSize-1) > maxCentreFrequency) {
      avgSize--;
    }

    fftSmooth = new float[avgSize];

    src = createGraphics(xsize, xsize, P2D); 
    src.beginDraw();
    src.colorMode(HSB, 360, 100, 100);
    src.endDraw();

    blur = loadShader("blur2.glsl");
    blur.set("blurSize", 20);

    pass1 = createGraphics(xsize, xsize, P2D);
    pass1.noSmooth();  

    pass2 = createGraphics(xsize, xsize, P2D);
    pass2.noSmooth();
  }

  float[] calculateAWeightingDBForFFTAverages(FFT fft) {
    float[] result = new float[fft.avgSize()];
    for (int i = 0; i < result.length; i++) {
      result[i] = calculateAWeightingDBAtFrequency(fft.getAverageCenterFrequency(i));
    }
    return result;
  }

  float calculateAWeightingDBAtFrequency(float frequency) {
    return linterp(aWeightFrequency, aWeightDecibels, frequency);
  }

  float dB(float x) {
    if (x == 0) {
      return 0;
    } else {
      return 10 * (float)Math.log10(x);
    }
  }

  float todB(float x) {
    float ref = 0.000005;
    if (x == 0) {
      return 0;
    } else {
      return 20 * (float)Math.log10(x/ref);
    }
  }

  float linterp(float[] x, float[] y, float xx) {
    assert(x.length > 1);
    assert(x.length == y.length);

    float result = 0.0;
    boolean found = false;

    if (x[0] > xx) {
      result = y[0];
      found = true;
    }

    if (!found) {
      for (int i = 1; i < x.length; i++) {
        if (x[i] > xx) {
          result = y[i-1] + ((xx - x[i-1]) / (x[i] - x[i-1])) * (y[i] - y[i-1]);
          found = true;
          break;
        }
      }
    }

    if (!found) {
      result = y[y.length-1];
    }

    return result;
  }

  void mute() {
    in.mute();
  }

  void unmute() {
    in.unmute();
  }

  void display(int x, int y) {
    float level = in.mix.level();
    blur.set("sigma", 15*exp(level)-15); 

    src.beginDraw();
    src.background(60, 5, 100); //pearly gates
    //src.background(255,255,242);
    src.noStroke();

    fft.forward(in.mix);

    if (resetBoundsAtEachStep) {
      minVal = 0.0;
      maxVal = 0.0;
      firstMinDone = false;
    }

    for (int i = 0; i < avgSize; i++) {
      // Get spectrum value (using dB conversion or not, as desired)
      float fftCurr;
      if (useDB) {
        fftCurr = dB(fft.getAvg(i));
        if (useAWeighting) {
          fftCurr += aWeightDBAtBandCentreFreqs[i];
        }
      } else {
        fftCurr = fft.getAvg(i);
      }

      // Smooth using exponential moving average
      fftSmooth[i] = (smoothing) * fftSmooth[i] + ((1 - smoothing) * fftCurr);

      // Find max and min values ever displayed across whole spectrum
      if (fftSmooth[i] > maxVal) {
        maxVal = fftSmooth[i];
      }
      if (!firstMinDone || (fftSmooth[i] < minVal)) {
        minVal = fftSmooth[i];
      }
    }

    // Calculate the total range of smoothed spectrum; this will be used to scale all values to range 0...1
    src.translate(xsize/2, xsize/2);

    float noiseSize = 10*level;
    float levelNorm = map(level, 0, sqrt(2), 0, 1);
    float maxSize = map(todB(level), 0, 110, 0, xsize-20);

    for (int i = 0; i < avgSize; i++)
    {
      float radio = max(0.0, map(fftSmooth[i], minVal, maxVal, 0, maxSize));

      float hue = map(i, 0, avgSize, 360, 0);
      float sat = map(fftSmooth[i], minVal, maxVal, 50, 10);
      float alpha = map(fftSmooth[i]*level, minVal, maxVal, 50, 10);

      float offX = random(-noiseSize, noiseSize);
      float offY = random(-noiseSize, noiseSize);

      //Color circle
      src.fill(hue, sat, 0, alpha);
      src.ellipse(offX, offY, radio, radio);

      //BG color circle to form a ring
      src.fill(60, 5, 100);
      src.ellipse(offX, offY, 0.9*radio*(1-levelNorm), 0.9*radio*(1-levelNorm));
    }

    src.endDraw();

    // Applying the blur shader along the vertical direction   
    blur.set("horizontalPass", 0);
    pass1.beginDraw();            
    pass1.shader(blur);  
    pass1.image(src, 0, 0);
    pass1.endDraw();

    // Applying the blur shader along the horizontal direction      
    blur.set("horizontalPass", 1);
    pass2.beginDraw();            
    pass2.shader(blur);  
    pass2.image(pass1, 0, 0);
    pass2.endDraw();    

    image(pass2, x, y);

    push();
    translate(x+xsize/2, y+xsize/2);
    noFill();
    stroke(255, 172, 51, 128);
    strokeWeight(4);

    float radioWarn = map(umbral, 0, 110, 0, xsize-20);
    ellipse(0, 0, radioWarn, radioWarn);
    pop();


    fill(255, 0, 0);
    if (debug) {
      text("level: " + level +"\ndB: " + todB(level), x, y);
    }
  }
}

class VisualizerLineIn {
  Minim       minim;
  AudioInput  in;
  FFT         fft;

  PGraphics src;
  PShader blur;
  PGraphics pass1, pass2;

  final boolean useDB = true;
  final boolean useAWeighting = true; // only used in dB mode, because the table I found was in dB 
  final boolean resetBoundsAtEachStep = false;
  final float maxViewportUsage = 0.85;
  final int minBandwidthPerOctave = 200;
  final int bandsPerOctave = 10;
  final float maxCentreFrequency = 18000;
  float[] fftSmooth;
  int avgSize;

  float minVal = 0.0;
  float maxVal = 0.0;
  boolean firstMinDone = false;

  final float[] aWeightFrequency = { 
    10, 12.5, 16, 20, 
    25, 31.5, 40, 50, 
    63, 80, 100, 125, 
    160, 200, 250, 315, 
    400, 500, 630, 800, 
    1000, 1250, 1600, 2000, 
    2500, 3150, 4000, 5000, 
    6300, 8000, 10000, 12500, 
    16000, 20000 
  };

  final float[] aWeightDecibels = {
    -70.4, -63.4, -56.7, -50.5, 
    -44.7, -39.4, -34.6, -30.2, 
    -26.2, -22.5, -19.1, -16.1, 
    -13.4, -10.9, -8.6, -6.6, 
    -4.8, -3.2, -1.9, -0.8, 
    0.0, 0.6, 1.0, 1.2, 
    1.3, 1.2, 1.0, 0.5, 
    -0.1, -1.1, -2.5, -4.3, 
    -6.6, -9.3 
  };

  float[] aWeightDBAtBandCentreFreqs;
  int xsize;

  VisualizerLineIn (PApplet p, int size) {

    minim = new Minim(p);
    in = minim.getLineIn(Minim.STEREO, 512);

    in.mute();

    xsize = size;

    fft = new FFT(in.bufferSize(), in.sampleRate());

    // Use logarithmically-spaced averaging
    fft.logAverages(minBandwidthPerOctave, bandsPerOctave);
    aWeightDBAtBandCentreFreqs = calculateAWeightingDBForFFTAverages(fft);

    avgSize = fft.avgSize();
    // Only use freqs up to maxCentreFrequency - ones above this may have
    // values too small that will skew our range calculation for all time
    while (fft.getAverageCenterFrequency(avgSize-1) > maxCentreFrequency) {
      avgSize--;
    }

    fftSmooth = new float[avgSize];

    src = createGraphics(xsize, xsize, P2D); 
    src.beginDraw();
    src.colorMode(HSB, 360, 100, 100);
    src.endDraw();

    blur = loadShader("blur2.glsl");
    blur.set("blurSize", 20);

    pass1 = createGraphics(xsize, xsize, P2D);
    pass1.noSmooth();  

    pass2 = createGraphics(xsize, xsize, P2D);
    pass2.noSmooth();
  }

  float[] calculateAWeightingDBForFFTAverages(FFT fft) {
    float[] result = new float[fft.avgSize()];
    for (int i = 0; i < result.length; i++) {
      result[i] = calculateAWeightingDBAtFrequency(fft.getAverageCenterFrequency(i));
    }
    return result;
  }

  float calculateAWeightingDBAtFrequency(float frequency) {
    return linterp(aWeightFrequency, aWeightDecibels, frequency);
  }

  float dB(float x) {
    if (x == 0) {
      return 0;
    } else {
      return 10 * (float)Math.log10(x);
    }
  }

  float todB(float x) {
    float ref = 0.000005;
    if (x == 0) {
      return 0;
    } else {
      return 20 * (float)Math.log10(x/ref);
    }
  }

  float linterp(float[] x, float[] y, float xx) {
    assert(x.length > 1);
    assert(x.length == y.length);

    float result = 0.0;
    boolean found = false;

    if (x[0] > xx) {
      result = y[0];
      found = true;
    }

    if (!found) {
      for (int i = 1; i < x.length; i++) {
        if (x[i] > xx) {
          result = y[i-1] + ((xx - x[i-1]) / (x[i] - x[i-1])) * (y[i] - y[i-1]);
          found = true;
          break;
        }
      }
    }

    if (!found) {
      result = y[y.length-1];
    }

    return result;
  }

  void mute() {
    in.mute();
  }

  void unmute() {
    in.unmute();
  }

  void display(int x, int y) {
    float level = in.mix.level();
    blur.set("sigma", 15*exp(level)-15); 

    src.beginDraw();
    src.background(60, 5, 100); //pearly gates
    //src.background(255,255,242);
    src.noStroke();

    fft.forward(in.mix);

    if (resetBoundsAtEachStep) {
      minVal = 0.0;
      maxVal = 0.0;
      firstMinDone = false;
    }

    for (int i = 0; i < avgSize; i++) {
      // Get spectrum value (using dB conversion or not, as desired)
      float fftCurr;
      if (useDB) {
        fftCurr = dB(fft.getAvg(i));
        if (useAWeighting) {
          fftCurr += aWeightDBAtBandCentreFreqs[i];
        }
      } else {
        fftCurr = fft.getAvg(i);
      }

      // Smooth using exponential moving average
      fftSmooth[i] = (smoothing) * fftSmooth[i] + ((1 - smoothing) * fftCurr);

      // Find max and min values ever displayed across whole spectrum
      if (fftSmooth[i] > maxVal) {
        maxVal = fftSmooth[i];
      }
      if (!firstMinDone || (fftSmooth[i] < minVal)) {
        minVal = fftSmooth[i];
      }
    }

    // Calculate the total range of smoothed spectrum; this will be used to scale all values to range 0...1
    src.translate(xsize/2, xsize/2);

    float noiseSize = 10*level;
    float levelNorm = map(level, 0, sqrt(2), 0, 1);
    float maxSize = map(todB(level), 0, 110, 0, xsize-20);

    for (int i = 0; i < avgSize; i++)
    {
      float radio = max(0.0, map(fftSmooth[i], minVal, maxVal, 0, maxSize));

      float hue = map(i, 0, avgSize, 360, 0);
      float sat = map(fftSmooth[i], minVal, maxVal, 50, 10);
      float alpha = map(fftSmooth[i]*level, minVal, maxVal, 50, 10);

      float offX = random(-noiseSize, noiseSize);
      float offY = random(-noiseSize, noiseSize);

      //Color circle
      src.fill(hue, sat, 0, alpha);
      src.ellipse(offX, offY, radio, radio);

      //BG color circle to form a ring
      src.fill(60, 5, 100);
      src.ellipse(offX, offY, 0.9*radio*(1-levelNorm), 0.9*radio*(1-levelNorm));
    }

    src.endDraw();

    // Applying the blur shader along the vertical direction   
    blur.set("horizontalPass", 0);
    pass1.beginDraw();            
    pass1.shader(blur);  
    pass1.image(src, 0, 0);
    pass1.endDraw();

    // Applying the blur shader along the horizontal direction      
    blur.set("horizontalPass", 1);
    pass2.beginDraw();            
    pass2.shader(blur);  
    pass2.image(pass1, 0, 0);
    pass2.endDraw();    

    image(pass2, x, y);

    push();
    translate(x+xsize/2, y+xsize/2);
    noFill();
    stroke(255, 172, 51, 128);
    strokeWeight(4);

    float radioWarn = map(umbral, 0, 110, 0, xsize-20);
    ellipse(0, 0, radioWarn, radioWarn);
    pop();


    fill(255, 0, 0);
    if (debug) {
      text("level: " + level +"\ndB: " + todB(level), x, y);
    }
  }
}
