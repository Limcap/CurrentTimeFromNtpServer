import 'GetTimeFromNtp.dart' as UdpWebTime;

main() async {
	var dt = await UdpWebTime.getNtpBrTime();
	print(dt);
}
