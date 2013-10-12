class Pulley extends SCPattern {
  
  final int NUM_DIVISIONS = 16;
  private final Accelerator[] gravity = new Accelerator[NUM_DIVISIONS];
  private final Click[] delays = new Click[NUM_DIVISIONS];
  
  private final Click reset = new Click(9000);
  private boolean isRising = false;
  
  private BasicParameter sz = new BasicParameter("SIZE", 0.5);
  private BasicParameter beatAmount = new BasicParameter("BEAT", 0.1);
  
  Pulley(GLucose glucose) {
    super(glucose);
    for (int i = 0; i < NUM_DIVISIONS; ++i) {
      addModulator(gravity[i] = new Accelerator(0, 0, 0));
      addModulator(delays[i] = new Click(0));
    }
    addModulator(reset).start();
    addParameter(sz);
    addParameter(beatAmount);
    trigger();
  }
  
  private void trigger() {
    isRising = !isRising;
    int i = 0;
    for (Accelerator g : gravity) {
      if (isRising) {
        g.setSpeed(random(40, 50), 0).start();
      } else {
        g.setVelocity(0).setAcceleration(-420);
        delays[i].setDuration(random(0, 500)).trigger();
      }
      ++i;
    }
  }
  
  public void run(double deltaMs) {
    if (reset.click()) {
      trigger();
    }
    int j = 0;
    for (Click d : delays) {
      if (d.click()) {
        gravity[j].start();
        d.stop();
      }
      ++j;
    }   
    
    for (Accelerator g : gravity) {
      if (isRising) {
        if (g.getValuef() > model.yMax) {
          g.stop();
        } else if (g.getValuef() > model.yMax*.55) {
          if (g.getVelocityf() > 10) {
            g.setAcceleration(-16);
          } else {
            g.setAcceleration(0);
          }
        }
      } else {
        if (g.getValuef() < 0) {
          g.setValue(-g.getValuef());
          g.setVelocity(-g.getVelocityf() * random(0.74, 0.84));
        }
      }
    }
    
    float fPos = 1 - lx.tempo.rampf();
    if (fPos < .2) {
      fPos = .2 + 4 * (.2 - fPos);
    }
    float falloff = 100. / (3 + sz.getValuef() * 36 + fPos * beatAmount.getValuef()*48);
    for (Point p : model.points) {
      int i = (int) constrain((p.x - model.xMin) * NUM_DIVISIONS / (model.xMax - model.xMin), 0, NUM_DIVISIONS-1);
      colors[p.index] = color(
        (lx.getBaseHuef() + abs(p.x - model.cx)*.8 + p.y*.4) % 360,
        constrain(130 - p.y*.8, 0, 100),
        max(0, 100 - abs(p.y - gravity[i].getValuef())*falloff)
      );
    }
  }
}

class ViolinWave extends SCPattern {
  
  BasicParameter level = new BasicParameter("LVL", 0.45);
  BasicParameter range = new BasicParameter("RNG", 0.5);
  BasicParameter edge = new BasicParameter("EDG", 0.5);
  BasicParameter release = new BasicParameter("RLS", 0.5);
  BasicParameter speed = new BasicParameter("SPD", 0.5);
  BasicParameter amp = new BasicParameter("AMP", 0.25);
  BasicParameter period = new BasicParameter("WAVE", 0.5);
  BasicParameter pSize = new BasicParameter("PSIZE", 0.5);
  BasicParameter pSpeed = new BasicParameter("PSPD", 0.5);
  BasicParameter pDensity = new BasicParameter("PDENS", 0.25);
  
  LinearEnvelope dbValue = new LinearEnvelope(0, 0, 10);

  ViolinWave(GLucose glucose) {
    super(glucose);
    addParameter(level);
    addParameter(edge);
    addParameter(range);
    addParameter(release);
    addParameter(speed);
    addParameter(amp);
    addParameter(period);
    addParameter(pSize);
    addParameter(pSpeed);
    addParameter(pDensity);

    addModulator(dbValue);
  }
  
  final List<Particle> particles = new ArrayList<Particle>();
  
  class Particle {
    
    LinearEnvelope x = new LinearEnvelope(0, 0, 0);
    LinearEnvelope y = new LinearEnvelope(0, 0, 0);
    
    Particle() {
      addModulator(x);
      addModulator(y);
    }
    
    Particle trigger(boolean direction) {
      float xInit = random(model.xMin, model.xMax);
      float time = 3000 - 2500*pSpeed.getValuef();
      x.setRange(xInit, xInit + random(-40, 40), time).trigger();
      y.setRange(model.cy + 10, direction ? model.yMax + 50 : model.yMin - 50, time).trigger();
      return this;
    }
    
    boolean isActive() {
      return x.isRunning() || y.isRunning();
    }
    
