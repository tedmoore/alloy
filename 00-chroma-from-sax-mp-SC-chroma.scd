(
// bari
var source_folder = "/Users/macprocomputer/Documents/_CREATING/_PROJECT_FILES/alloy/bari-sax/audio/";

// alto
// var source_folder = "/Users/macprocomputer/Documents/_CREATING/_PROJECT_FILES/alloy/audio/quiet_alto/";

// tenor
// var source_folder = "/Users/macprocomputer/Documents/_CREATING/_PROJECT_FILES/alloy/tenor-sax/_bounces/230324_132204/";

var dest_folder = thisProcess.nowExecutingPath.dirname+/+"outputs/%_tenor_data".format(Date.localtime.stamp);

s.options.device_("Fireface UC Mac (24006457)");
s.options.sampleRate_(44100);
s.options.numBuffers_(2048);
s.options.memSize_(8192*2);
Window.closeAll;
s.waitForBoot{
	var logfreq = 20;
	var fftsize = 2048;
	var buffers = Dictionary.new;
	var ds = FluidDataSet(s);
	var xbuf = Buffer.alloc(s,12);
	var cond = Condition.new;
	var log_file, total_remaining;
	var statsbufs, flatbufs;

	Buffer.freeAll;

	s.sync;

	PathName(source_folder).files.collect({
		arg pn;
		if(pn.extension == "wav",{
			buffers[pn.fileNameWithoutExtension] = Buffer.read(s,pn.fullPath).normalize;
		});
	});

	s.sync;

	total_remaining = buffers.size;

	statsbufs = {Buffer(s)} ! buffers.size;
	flatbufs = {Buffer(s)} ! buffers.size;

	s.sync;

	buffers.keysValuesDo{
		arg name, buf, i;
		fork{
			var bufsize = ((buf.duration * logfreq) + 1).floor.asInteger;
			var chromabuf = Buffer.alloc(s,bufsize,12);
			var ampbuf = Buffer.alloc(s,bufsize);
			var statsbuf = statsbufs[i];
			var flatbuf = flatbufs[i];

			s.sync;
			{
				arg buf, fftsize, logfreq, chromabuf, ampbuf;
				var amp, trig;
				var sig = PlayBuf.ar(1,buf,BufRateScale.ir(buf),doneAction:2);
				var sig_mono = Mix(sig);
				var chroma = "analysis-func.scd".loadRelative[0].(sig_mono,fftsize);
				amp = Amplitude.kr(sig_mono);
				trig = Impulse.kr(logfreq);
				Logger.kr(chroma,trig,chromabuf);
				Logger.kr(amp,trig,ampbuf);
			}.play(args:[
				\buf,buf,
				\fftsize,fftsize,
				\logfreq,logfreq,
				\chromabuf,chromabuf,
				\ampbuf,ampbuf
			]);

			(buf.duration + 0.1).wait;

			FluidBufStats.process(s,chromabuf,select:[\mean],stats:statsbuf,weights:ampbuf).wait;
			FluidBufFlatten.process(s,statsbuf,destination:flatbuf).wait;

			statsbuf.free;
			chromabuf.free;
			ampbuf.free;

			"i: %\tid: %".format(i,name).postln;

			ds.addPoint(name,flatbuf,{

				total_remaining = total_remaining - 1;

				"% remaining".format(total_remaining).postln;

				if(total_remaining == 0){
					dest_folder.mkdir;

					log_file = File(dest_folder+/+"log.txt","w");
					log_file.write(source_folder);
					log_file.close;

					ds.write(dest_folder+/+"chroma.json");

					"done done done".postln;
				};
			});
		}
	};
}
)