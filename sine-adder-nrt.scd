(
~render_sines = {
	arg inputFilePath, outputFilePath, n = 24;
	var reverb_bus = 2;
	var freqs_bus = 0;
	var amps_bus = n;
	var server = Server(
		// name: 'nrt',
		options: ServerOptions.new
		.numOutputBusChannels_(2)
		.numInputBusChannels_(2)
		.numWireBufs_(2048)
	);
	var inputFile = SoundFile.openRead(inputFilePath);

	thisThread.randSeed = PathName(inputFilePath).fileNameWithoutExtension.hash;

	inputFile.close;  // doesn't need to stay open; we just need the stats

	SynthDef(\analysis,{
		var in = PlayBuf.ar(2,0,BufRateScale.ir(0),loop:0) * -12.dbamp;
		var freqs, amps, sig;
		# freqs, amps = FluidSineFeature.kr(in.sum,n);
		Out.kr(freqs_bus,freqs);
		Out.kr(amps_bus,amps);
	}).store;

	SynthDef(\reverb,{
		arg mix = 0.3;
		var in = In.ar(reverb_bus,2);
		var sig;

		sig = HPF.ar(sig,50);
		sig = HPF.ar(sig,50);
		sig = HPF.ar(sig,50);

		sig = GVerb.ar(
			in: in.sum,
			roomsize: 243,
			revtime: 1,
			damping: 0.1,
			inputbw: 0.34,
			spread: 15,
			drylevel: 0,
			earlyreflevel: -11.dbamp,
			taillevel: -9.dbamp
		);
		sig = SelectX.ar(mix,[in,sig]) * -6.dbamp;
		Out.ar(0,sig);
	}).store;

	SynthDef(\swell,{
		arg freq_mul = 1, fadein, sustain, fadeout;
		var freqs = In.kr(freqs_bus,n);
		var amps = In.kr(amps_bus,n);
		var env = EnvGen.kr(Env([0,1,1,0],[fadein,sustain,fadeout]),doneAction:2);
		var sig;
		freqs = Latch.kr(freqs,1);
		amps = Latch.kr(amps,1);

		freqs = freqs * LFDNoise1.kr(0.1,0.25).midiratio * freq_mul;
		amps = amps * LFDNoise1.kr(0.1,6).dbamp * AmpCompA.kr(freqs);

		sig = SinOsc.ar(freqs,{rrand(0,2pi)} ! freqs.numChannels,amps).scramble * env * 4.dbamp;
		// sig = LFTri.ar(freqs,0,amps).scramble;
		// sig = Splay.ar(sig) * env * 18.dbamp;
		sig = sig.collect{
			arg si;
			Pan2.ar(si,rrand(-2.1,2.1).tanh);
		}.sum;
		Out.ar(reverb_bus,sig);
	}).store;

	a = Score([
		[0.0, [\b_allocRead,0,inputFile.path,0,-1]],
		[0.0, [\s_new,\reverb,  1000,0,0   ]],
		[0.0, [\s_new,\analysis,1001,2,1000]]
	]);

	t = 0;

	while{t < inputFile.duration}{
		var fadein = rrand(6.0,12.0);
		var fadeout = rrand(6.0,12.0);
		var sustain = rrand(2.0,6.0);
		var total = fadein + sustain + fadeout;
		var waitdur = rrand(total*0.5,total*0.9);
		var freq_mul = [0.25,0.5,1,2].choose;
		var cmd = [t, ['/s_new',\swell,UniqueID.next,3,1001,
			\freq_mul,freq_mul,
			\fadein,fadein,
			\sustain,sustain,
			\fadeout,fadeout
		]];

		cmd.postln;

		a.add(cmd);

		t = t + waitdur;
	};

	a.recordNRT(
		outputFilePath: outputFilePath,
		headerFormat: "wav",
		sampleFormat: "int24",
		options: server.options,
		duration: inputFile.duration + 10,
		action: { "done".postln }
	);

	server.remove;
};
)

(
SelectFiles(
	input: "/Users/ted/Documents/_PROJECT-FILES/alloy/250312-alloy-album/_renders/250508_114937/",
	selectExtensions: ['wav'],
	numChannels: [2],
	recursive: false
).do{
	arg p;
	var out = PathName(p);
	out = out.pathOnly +/+ "%_sines.wav".format(out.fileNameWithoutExtension);
	~render_sines.(p,out);
};
)