    public void run(double deltaMs) {
      if (!isActive()) {
        return;
      }
      
      float pFalloff = (30 - 27*pSize.getValuef());
      for (Point p : model.points) {
        float b = 100 - pFalloff * (abs(p.x - x.getValuef()) + abs(p.y - y.getValuef()));
        if (b > 0) {
          colors[p.index] = blendColor(colors[p.index], color(
            lx.getBaseHuef(), 20, b
          ), ADD);
        }
      }
    }
  }
  
  float[] centers = new float[30];
  double accum = 0;
  boolean rising = true;
  
  void fireParticle(boolean direction) {
    boolean gotOne = false;
    for (Particle p : particles) {
      if (!p.isActive()) {
       p.trigger(direction);
       return;
      }
    }
    particles.add(new Particle().trigger(direction));
  }
  
  public void run(double deltaMs) {
    accum += deltaMs / (1000. - 900.*speed.getValuef());
    for (int i = 0; i < centers.length; ++i) {
      centers[i] = model.cy + 30*amp.getValuef()*sin((float) (accum + (i-centers.length/2.)/(1. + 9.*period.getValuef())));
    }
    
    float zeroDBReference = pow(10, (50 - 190*level.getValuef())/20.);
    float dB = 20*GraphicEQ.log10(lx.audioInput().mix.level() / zeroDBReference);    
    if (dB > dbValue.getValuef()) {
      rising = true;
      dbValue.setRangeFromHereTo(dB, 10).trigger();
    } else {
      if (rising) {
        for (int j = 0; j < pDensity.getValuef()*3; ++j) {
          fireParticle(true);
          fireParticle(false);
        }
      }
      rising = false;
      dbValue.setRangeFromHereTo(max(dB, -96), 50 + 1000*release.getValuef()).trigger();
    }
    float edg = 1 + edge.getValuef() * 40;
    float rng = (78 - 64 * range.getValuef()) / (model.yMax - model.cy);
    float val = max(2, dbValue.getValuef());
    
    for (Point p : model.points) {
      int ci = (int) lerp(0, centers.length-1, (p.x - model.xMin) / (model.xMax - model.xMin));
      float rFactor = 1.0 -  0.9 * abs(p.x - model.cx) / (model.xMax - model.cx);
      colors[p.index] = color(
        (lx.getBaseHuef() + abs(p.x - model.cx)) % 360,
        min(100, 20 + 8*abs(p.y - centers[ci])),
        constrain(edg*(val*rFactor - rng * abs(p.y-centers[ci])), 0, 100)
      );
    }
    
    for (Particle p : particles) {
      p.run(deltaMs);
    }
  }
}

class BouncyBalls extends SCPattern {
  
  static final int NUM_BALLS = 6;
  
  class BouncyBall {
       
    Accelerator yPos;
    TriangleLFO xPos = new TriangleLFO(0, model.xMax, random(8000, 19000));
    float zPos;
    
    BouncyBall(int i) {
      addModulator(xPos).setBasis(random(0, TWO_PI)).start();
      addModulator(yPos = new Accelerator(0, 0, 0));
      zPos = lerp(model.zMin, model.zMax, (i+2.) / (NUM_BALLS + 4.));
    }
    
    void bounce(float midiVel) {
      float v = 100 + 8*midiVel;
      yPos.setSpeed(v, getAccel(v, 60 / lx.tempo.bpmf())).start();
    }
    
    float getAccel(float v, float oneBeat) {
      return -2*v / oneBeat;
    }
    
    void run(double deltaMs) {
      float flrLevel = flr.getValuef() * model.xMax/2.;
      if (yPos.getValuef() < flrLevel) {
        if (yPos.getVelocity() < -50) {
          yPos.setValue(2*flrLevel-yPos.getValuef());
          float v = -yPos.getVelocityf() * bounce.getValuef();
          yPos.setSpeed(v, getAccel(v, 60 / lx.tempo.bpmf()));
        } else {
          yPos.setValue(flrLevel).stop();
        }
      }
      float falloff = 130.f / (12 + blobSize.getValuef() * 36);
      float xv = xPos.getValuef();
      float yv = yPos.getValuef();
      
      for (Point p : model.points) {
        float d = sqrt((p.x-xv)*(p.x-xv) + (p.y-yv)*(p.y-yv) + .1*(p.z-zPos)*(p.z-zPos));
        float b = constrain(130 - falloff*d, 0, 100);
        if (b > 0) {
          colors[p.index] = blendColor(colors[p.index], color(
            (lx.getBaseHuef() + p.y*.5 + abs(model.cx - p.x) * .5) % 360,
            max(0, 100 - .45*(p.y - flrLevel)),
            b
          ), ADD);
        }
      }
    }
  }
  
  final BouncyBall[] balls = new BouncyBall[NUM_BALLS];
  
