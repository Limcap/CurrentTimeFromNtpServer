import 'dart:async';
import 'dart:math';
import 'dart:io';
import "dart:typed_data";


Future<DateTime> getNtpBrTime() async {
	var ntpServers = [
		"a.ntp.br",
		"b.ntp.br",
		"c.ntp.br",
		"a.st1.ntp.br",
		"b.st1.ntp.br",
		"c.st1.ntp.br",
		"d.st1.ntp.br",
		"gps.ntp.br"
	];

	// Embaralha a lista de servidores, para não pegar sempre do mesmo.
	shuffle(ntpServers);

	// Processa a lista servidores para obter o endereço IP.
	// Em caso de falha tentará novamente por até 20 vezes.
	InternetAddress ipv4;
	for (var i = 0; i < 20; i++) {
		ipv4 = await getIpv4fromManyDns(ntpServers);
		if (ipv4 != null) break;
	}

	// Prepara os bytes a serem enviado para o servidor:
	// Tamanho da mensagem NTP - 16 bytes (RFC 2030)
	var ntpData = Uint8List.fromList(List.filled(48, 0));
	//Indicador de Leap (ver RFC), Versão e Modo
	ntpData[0] = 0x1B; //LI = 0 (sem warnings), VN = 3 (IPv4 apenas), Mode = 3 (modo cliente);

	var bytes = await sendBytesUDP(ipv4, 123, ntpData);
	return convertBytesToDate(bytes);
}




List shuffle(List items) {
	var random = new Random();
	for (var i = items.length - 1; i > 0; i--) {
   	var n = random.nextInt(i + 1);
		var temp = items[i];
		items[i] = items[n];
		items[n] = temp;
	}
	return items;
}




Future<InternetAddress> getIpv4fromManyDns( List<String> manyDns ) async {
	for (String dns in manyDns) {
		var ipv4 = await getIpv4fromDns(dns);
		// Se não achou um IPV4 nesse servidor, passa pro próximo
		if (ipv4 != null) return ipv4;
	}
	return null;
}




Future<InternetAddress> getIpv4fromDns( String dns ) async {
	List<InternetAddress> addresses = await InternetAddress.lookup(dns);
	for (var index = addresses.length - 1; index >= 0; index--) {
		var addressItem = addresses[index];
		var addressString = addressItem.address;
		RegExp regex = RegExp(r"^(\d{1,3}\.){3}\d{1,3}$");
		if (regex.hasMatch(addressString))
			return addressItem;
	}
	return null;
}




Future<Uint8List> sendBytesUDP(InternetAddress destIp, int destPort, Uint8List dataToSend) async {
	// var codec = new Utf8Codec();
	// List<int> dataToSend = codec.encode(data);
	print("Server: ${destIp.host}");
	Stopwatch stopwatch = new Stopwatch()..start();
	// IP 0.0.0.0 e Porta 0 fazem com que o soocket de saida seja escolhido automaticamente.
	RawDatagramSocket rds = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
	Uint8List response;
	var subs = rds.listen((ev) {
		if(ev == RawSocketEvent.write) {
			rds.send(dataToSend, destIp, 123);
		}
		else if(ev == RawSocketEvent.read) {
			Datagram datagram = rds.receive();
			print("Received: ${datagram.data.length} bytes");
			if(datagram != null) response = datagram.data;
			rds.close();
		}
	});
	var future = subs.asFuture<Uint8List>();
	await future;
	print('Duration: ${stopwatch.elapsedMilliseconds} ms');
	stopwatch.stop();
	return response;
}




DateTime convertBytesToDate( Uint8List data ) {
  // Converte os bytes em segundos e fração de segundos
  Uint8List segundosBytes = Uint8List.fromList(data.skip(40).toList()); //.reversed.toList()
  int segundos = ByteData.view(segundosBytes.buffer).getUint32(0, Endian.big);
  Uint8List fracaoBytes = Uint8List.fromList(data.skip(44).toList()); //.reversed.toList()
  int fracao = ByteData.view(fracaoBytes.buffer).getUint32(0, Endian.big);
  int milliseconds = ((segundos * 1000) + ((fracao * 1000) / 0x100000000 )).toInt();

	// cria o Datetime em UTC e converte para local.
	var networkDateTime = DateTime.utc( 1900, 1, 1, 0, 0, 0 );
	networkDateTime = networkDateTime.add( Duration( milliseconds: milliseconds ) );
	var localTime = networkDateTime.toLocal();
	return localTime;
}




Future delay( int ms ) async {
  var sleep = new Future.delayed(Duration(milliseconds: ms), () => 0);
  return await sleep; 
}




Uint8List int32BigEndianBytes(int value) {
	return  Uint8List(4)..buffer.asByteData().setInt32(0, value, Endian.big);
}
