(
~dir = thisProcess.nowExecutingPath.dirname;
~images_dir = "/Users/ted/Documents/_PROJECT-FILES/alloy/bari-sax/images-individual/";
Window.closeAll;

s.options.inDevice_("Fireface UC Mac (24006457)");
s.options.outDevice_("Fireface UC Mac (24006457)");
s.options.numInputBusChannels_(4);
s.options.numOutputBusChannels_(4);
s.waitForBoot{

	//bari
	var data_folder = ~dir+/+"outputs/230524_205653_BARI_data/";

	// alto
	//var data_folder = "/Users/macprocomputer/Documents/_CREATING/_PROJECT_FILES/alloy/supercollider/outputs/221003_194950_data_alto";

	// tenor
	// var data_folder = "/Volumes/2110-Seagate-8TB/Project-Files/alloy/supercollider/outputs/230324_132626_tenor_data/";

	var transp = File.readAllString(data_folder+/+"transposition.txt").asInteger;
	var ds = FluidDataSet(s);
	var xbuf = Buffer.alloc(s,12);
	var tree = FluidKDTree(s);
	var images = Dictionary.new;
	var loudness_thresh = -75;
	var loudness_alpha = 1;
	var outfile;
	var displayImages = true;

	var render_data = false;

	~counterDict = Dictionary.new;

	if(render_data){
		outfile = ArrayToCSV.open(data_folder+/+"%-data-render.csv".format(Date.localtime.stamp));
	};

	PathName(~images_dir).filesDo{
		arg pn;
		// pn.fullPath.postln;
		images[pn.fileNameWithoutExtension] = Image(pn.fullPath);
	};

	s.sync;

	ds.read(data_folder+/+"chroma.json");
	tree.fit(ds);

	fork({
		var fftsize = 2048;
		var confidence = 0;
		var latest = nil;
		var min_conf = 30;
		var width = 766, height = 454;
		var win, update_display, pitch;
		var picture_index = 1;
		var letter = nil;
		var frame_rate = 30;

		win = Window(bounds:Rect(0,0,width*2,height*2));
		win.background_(Color.white);
		win.drawFunc_{
			var notename, centsoff;
			var notemidi;

			// base picture

			if(displayImages && images[picture_index].notNil){
				// "picture index: %".format(picture_index).postln;
				images[picture_index].drawInRect(Rect(0,0,width*2,height*2));
			};

			// letter if needed
			if(letter.notNil,{
				Pen.stringAtPoint(letter.asString.toUpper,Point(width*1.6,height*1.6),Font("Monaco",120),Color.red);
			});

			// pitch with cents
			if(pitch.notNil){
				notemidi = pitch.cpsmidi + transp;// transp for alto & bari
				notename = notemidi.midiname;
				centsoff = ((notemidi - notemidi.round) * 100).round.asInteger;
				centsoff = "%%".format(["","+"][(centsoff >= 0).asInteger],centsoff);
				Pen.stringAtPoint("%".format(notename),Point(width*1.6,height * 0.1),Font("Monaco",80),Color.red);
				Pen.stringAtPoint("cents: %".format(centsoff),Point(width*1.6,height * 0.3),Font("Monaco",40),Color.red);
			};

			// white overlay to have it fade in with confidence
			Pen.addRect(Rect(0,0,width*2,height*2));
			Pen.color_(Color.white.alpha_(confidence.linlin(min_conf,min_conf + 30,1.0,0.0)));
			Pen.fill;

			// white overlay to have it fade in with loudness
			Pen.addRect(Rect(0,0,width*2,height*2));
			Pen.color_(Color.white.alpha_(loudness_alpha));
			Pen.fill;
		};

		win.front;

		// analysis synth

		{
			var sig = SoundIn.ar(0);
			var chroma = "analysis-func.scd".loadRelative[0].(sig,fftsize,true);
			var pitch = FluidPitch.kr(sig,select:[\pitch]);
			var loudness = FluidLoudness.kr(sig,select:[\loudness]);
			var loudnessAlpha = (loudness < loudness_thresh).lag(1);
			var trig = Impulse.kr(frame_rate);
			var counter = PulseCount.kr(trig) - 1;
			FluidKrToBuf.kr(chroma,xbuf);
			SendReply.kr(trig,"/pitch-loudnessAlpha-chroma",[counter,pitch,loudnessAlpha] ++ chroma);
		}.play;

		// osc func

		OSCFunc({
			arg msg;

			tree.kNearest(xbuf,1,{
				arg nearest;
				var fingering = nearest.asString;
				var last_char = fingering.at(fingering.size-1);

				// increment confidence accordingly

				if(latest == nearest,{
					confidence = confidence + 1;
				},{
					confidence = 0;
					latest = nearest;
				});

				nearest.post;
				" ".post;
				{"*".post} ! confidence;
				"".postln;

				if(~counterDict[nearest].notNil){
					~counterDict[nearest] = ~counterDict[nearest] + confidence;
				}{
					~counterDict[nearest] = 0;
				};

				if(render_data){
					outfile.writeLine([msg[3].asInteger,msg[3]/frame_rate,nearest,confidence]);
				};

				if(displayImages){
					// strip off the letter portion if needed

					letter = nil; // reset the "letter" variable

					if(last_char.isAlpha,{ // isAlpha means "is a letter" as opposed to a number;
						letter = last_char;
						picture_index = fingering[0..(fingering.size-2)];
					},{
						picture_index = fingering;
					});
				};

				pitch = msg[4];
				loudness_alpha = msg[5];

				defer{win.refresh};
			});

		},"/pitch-loudnessAlpha-chroma");
	},AppClock);
}
)

// saving results
(
~l = List.new;
~counterDict.keysValuesDo{
	arg k, v;
	~l.add([v,k]);
};
~sorted = ~l.sort({arg a, b; a[0] > b[0]});
~sorted.dopostln;
ArrayToCSV(~sorted,"/Volumes/2110-Seagate-8TB/Project-Files/saccades/data/%-bari-sax-multiphonics-sorted-mvt4-add-confidence.csv".format(Date.localtime.stamp));
)