  final BasicParameter bounce = new BasicParameter("BNC", .8);
  final BasicParameter flr = new BasicParameter("FLR", 0);
  final BasicParameter blobSize = new BasicParameter("SIZE", 0.5);
  
  BouncyBalls(GLucose glucose) {
    super(glucose);
    for (int i = 0; i < balls.length; ++i) {
      balls[i] = new BouncyBall(i);
    }
    addParameter(bounce);
    addParameter(flr);
    addParameter(blobSize);
  }
  
  public void run(double deltaMs) {
    setColors(#000000);
    for (BouncyBall b : balls) {
      b.run(deltaMs);
    }
  }
  
  public boolean noteOnReceived(Note note) {
    int pitch = (note.getPitch() + note.getChannel()) % NUM_BALLS;
    balls[pitch].bounce(note.getVelocity());
    return true;
  }
}

class SpaceTime extends SCPattern {

  SinLFO pos = new SinLFO(0, 1, 3000);
  SinLFO rate = new SinLFO(1000, 9000, 13000);
  SinLFO falloff = new SinLFO(10, 70, 5000);
  float angle = 0;

  BasicParameter rateParameter = new BasicParameter("RATE", 0.5);
  BasicParameter sizeParameter = new BasicParameter("SIZE", 0.5);


  public SpaceTime(GLucose glucose) {
    super(glucose);
    
    addModulator(pos).trigger();
    addModulator(rate).trigger();
    addModulator(falloff).trigger();    
    pos.modulateDurationBy(rate);
    addParameter(rateParameter);
    addParameter(sizeParameter);
  }

  public void onParameterChanged(LXParameter parameter) {
    if (parameter == rateParameter) {
      rate.stop().setValue(9000 - 8000*parameter.getValuef());
    }  else if (parameter == sizeParameter) {
      falloff.stop().setValue(70 - 60*parameter.getValuef());
    }
  }

  void run(double deltaMs) {    
    angle += deltaMs * 0.0007;
    float sVal1 = model.strips.size() * (0.5 + 0.5*sin(angle));
    float sVal2 = model.strips.size() * (0.5 + 0.5*cos(angle));

    float pVal = pos.getValuef();
    float fVal = falloff.getValuef();

    int s = 0;
    for (Strip strip : model.strips) {
      int i = 0;
      for (Point p : strip.points) {
        colors[p.index] = color(
          (lx.getBaseHuef() + 360 - p.fx*.2 + p.fy * .3) % 360, 
          constrain(.4 * min(abs(s - sVal1), abs(s - sVal2)), 20, 100),
          max(0, 100 - fVal*abs(i - pVal*(strip.metrics.numPoints - 1)))
        );
        ++i;
      }
      ++s;
    }
  }
}

class Swarm extends SCPattern {

  SawLFO offset = new SawLFO(0, 1, 1000);
  SinLFO rate = new SinLFO(350, 1200, 63000);
  SinLFO falloff = new SinLFO(15, 50, 17000);
  SinLFO fX = new SinLFO(0, model.xMax, 19000);
  SinLFO fY = new SinLFO(0, model.yMax, 11000);
  SinLFO hOffX = new SinLFO(0, model.xMax, 13000);

  public Swarm(GLucose glucose) {
    super(glucose);
    
    addModulator(offset).trigger();
    addModulator(rate).trigger();
    addModulator(falloff).trigger();
    addModulator(fX).trigger();
    addModulator(fY).trigger();
    addModulator(hOffX).trigger();
    offset.modulateDurationBy(rate);
  }

  float modDist(float v1, float v2, float mod) {
    v1 = v1 % mod;
    v2 = v2 % mod;
    if (v2 > v1) {
      return min(v2-v1, v1+mod-v2);
    } 
    else {
      return min(v1-v2, v2+mod-v1);
    }
  }

  void run(double deltaMs) {
    float s = 0;
    for (Strip strip : model.strips  ) {
      int i = 0;
      for (Point p : strip.points) {
        float fV = max(-1, 1 - dist(p.fx/2., p.fy, fX.getValuef()/2., fY.getValuef()) / 64.);
        colors[p.index] = color(
        (lx.getBaseHuef() + 0.3 * abs(p.fx - hOffX.getValuef())) % 360, 
        constrain(80 + 40 * fV, 0, 100), 
        constrain(100 - (30 - fV * falloff.getValuef()) * modDist(i + (s*63)%61, offset.getValuef() * strip.metrics.numPoints, strip.metrics.numPoints), 0, 100)
          );
        ++i;
      }
      ++s;
    }
  }
}

class SwipeTransition extends SCTransition {
  
  final BasicParameter bleed = new BasicParameter("WIDTH", 0.5);
  
  SwipeTransition(GLucose glucose) {
    super(glucose);
    setDuration(5000);
    addParameter(bleed);
  }

