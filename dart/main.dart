import 'GetTimeFromNtp.dart' as UdpWebTime;

main() async {
  Stopwatch stopwatch = new Stopwatch()..start();
	var dt = await UdpWebTime.getNtpBrTime();
	stopwatch.stop();
  print('Duration: ${stopwatch.elapsedMilliseconds} ms');
	print(dt);
}
