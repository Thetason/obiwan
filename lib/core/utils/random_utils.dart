import 'dart:math' as math;

extension RandomGaussian on math.Random {
  double nextGaussian() {
    double u = 0, v = 0;
    while(u == 0) u = nextDouble();
    while(v == 0) v = nextDouble();
    return math.sqrt(-2.0 * math.log(u)) * math.cos(2.0 * math.pi * v);
  }
}