  void computeBlend(int[] c1, int[] c2, double progress) {
    float bleedf = 10 + bleed.getValuef() * 200.;
    float xPos = (float) (-bleedf + progress * (model.xMax + bleedf));
    for (Point p : model.points) {
      float d = (p.fx - xPos) / bleedf;
      if (d < 0) {
        colors[p.index] = c2[p.index];
      } else if (d > 1) {
        colors[p.index] = c1[p.index];
      } else {
        colors[p.index] = lerpColor(c2[p.index], c1[p.index], d, RGB);
      }
    }
  }
}

abstract class BlendTransition extends SCTransition {
  
  final int blendType;
  
  BlendTransition(GLucose glucose, int blendType) {
    super(glucose);
    this.blendType = blendType;
  }

  void computeBlend(int[] c1, int[] c2, double progress) {
    if (progress < 0.5) {
      for (int i = 0; i < c1.length; ++i) {
        colors[i] = lerpColor(
          c1[i],
          blendColor(c1[i], c2[i], blendType),
          (float) (2.*progress),
          RGB);
      }
    } else {
      for (int i = 0; i < c1.length; ++i) {
        colors[i] = lerpColor(
          c2[i],
          blendColor(c1[i], c2[i], blendType),
          (float) (2.*(1. - progress)),
          RGB);
      }
    }
  }
}

class MultiplyTransition extends BlendTransition {
  MultiplyTransition(GLucose glucose) {
    super(glucose, MULTIPLY);
  }
}

class ScreenTransition extends BlendTransition {
  ScreenTransition(GLucose glucose) {
    super(glucose, SCREEN);
  }
}

class BurnTransition extends BlendTransition {
  BurnTransition(GLucose glucose) {
    super(glucose, BURN);
  }
}

class DodgeTransition extends BlendTransition {
  DodgeTransition(GLucose glucose) {
    super(glucose, DODGE);
  }
}

class OverlayTransition extends BlendTransition {
  OverlayTransition(GLucose glucose) {
    super(glucose, OVERLAY);
  }
}

class AddTransition extends BlendTransition {
  AddTransition(GLucose glucose) {
    super(glucose, ADD);
  }
}

class SubtractTransition extends BlendTransition {
  SubtractTransition(GLucose glucose) {
    super(glucose, SUBTRACT);
  }
}

class SoftLightTransition extends BlendTransition {
  SoftLightTransition(GLucose glucose) {
    super(glucose, SOFT_LIGHT);
  }
}

class BassPod extends SCPattern {

  private GraphicEQ eq = null;
  
  public BassPod(GLucose glucose) {
    super(glucose);
  }
  
  protected void onActive() {
    if (eq == null) {
      eq = new GraphicEQ(lx, 16);
      eq.slope.setValue(0.6);
      addParameter(eq.level);
      addParameter(eq.range);
      addParameter(eq.attack);
      addParameter(eq.release);
      addParameter(eq.slope);
    }
  }

  public void run(double deltaMs) {
    eq.run(deltaMs);
    
    float bassLevel = eq.getAverageLevel(0, 5);
    
    for (Point p : model.points) {
      int avgIndex = (int) constrain(1 + abs(p.fx-model.xMax/2.)/(model.xMax/2.)*(eq.numBands-5), 0, eq.numBands-5);
      float value = 0;
      for (int i = avgIndex; i < avgIndex + 5; ++i) {
        value += eq.getLevel(i);
      }
      value /= 5.;

      float b = constrain(8 * (value*model.yMax - abs(p.fy-model.yMax/2.)), 0, 100);
      colors[p.index] = color(
        (lx.getBaseHuef() + abs(p.fy - model.cy) + abs(p.fx - model.cx)) % 360,
        constrain(bassLevel*240 - .6*dist(p.fx, p.fy, model.cx, model.cy), 0, 100),
        b
      );
    }
  }
}


class CubeEQ extends SCPattern {

  private GraphicEQ eq = null;

  private final BasicParameter edge = new BasicParameter("EDGE", 0.5);
  private final BasicParameter clr = new BasicParameter("CLR", 0.5);
  private final BasicParameter blockiness = new BasicParameter("BLK", 0.5);

  public CubeEQ(GLucose glucose) {
    super(glucose);
  }

  protected void onActive() {
    if (eq == null) {
      eq = new GraphicEQ(lx, 16);
      addParameter(eq.level);
      addParameter(eq.range);
      addParameter(eq.attack);
      addParameter(eq.release);
      addParameter(eq.slope);
      addParameter(edge);
      addParameter(clr);
      addParameter(blockiness);
    }
  }

