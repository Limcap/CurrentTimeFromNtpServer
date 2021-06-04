import 'dart:async';
import 'dart:math';
import 'dart:io';
import "dart:typed_data";


Future<DateTime> getNtpBrTime() async {
	// Os servidores NTP.BR fornecem a hora legal brasileira.
	var ntpServers = [
		"pool.ntp.br",
		"a.ntp.br",
		"b.ntp.br",
		"c.ntp.br",
		"a.st1.ntp.br",
		"b.st1.ntp.br",
		"c.st1.ntp.br",
		"d.st1.ntp.br",
		"gps.ntp.br",
		// "ntp.cais.rnp.br", 
		// "time.windows.com", // não é a hora legal brasileira
	];

	// Embaralha a lista de servidores, para não pegar sempre do mesmo.
	shuffle(ntpServers);

	// Tenta todos os servidores em ordem, com um timout inicial de 1s. Caso nenhum
	// servidor responda nesse tempo, o timeout dobra e as tentativas
	// recomeçam até o timeout chegar a 10s ou até algum sevidor responder.
	for (var timelimit = 1000; timelimit < 10000; timelimit *= 2 ) {
		for (String dns in ntpServers) {
			var ipv4 = await getIpv4fromDns(dns);
			if (ipv4 == null) continue;
		
			// Prepara os bytes a serem enviado para o servidor:
			// Tamanho da mensagem NTP - 16 bytes (RFC 2030)
			var ntpData = Uint8List.fromList(List.filled(48, 0));
			//Indicador de Leap (ver RFC), Versão e Modo
			ntpData[0] = 0x1B; //LI = 0 (sem warnings), VN = 3 (IPv4 apenas), Mode = 3 (modo cliente);
			
			var bytes = await sendBytesUDP(ipv4, 123, ntpData, timelimit);
			if (bytes != null) return convertBytesToDate(bytes);
		}
	}
	return null;
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




Future<Uint8List> sendBytesUDP(InternetAddress destIp, int destPort, Uint8List dataToSend, int timelimit) async {
	// var codec = new Utf8Codec();
	// List<int> dataToSend = codec.encode(data);
	print("Server: ${destIp.host}");
	// IP 0.0.0.0 e Porta 0 fazem com que o soocket de saida seja escolhido automaticamente.
	RawDatagramSocket rds = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
	// rds.timeout(Duration(milliseconds:timelimit),onTimeout:(e)=>rds.close());
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
	try { await subs.asFuture<Uint8List>().timeout(Duration(milliseconds:timelimit)); }
	catch (e) { return null; }
	finally { rds.close(); }
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
