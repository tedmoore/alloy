{
	arg sig_mono, fftsize, maxPool = true;
	var fft = FFT(LocalBuf(fftsize),sig_mono);
	var chroma = Chromagram.kr(fft,fftsize,12,"a-1".namecps,8,perframenormalize:1);
	if(maxPool){
		chroma = MaxPooler.kr(chroma,12,0.999);
	};
	chroma;
}