  public void run(double deltaMs) {
    eq.run(deltaMs);

    float edgeConst = 2 + 30*edge.getValuef();
    float clrConst = 1.1 + clr.getValuef();

    for (Point p : model.points) {
      float avgIndex = constrain(2 + p.fx / model.xMax * (eq.numBands-4), 0, eq.numBands-4);
      int avgFloor = (int) avgIndex;

      float leftVal = eq.getLevel(avgFloor);
      float rightVal = eq.getLevel(avgFloor+1);
      float smoothValue = lerp(leftVal, rightVal, avgIndex-avgFloor);
      
      float chunkyValue = (
        eq.getLevel(avgFloor/4*4) +
        eq.getLevel(avgFloor/4*4 + 1) +
        eq.getLevel(avgFloor/4*4 + 2) +
        eq.getLevel(avgFloor/4*4 + 3)
      ) / 4.; 
      
      float value = lerp(smoothValue, chunkyValue, blockiness.getValuef());

      float b = constrain(edgeConst * (value*model.yMax - p.fy), 0, 100);
      colors[p.index] = color(
        (480 + lx.getBaseHuef() - min(clrConst*p.fy, 120)) % 360, 
        100, 
        b
      );
    }
  }
}

class BoomEffect extends SCEffect {

  final BasicParameter falloff = new BasicParameter("WIDTH", 0.5);
  final BasicParameter speed = new BasicParameter("SPD", 0.5);
  final BasicParameter bright = new BasicParameter("BRT", 1.0);
  final BasicParameter sat = new BasicParameter("SAT", 0.2);
  List<Layer> layers = new ArrayList<Layer>();
  final float maxr = sqrt(model.xMax*model.xMax + model.yMax*model.yMax + model.zMax*model.zMax) + 10;

  class Layer {
    LinearEnvelope boom = new LinearEnvelope(-40, 500, 1300);

    Layer() {
      addModulator(boom);
      trigger();
    }

    void trigger() {
      float falloffv = falloffv();
      boom.setRange(-100 / falloffv, maxr + 100/falloffv, 4000 - speed.getValuef() * 3300);
      boom.trigger();
    }

    void doApply(int[] colors) {
      float brightv = 100 * bright.getValuef();
      float falloffv = falloffv();
      float satv = sat.getValuef() * 100;
      float huev = lx.getBaseHuef();
      for (Point p : model.points) {
        colors[p.index] = blendColor(
        colors[p.index], 
        color(huev, satv, constrain(brightv - falloffv*abs(boom.getValuef() - dist(p.fx, 2*p.fy, 3*p.fz, model.xMax/2, model.yMax, model.zMax*1.5)), 0, 100)), 
        ADD);
      }
    }
  }

  BoomEffect(GLucose glucose) {
    super(glucose, true);
    addParameter(falloff);
    addParameter(speed);
    addParameter(bright);
    addParameter(sat);
  }

  public void onEnable() {
    for (Layer l : layers) {
      if (!l.boom.isRunning()) {
        l.trigger();
        return;
      }
    }
    layers.add(new Layer());
  }

  private float falloffv() {
    return 20 - 19 * falloff.getValuef();
  }

  public void onTrigger() {
    onEnable();
  }

  public void doApply(int[] colors) {
    for (Layer l : layers) {
      if (l.boom.isRunning()) {
        l.doApply(colors);
      }
    }
  }
}

public class PianoKeyPattern extends SCPattern {
  
  final LinearEnvelope[] cubeBrt;
  final SinLFO base[];  
  final BasicParameter attack = new BasicParameter("ATK", 0.1);
  final BasicParameter release = new BasicParameter("REL", 0.5);
  final BasicParameter level = new BasicParameter("AMB", 0.6);
  
  PianoKeyPattern(GLucose glucose) {
    super(glucose);
        
    addParameter(attack);
    addParameter(release);
    addParameter(level);
    cubeBrt = new LinearEnvelope[model.cubes.size() / 4];
    for (int i = 0; i < cubeBrt.length; ++i) {
      addModulator(cubeBrt[i] = new LinearEnvelope(0, 0, 100));
    }
    base = new SinLFO[model.cubes.size() / 12];
    for (int i = 0; i < base.length; ++i) {
      addModulator(base[i] = new SinLFO(0, 1, 7000 + 1000*i)).trigger();
    }
  }
  
  private float getAttackTime() {
    return 15 + attack.getValuef()*attack.getValuef() * 2000;
  }
  
  private float getReleaseTime() {
    return 15 + release.getValuef() * 3000;
  }
  
  private LinearEnvelope getEnvelope(int index) {
    return cubeBrt[index % cubeBrt.length];
  }
  
  private SinLFO getBase(int index) {
    return base[index % base.length];
  }
    
  public boolean noteOnReceived(Note note) {
    LinearEnvelope env = getEnvelope(note.getPitch());
    env.setEndVal(min(1, env.getValuef() + (note.getVelocity() / 127.)), getAttackTime()).start();
    return true;
  }
  
  public boolean noteOffReceived(Note note) {
    getEnvelope(note.getPitch()).setEndVal(0, getReleaseTime()).start();
    return true;
  }
  
