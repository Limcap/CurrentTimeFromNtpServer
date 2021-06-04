import * as Ntp from "./GetTimeFromNtp";

main();

async function main() {
	console.time("duracao");
	var time = await Ntp.getNtpBrTime();
	console.log(time);
	console.timeEnd("duracao");
}
