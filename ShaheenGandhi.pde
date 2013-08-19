import toxi.geom.Vec3D;
import toxi.geom.Matrix4x4;

class HelixPattern extends SCPattern {

  // Stores a line in point + vector form
  private class Line {
    private final PVector origin;
    private final PVector vector;

    Line(PVector pt, PVector v) {
      origin = pt;
      vector = v.get();
      vector.normalize();
    }

    PVector getPoint() {
      return origin;
    }

    PVector getVector() {
      return vector;
    }

    PVector getPointAt(final float t) {
      return PVector.add(origin, PVector.mult(vector, t));
    }

    boolean isColinear(final PVector pt) {
      PVector projected = projectPoint(pt);
      return projected.x==pt.x && projected.y==pt.y && projected.z==pt.z;
    }

    float getTValue(final PVector pt) {
      PVector subtraction = PVector.sub(pt, origin);
      return subtraction.dot(vector);
    }

    PVector projectPoint(final PVector pt) {
      return getPointAt(getTValue(pt));
    }

    PVector rotatePoint(final PVector pt, final float rads) {
      Vec3D axisVec3D = new Vec3D(vector.x, vector.y, vector.z);
      Vec3D originVec3D = new Vec3D(origin.x, origin.y, origin.z);
      Matrix4x4 mat = new Matrix4x4().identity()
        .rotateAroundAxis(axisVec3D, rads);
      Vec3D ptVec3D = new Vec3D(pt.x, pt.y, pt.z).sub(originVec3D);
      Vec3D rotatedPt = mat.applyTo(ptVec3D).add(originVec3D);
      return new PVector(rotatedPt.x, rotatedPt.y, rotatedPt.z);
    }
  }

  private class Helix {
    private final Line axis;
    private final float period; // period of coil
    private final float rotationPeriod; // animation period
    private final float radius; // radius of coil
    private final float girth; // girth of coil
    private final PVector referencePoint;
    private float phase;
    private PVector phaseNormal;

    Helix(Line axis, float period, float radius, float girth, float phase, float rotationPeriod) {
      this.axis = axis;
      this.period = period;
      this.radius = radius;
      this.girth = girth;
      this.phase = phase;
      this.rotationPeriod = rotationPeriod;

      // Generate a normal that will rotate to
      // produce the helical shape.
      PVector pt = new PVector(0, 1, 0);
      if (this.axis.isColinear(pt)) {
        pt = new PVector(0, 0, 1);
        if (this.axis.isColinear(pt)) {
          pt = new PVector(0, 1, 1);
        }
      }

      this.referencePoint = pt;

      // The normal is calculated by the cross product of the axis
      // and a random point that is not colinear with it.
      phaseNormal = axis.getVector().cross(referencePoint);
      phaseNormal.normalize();
      phaseNormal.mult(radius);
    }

    Line getAxis() {
      return axis;
    }

    void step(int deltaMs) {
      // Rotate
      if (rotationPeriod != 0) {
        this.phase = (phase + ((float)deltaMs / (float)rotationPeriod) * TWO_PI);
      }
    }

    PVector pointOnToroidalAxis(float t) {
      PVector p = axis.getPointAt(t);
      PVector middle = PVector.add(p, phaseNormal);
      return axis.rotatePoint(middle, (t / period) * TWO_PI + phase);
    }

    color colorOfPoint(final PVector p) {
      float t = axis.getTValue(p);

      // For performance reasons, cut out points that are outside of
      // the tube where the toroidal coil lives.
      if (abs(PVector.dist(p, axis.getPointAt(t)) - radius) > girth*.5f) {
        return color(0,0,0);
      }

      // Find the appropriate point for the current rotation
      // of the helix.
      PVector toroidPoint = pointOnToroidalAxis(t);

      // The rotated point represents the middle of the girth of
      // the helix.  Figure out if the current point is inside that
      // region.
      float d = PVector.dist(p, toroidPoint);

      // Soften edges by fading brightness.
      float b = constrain(100*(1 - ((d-.5*girth)/(girth*.5))), 0, 100);
      return color((lx.getBaseHuef() + (360*(phase / TWO_PI)))%360, 80, b);
    }
  }

  private final Helix h1;
  private final Helix h2;

  private final BasicParameter helix1On = new BasicParameter("H1ON", 1);
  private final BasicParameter helix2On = new BasicParameter("H2ON", 1);