  public void run(double deltaMs) {
    int i = 0;
    float huef = lx.getBaseHuef();
    float levelf = level.getValuef();
    for (Cube c : model.cubes) {
      float v = max(getBase(i).getValuef() * levelf/4., getEnvelope(i++).getValuef());
      setColor(c, color(
        (huef + 20*v + abs(c.cx-model.xMax/2.)*.3 + c.cy) % 360,
        min(100, 120*v),
        100*v
      ));
    }
  }
}

class CrossSections extends SCPattern {
  
  final SinLFO x = new SinLFO(0, model.xMax, 5000);
  final SinLFO y = new SinLFO(0, model.yMax, 6000);
  final SinLFO z = new SinLFO(0, model.zMax, 7000);
  
  final BasicParameter xw = new BasicParameter("XWID", 0.3);
  final BasicParameter yw = new BasicParameter("YWID", 0.3);
  final BasicParameter zw = new BasicParameter("ZWID", 0.3);  
  final BasicParameter xr = new BasicParameter("XRAT", 0.7);
  final BasicParameter yr = new BasicParameter("YRAT", 0.6);
  final BasicParameter zr = new BasicParameter("ZRAT", 0.5);
  final BasicParameter xl = new BasicParameter("XLEV", 1);
  final BasicParameter yl = new BasicParameter("YLEV", 1);
  final BasicParameter zl = new BasicParameter("ZLEV", 0.5);

  
  CrossSections(GLucose glucose) {
    super(glucose);
    addModulator(x).trigger();
    addModulator(y).trigger();
    addModulator(z).trigger();
    addParams();
  }
  
  protected void addParams() {
    addParameter(xr);
    addParameter(yr);
    addParameter(zr);    
    addParameter(xw);
    addParameter(xl);
    addParameter(yl);
    addParameter(zl);
    addParameter(yw);    
    addParameter(zw);
  }
  
  void onParameterChanged(LXParameter p) {
    if (p == xr) {
      x.setDuration(10000 - 8800*p.getValuef());
    } else if (p == yr) {
      y.setDuration(10000 - 9000*p.getValuef());
    } else if (p == zr) {
      z.setDuration(10000 - 9000*p.getValuef());
    }
  }
  
  float xv, yv, zv;
  
  protected void updateXYZVals() {
    xv = x.getValuef();
    yv = y.getValuef();
    zv = z.getValuef();    
  }

  public void run(double deltaMs) {
    updateXYZVals();
    
    float xlv = 100*xl.getValuef();
    float ylv = 100*yl.getValuef();
    float zlv = 100*zl.getValuef();
    
    float xwv = 100. / (10 + 40*xw.getValuef());
    float ywv = 100. / (10 + 40*yw.getValuef());
    float zwv = 100. / (10 + 40*zw.getValuef());
    
    for (Point p : model.points) {
      color c = 0;
      c = blendColor(c, color(
      (lx.getBaseHuef() + p.fx/10 + p.fy/3) % 360, 
      constrain(140 - 1.1*abs(p.fx - model.xMax/2.), 0, 100), 
      max(0, xlv - xwv*abs(p.fx - xv))
        ), ADD);
      c = blendColor(c, color(
      (lx.getBaseHuef() + 80 + p.fy/10) % 360, 
      constrain(140 - 2.2*abs(p.fy - model.yMax/2.), 0, 100), 
      max(0, ylv - ywv*abs(p.fy - yv))
        ), ADD); 
      c = blendColor(c, color(
      (lx.getBaseHuef() + 160 + p.fz / 10 + p.fy/2) % 360, 
      constrain(140 - 2.2*abs(p.fz - model.zMax/2.), 0, 100), 
      max(0, zlv - zwv*abs(p.fz - zv))
        ), ADD); 
      colors[p.index] = c;
    }
  }
}

class Blinders extends SCPattern {
    
  final SinLFO[] m;
  final TriangleLFO r;
  final SinLFO s;
  final TriangleLFO hs;

  public Blinders(GLucose glucose) {
    super(glucose);
    m = new SinLFO[12];
    for (int i = 0; i < m.length; ++i) {  
      addModulator(m[i] = new SinLFO(0.5, 120, (120000. / (3+i)))).trigger();
    }
    addModulator(r = new TriangleLFO(9000, 15000, 29000)).trigger();
    addModulator(s = new SinLFO(-20, 275, 11000)).trigger();
    addModulator(hs = new TriangleLFO(0.1, 0.5, 15000)).trigger();
    s.modulateDurationBy(r);
  }

  public void run(double deltaMs) {
    float hv = lx.getBaseHuef();
    int si = 0;
    for (Strip strip : model.strips) {
      int i = 0;
      float mv = m[si % m.length].getValuef();
      for (Point p : strip.points) {
        colors[p.index] = color(
          (hv + p.fz + p.fy*hs.getValuef()) % 360, 
          min(100, abs(p.fx - s.getValuef())/2.), 
          max(0, 100 - mv/2. - mv * abs(i - (strip.metrics.length-1)/2.))
        );
        ++i;
      }
      ++si;
    }
  }
}

class Psychedelia extends SCPattern {
  
