(
var data_folder = "/Volumes/2110-Seagate-8TB/Project-Files/alloy/supercollider/outputs/230324_132626_tenor_data/";

var out_folder = thisProcess.nowExecutingPath.dirname;

s.options.sampleRate_(44100);
Window.closeAll;
s.waitForBoot{
	var ds = FluidDataSet(s);
	var nDims = 2;
	var umap = FluidUMAP(s,nDims,15,0.5);
	var bufs = Dictionary.new;
	var plot2d, save1d, previous = nil;

	var audio_folder = File.readAllString(data_folder+/+"log.txt");

	audio_folder.postln;

	Buffer.freeAll;
	s.sync;

	PathName(audio_folder).filesDo({
		arg pn;
		// pn.postln;
		if(pn.extension == "wav"){
			bufs[pn.fileNameWithoutExtension] = Buffer.read(s,pn.fullPath);
		}
	});

	plot2d = {
		arg ds_;
		var xybuf = Buffer.alloc(s,2);
		var normer = FluidNormalize(s).fitTransform(ds_,ds_);
		var tree = FluidKDTree(s).fit(ds_);

		ds_.print;

		ds_.dump{
			arg dict;
			defer{
				FluidPlotter(dict:dict,mouseMoveAction:{
					arg view, x, y;
					xybuf.setn(0,[x,y]);
					tree.kNearest(xybuf,1,{
						arg id;
						if(id != previous){
							id.postln;
							bufs[id.asString].play;
							previous = id;
						};
					});
				});
			}
		};
	};

	save1d = {
		arg ds_;
		ds_.dump({
			arg dict;
			var order = Array.newClear(dict.at("data").size);
			var proj = ReaProj();
			var track = ReaTrack();
			var start = 0;
			var path = out_folder+/+"%_1d.RPP".format(Date.localtime.stamp);

			dict.at("data").keysValuesDo({
				arg key, val, i;
				order[i] = [val[0],key];
			});
			// order.postln;
			order.sort({arg a, b; a[0] < b[0]});
			// order.postln;

			order.do({
				arg arr;
				var key = arr[1].postln;
				var buffer = bufs.at(key);
				var len = buffer.duration;
				track.addItem(ReaItem(buffer.path,start,len));
				start = start + len;
			});

			proj.addTrack(track);
			// proj.write(path);
			// "open %".format(path.asUnixPath).unixCmd;
		});
	};



	s.sync;

	ds.read(data_folder+/+"chroma.json",{
		umap.fitTransform(ds,ds,{
			if(nDims == 1){
				save1d.(ds);
			}{
				plot2d.(ds);
			};
		});
	});
}
)