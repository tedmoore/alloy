(
s.options.device = "Fireface UFX+ (24082112)";
s.options.numInputBusChannels = 4;
s.options.numOutputBusChannels = 4;
s.options.numWireBufs = 2048;
s.boot;
)

~src = Buffer.read(s,"/Users/ted/Documents/_PROJECT-FILES/alloy/250312-alloy-album/_renders/250508_114937/1_alloy-album_bar-recorded-separately_250508_114937.wav");

(
fork{
	n = 24;

	~reverb_bus = Bus.audio(s,2);
	~freq_bus = Bus.control(s,n);
	~amp_bus = Bus.control(s,n);

	~reverb = {
		arg mix = 0.3;
		var in = In.ar(~reverb_bus,2);
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
		SelectX.ar(mix,[in,sig]) * -6.dbamp;
	}.play;

	s.sync;

	~analysis = {
		// var in = SoundIn.ar([2,3]).sum;
		// var start = 0;
		var start = rrand(0,~src.numFrames-1);
		var in = PlayBuf.ar(2,~src,BufRateScale.ir(~src),startPos:start,loop:1) * -12.dbamp;
		var freqs, amps, sig;
		# freqs, amps = FluidSineFeature.kr(in.sum,n);
		Out.kr(~freq_bus,freqs);
		Out.kr(~amp_bus,amps);
		// nil;
		in
	}.play(~reverb,addAction:\addBefore);

	s.sync;

	inf.do{
		var fadein = rrand(6.0,12.0);
		var fadeout = rrand(6.0,12.0);
		var sustain = rrand(2.0,6.0);
		var total = fadein + sustain + fadeout;
		var waitdur = rrand(total*0.5,total*0.9);

		"".postln;
		total.postln;
		waitdur.postln;

		{
			arg freq_mul = 1;
			var freqs = In.kr(~freq_bus,n);
			var amps = In.kr(~amp_bus,n);
			var env = EnvGen.kr(Env([0,1,1,0],[fadein,sustain,fadeout]),doneAction:2);
			var sig;
			freqs = Latch.kr(freqs,1);
			amps = Latch.kr(amps,1);

			freqs = freqs * LFDNoise1.kr(0.1,0.25).midiratio * freq_mul;
			amps = amps * LFDNoise1.kr(0.1,6).dbamp * AmpCompA.kr(freqs);

			sig = SinOsc.ar(freqs,Rand(0,2pi.dup(freqs.numChannels)),amps).scramble * env * 4.dbamp;
			// sig = LFTri.ar(freqs,0,amps).scramble;
			// sig = Splay.ar(sig) * env * 18.dbamp;
			sig = sig.collect{
				arg si;
				Pan2.ar(si,Rand(-2.1,2.1).tanh);
			}.sum;
			sig;
		}.play(
			target: ~analysis,
			outbus: ~reverb_bus,
			addAction:\addAfter,
			args:[
				\freq_mul,[0.25,0.5,1,2].choose.postln
			]
		);
		waitdur.wait;
	};
}
)