  final int NUM = 3;
  SinLFO m = new SinLFO(-0.5, NUM-0.5, 9000);
  SinLFO s = new SinLFO(-20, 147, 11000);
  TriangleLFO h = new TriangleLFO(0, 240, 19000);
  SinLFO c = new SinLFO(-.2, .8, 31000);

  Psychedelia(GLucose glucose) {
    super(glucose);
    addModulator(m).trigger();
    addModulator(s).trigger();
    addModulator(h).trigger();
    addModulator(c).trigger();
  }

  void run(double deltaMs) {
    float huev = h.getValuef();
    float cv = c.getValuef();
    float sv = s.getValuef();
    float mv = m.getValuef();
    int i = 0;
    for (Strip strip : model.strips) {
      for (Point p : strip.points) {
        colors[p.index] = color(
          (huev + i*constrain(cv, 0, 2) + p.fz/2. + p.fx/4.) % 360, 
          min(100, abs(p.fy-sv)), 
          max(0, 100 - 50*abs((i%NUM) - mv))
        );
      }
      ++i;
    }
  }
}

class AskewPlanes extends SCPattern {
  
  class Plane {
    private final SinLFO a;
    private final SinLFO b;
    private final SinLFO c;
    float av = 1;
    float bv = 1;
    float cv = 1;
    float denom = 0.1;
    
    Plane(int i) {
      addModulator(a = new SinLFO(-1, 1, 4000 + 1029*i)).trigger();
      addModulator(b = new SinLFO(-1, 1, 11000 - 1104*i)).trigger();
      addModulator(c = new SinLFO(-50, 50, 4000 + 1000*i * ((i % 2 == 0) ? 1 : -1))).trigger();      
    }
    
    void run(double deltaMs) {
      av = a.getValuef();
      bv = b.getValuef();
      cv = c.getValuef();
      denom = sqrt(av*av + bv*bv);
    }
  }
    
  final Plane[] planes;
  final int NUM_PLANES = 3;
  
  AskewPlanes(GLucose glucose) {
    super(glucose);
    planes = new Plane[NUM_PLANES];
    for (int i = 0; i < planes.length; ++i) {
      planes[i] = new Plane(i);
    }
  }
  
  public void run(double deltaMs) {
    float huev = lx.getBaseHuef();
    
    // This is super fucking bizarre. But if this is a for loop, the framerate
    // tanks to like 30FPS, instead of 60. Call them manually and it works fine.
    // Doesn't make ANY sense... there must be some weird side effect going on
    // with the Processing internals perhaps?
//    for (Plane plane : planes) {
//      plane.run(deltaMs);
//    }
    planes[0].run(deltaMs);
    planes[1].run(deltaMs);
    planes[2].run(deltaMs);    
    
    for (Point p : model.points) {
      float d = MAX_FLOAT;
      for (Plane plane : planes) {
        if (plane.denom != 0) {
          d = min(d, abs(plane.av*(p.fx-model.cx) + plane.bv*(p.fy-model.cy) + plane.cv) / plane.denom);
        }
      }
      colors[p.index] = color(
        (huev + abs(p.fx-model.cx)*.3 + p.fy*.8) % 360,
        max(0, 100 - .8*abs(p.fx - model.cx)),
        constrain(140 - 10.*d, 0, 100)
      );
    }
  }
}

class ShiftingPlane extends SCPattern {

  final SinLFO a = new SinLFO(-.2, .2, 5300);
  final SinLFO b = new SinLFO(1, -1, 13300);
  final SinLFO c = new SinLFO(-1.4, 1.4, 5700);
  final SinLFO d = new SinLFO(-10, 10, 9500);

  ShiftingPlane(GLucose glucose) {
    super(glucose);
    addModulator(a).trigger();
    addModulator(b).trigger();
    addModulator(c).trigger();
    addModulator(d).trigger();    
  }
  
  public void run(double deltaMs) {
    float hv = lx.getBaseHuef();
    float av = a.getValuef();
    float bv = b.getValuef();
    float cv = c.getValuef();
    float dv = d.getValuef();    
    float denom = sqrt(av*av + bv*bv + cv*cv);
    for (Point p : model.points) {
      float d = abs(av*(p.fx-model.cx) + bv*(p.fy-model.cy) + cv*(p.fz-model.cz) + dv) / denom;
      colors[p.index] = color(
        (hv + abs(p.fx-model.cx)*.6 + abs(p.fy-model.cy)*.9 + abs(p.fz - model.cz)) % 360,
        constrain(110 - d*6, 0, 100),
        constrain(130 - 7*d, 0, 100)
      );
    }
  }
}

class Traktor extends SCPattern {