  private final BasicParameter basePairsOn = new BasicParameter("BPON", 1);
  private final BasicParameter spokePeriodParam = new BasicParameter("SPPD", 0.40);
  private final BasicParameter spokePhaseParam = new BasicParameter("SPPH", 0.25);

  private static final float helixCoilPeriod = 100;
  private static final float helixCoilRadius = 45;
  private static final float helixCoilGirth = 20;
  private static final float helixCoilRotationPeriod = 10000;

  public HelixPattern(GLucose glucose) {
    super(glucose);

    addParameter(helix1On);
    addParameter(helix2On);
    addParameter(basePairsOn);
    addParameter(spokePhaseParam);
    addParameter(spokePeriodParam);

    PVector origin = new PVector(100, 50, 45);
    PVector axis = new PVector(1,0,0);

    h1 = new Helix(
      new Line(origin, axis),
      helixCoilPeriod,
      helixCoilRadius,
      helixCoilGirth,
      0,
      helixCoilRotationPeriod);
    h2 = new Helix(
      new Line(origin, axis),
      helixCoilPeriod,
      helixCoilRadius,
      helixCoilGirth,
      PI,
      helixCoilRotationPeriod);
  }

  void run(int deltaMs) {
    boolean h1on = helix1On.getValue() > 0.5;
    boolean h2on = helix2On.getValue() > 0.5;
    boolean spokesOn = (float)basePairsOn.getValue() > 0.5;
    float spokePeriod = (float)spokePeriodParam.getValue() * 100 + 1;
    float spokeGirth = 10;
    float spokePhase = (float)spokePhaseParam.getValue() * spokePeriod;
    float spokeRadius = helixCoilRadius - helixCoilGirth*.5f;

    h1.step(deltaMs);
    h2.step(deltaMs);

    for (Point p : model.points) {
      PVector pt = new PVector(p.x,p.y,p.z);
      color h1c = h1.colorOfPoint(pt);
      color h2c = h2.colorOfPoint(pt);

      // Find the closest spoke's t-value and calculate its
      // axis.  Until everything animates in the model reference
      // frame, this has to be calculated at every step because
      // the helices rotate.
      float t = h1.getAxis().getTValue(pt) + spokePhase;
      float spokeAxisTValue = floor(((t + spokePeriod/2) / spokePeriod)) * spokePeriod;
      PVector h1point = h1.pointOnToroidalAxis(spokeAxisTValue);
      PVector h2point = h2.pointOnToroidalAxis(spokeAxisTValue);
      PVector spokeVector = PVector.sub(h2point, h1point);
      spokeVector.normalize();
      Line spokeLine = new Line(h1point, spokeVector);
      float spokeLength = PVector.dist(h1point, h2point);
      // TODO(shaheen) investigate why h1.getAxis().getPointAt(spokeAxisTValue) doesn't quite
      // have the same value.
      PVector spokeCenter = PVector.add(h1point, PVector.mult(spokeVector, spokeLength/2.f));
      PVector spokeStart = PVector.add(spokeCenter, PVector.mult(spokeLine.getVector(), -spokeRadius));
      PVector spokeEnd = PVector.add(spokeCenter, PVector.mult(spokeLine.getVector(), spokeRadius));
      float spokeStartTValue = spokeLine.getTValue(spokeStart);
      float spokeEndTValue = spokeLine.getTValue(spokeEnd);
      PVector pointOnSpoke = spokeLine.projectPoint(pt);
      float projectedTValue = spokeLine.getTValue(pointOnSpoke);
      float percentage = constrain(PVector.dist(pointOnSpoke, spokeStart) / spokeLength, 0.f, 1.f);
      float b = ((PVector.dist(pt, pointOnSpoke) < spokeGirth) && (PVector.dist(pointOnSpoke, spokeCenter) < spokeRadius)) ? 100.f : 0.f;

      color spokeColor;

      if (spokeStartTValue < spokeEndTValue) {
        spokeColor = lerpColor(h1c, h2c, percentage);
      } else {
        spokeColor = lerpColor(h2c, h1c, percentage);
      }

      spokeColor = color(hue(spokeColor), 80.f, b);

      if (!h1on) {
        h1c = color(0,0,0);
      }

      if (!h2on) {
        h2c = color(0,0,0);
      }

      if (!spokesOn) {
        spokeColor = color(0,0,0);
      }

      // The helices are positioned to not overlap.  If that changes,
      // a better blending formula is probably needed.
      colors[p.index] = blendColor(blendColor(h1c, h2c, ADD), spokeColor, ADD);
    }
  }
}
