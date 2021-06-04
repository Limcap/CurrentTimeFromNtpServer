// import { networkInterfaces } from 'os';
// import * as OS from 'os';
import dnsTools = require("dns")
import dgram = require('dgram')
import fs = require('fs')
import util = require('util')




export async function getNtpBrTime() : Promise<Date> {
	// Os servidores NTP.BR fornecem a hora legal brasileira.
	let ntpServers = [
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
		// "time.windows.com",  // não é a hora legal brasileira
	];

	// Embaralha a lista de servidores, para não pegar sempre do mesmo.
	shuffle(ntpServers);	

	// Tenta todos os servidores em ordem, com um timout inicial de 1s. Caso nenhum
	// servidor responda nesse tempo, o timeout dobra e as tentativas
	// recomeçam até o timeout chegar a 10s ou até algum sevidor responder.
	for (let timeoutms = 1000; timeoutms < 10000; timeoutms *= 2 ) {
		for (let dns of ntpServers) {
			var ipv4 = await getIpv4fromDns(dns);
			if (ipv4 == null) continue;
			console.log("Dns: "+dns);
			
			// Prepara os bytes a serem enviado para o servidor:
			// Tamanho da mensagem NTP - 16 bytes (RFC 2030)
			var ntpData = Uint8Array.from(new Array(48).fill(0));
			//Indicador de Leap (ver RFC), Versão e Modo
			ntpData[0] = 0x1B; //LI = 0 (sem warnings), VN = 3 (IPv4 apenas), Mode = 3 (modo cliente);
			
			var bytes = await sendBytesUdp(ipv4, 123, ntpData, timeoutms);
			if (bytes != null) break;
		}
		return  convertBytesToDate(bytes);
	}
}




function shuffle(items : Array<any> ) : void {
	const random = (max : number) => Math.floor(Math.random()*max);
	for (let i = items.length - 1; i > 0; i--) {
   	var n = random(i + 1);
		var temp = items[i];
		items[i] = items[n];
		items[n] = temp;
	}
}




async function getIpv4fromManyDns( manyDns : string[] ) {
	for (let dns of manyDns) {
		var ipv4 = await getIpv4fromDns(dns);
		if (ipv4 != null) {
			console.log("Dns: "+dns);
			break;
		} 
	}
	return ipv4;
}




async function getIpv4fromDns( dns: string ) : Promise<string> {
	let addresses = await new Promise<string[]>((resolve,reject) => {
		dnsTools.resolve4(dns, (_err, arr:string[]) => resolve(arr) );
	});
	for (let index = addresses.length - 1; index >= 0; index--) {
		var address = addresses[index];
		let regex = new RegExp(/^(\d{1,3}\.){3}\d{1,3}$/);
		if (regex.test(address)) return address;
	}
	return null;
}




async function sendBytesUdp(destIp:string, destPort:number, dataToSend:Uint8Array, timeoutms:number) : Promise<Uint8Array> {
	const socket = dgram.createSocket('udp4');
	socket.on('listening', () => socket.send(dataToSend,destPort,destIp));
	
	let bind = new Promise((rs,rj)=>socket.bind(0,"0.0.0.0",()=>rs(true)));
	let isBinded = await Promise.race([bind,timeout(timeoutms,false)])
	if (!isBinded) return null;

	let request = new Promise<Uint8Array>((rs,rj)=>socket.on('message',(msg:Buffer)=>rs(msg)));
	let response = await Promise.race<Promise<Uint8Array>>([request,timeout(timeoutms,null)])
	socket.close();
	return response;

	function timeout<T>( milliseconds : number, value : T) {
		return new Promise<T>((rs,rj) => {
			let wait = setTimeout(() => {clearTimeout(wait); rs(value);}, milliseconds)
		})
	}
}




function convertBytesToDate( data:Uint8Array ) : Date {
	let segundosBytes = Uint8Array.from(data.slice(40))
	let segundos = new DataView(segundosBytes.buffer, 0).getUint32(0, false)
	let fracaoBytes = Uint8Array.from(data.slice(44));
	let fracao = new DataView(fracaoBytes.buffer, 0).getUint32(0, false)
	let milliseconds = Math.round((segundos * 1000) + ((fracao * 1000) / 0x100000000 ))
	return new Date(milliseconds);
}