  final int FRAME_WIDTH = 60;
  
  final BasicParameter speed = new BasicParameter("SPD", 0.5);
  
  private float[] bass = new float[FRAME_WIDTH];
  private float[] treble = new float[FRAME_WIDTH];
    
  private int index = 0;
  private GraphicEQ eq = null;

  public Traktor(GLucose glucose) {
    super(glucose);
    for (int i = 0; i < FRAME_WIDTH; ++i) {
      bass[i] = 0;
      treble[i] = 0;
    }
    addParameter(speed);
  }

  public void onActive() {
    if (eq == null) {
      eq = new GraphicEQ(lx, 16);
      eq.slope.setValue(0.6);
      eq.level.setValue(0.65);
      eq.range.setValue(0.35);
      eq.release.setValue(0.4);
      addParameter(eq.level);
      addParameter(eq.range);
      addParameter(eq.attack);
      addParameter(eq.release);
      addParameter(eq.slope);
    }
  }

  int counter = 0;
  
  public void run(double deltaMs) {
    eq.run(deltaMs);
    
    int stepThresh = (int) (40 - 39*speed.getValuef());
    counter += deltaMs;
    if (counter < stepThresh) {
      return;
    }
    counter = counter % stepThresh;

    index = (index + 1) % FRAME_WIDTH;
    
    float rawBass = eq.getAverageLevel(0, 4);
    float rawTreble = eq.getAverageLevel(eq.numBands-7, 7);
    
    bass[index] = rawBass * rawBass * rawBass * rawBass;
    treble[index] = rawTreble * rawTreble;

    for (Point p : model.points) {
      int i = (int) constrain((model.xMax - p.x) / model.xMax * FRAME_WIDTH, 0, FRAME_WIDTH-1);
      int pos = (index + FRAME_WIDTH - i) % FRAME_WIDTH;
      
      colors[p.index] = color(
        (360 + lx.getBaseHuef() + .8*abs(p.x-model.cx)) % 360,
        100,
        constrain(9 * (bass[pos]*model.cy - abs(p.fy - model.cy)), 0, 100)
      );
      colors[p.index] = blendColor(colors[p.index], color(
        (400 + lx.getBaseHuef() + .5*abs(p.x-model.cx)) % 360,
        60,
        constrain(5 * (treble[pos]*.6*model.cy - abs(p.fy - model.cy)), 0, 100)

      ), ADD);
    }
  }
}

class ColorFuckerEffect extends SCEffect {
  
  BasicParameter hueShift = new BasicParameter("HSHFT", 0);
  BasicParameter sat = new BasicParameter("SAT", 1);  
  BasicParameter bright = new BasicParameter("BRT", 1);
  
  ColorFuckerEffect(GLucose glucose) {
    super(glucose);
    addParameter(hueShift);
    addParameter(bright);
    addParameter(sat);    
  }
  
  public void doApply(int[] colors) {
    if (!enabled) {
      return;
    }
    float bMod = bright.getValuef();
    float sMod = sat.getValuef();
    float hMod = hueShift.getValuef();
    if (bMod < 1 || sMod < 1 || hMod > 0) {    
      for (int i = 0; i < colors.length; ++i) {
        colors[i] = color(
          (hue(colors[i]) + hueShift.getValuef()*360.) % 360,
          saturation(colors[i]) * sat.getValuef(),
          brightness(colors[i]) * bright.getValuef()
        );
      }
    }
  }
}

class BlurEffect extends SCEffect {
  
  final LXParameter amount = new BasicParameter("AMT", 0);
  final int[] frame;
  final LinearEnvelope env = new LinearEnvelope(0, 1, 100);
  
  BlurEffect(GLucose glucose) {
    super(glucose);
    addParameter(amount);
    addModulator(env);
    frame = new int[lx.total];
    for (int i = 0; i < frame.length; ++i) {
      frame[i] = #000000;
    }
  }
  
  public void onEnable() {
    env.setRangeFromHereTo(1, 400).start();
    for (int i = 0; i < frame.length; ++i) {
      frame[i] = #000000;
    }
  }
  
  public void onDisable() {
    env.setRangeFromHereTo(0, 1000).start();
  }
  
  public void doApply(int[] colors) {
    float amt = env.getValuef() * amount.getValuef();
    if (amt > 0) {    
      amt = (1 - amt);
      amt = 1 - (amt*amt*amt);
      for (int i = 0; i < colors.length; ++i) {
        // frame[i] = colors[i] = blendColor(colors[i], lerpColor(#000000, frame[i], amt, RGB), SCREEN);
        frame[i] = colors[i] = lerpColor(colors[i], blendColor(colors[i], frame[i], SCREEN), amt, RGB);
      }
    }
      
  }  
}
