#include "lcr.h"
#include <string>
#include <array>

#define NUMFIELDS 14

using namespace std;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs > 0)
    {
        mexErrMsgIdAndTxt("lcr:usage", "Usage: status = lcrGetVideoStatus()");
        return;
    }				
	
	VideoSigStatus vidSigStat;
    int result = DLPC350_GetVideoSignalStatus(&vidSigStat)
    if (result < 0)
    {
        mexErrMsgIdAndTxt("lcr:failedToGetVideoStatus", "Failed to get video status");
        return;
    }
	const char *fieldnames[] = {"signalDetectionStatus", "HSYNCPolarity", "VSYNCPolarity","horizontalResolution", "verticalResolution", "horizontalFrequency", "verticalFrequency", "totalPixelsPerLine", "totalLinesPerFrame", "activePixelsPerLine", "activeLinesPerFrame", "firstPixel", "firstLine", "pixelClock"};

	plhs[0] = mxCreateStructMatrix(1,1,NUMFIELDS,fieldnames);
	
	string detectionString;
	switch(vidSigStat.Status)
	{
		case 0:
			detectionString = "Stopped";
			break;
		case 1:
			detectionString = "Processing";
			break;
		case 2:
			detectionString = "Detected";
			break;
		case 3:
			detectionString = "Lock Failed";
			break;
		default:
			detectionString = "Unknown Status";
			break;
	}
		
	mxSetFieldByNumber(plhs[0],0,0 , mxCreateString(detectionString.c_str()));
	mxSetFieldByNumber(plhs[0],0,1 , mxCreateDoubleScalar(vidSigStat.HSyncPol));
	mxSetFieldByNumber(plhs[0],0,2 , mxCreateDoubleScalar(vidSigStat.VSyncPol));
	mxSetFieldByNumber(plhs[0],0,3 , mxCreateDoubleScalar(vidSigStat.HRes));
	mxSetFieldByNumber(plhs[0],0,4 , mxCreateDoubleScalar(vidSigStat.VRes));
	mxSetFieldByNumber(plhs[0],0,5 , mxCreateDoubleScalar(vidSigStat.HFreq));
	mxSetFieldByNumber(plhs[0],0,6 , mxCreateDoubleScalar(vidSigStat.VFreq));
	mxSetFieldByNumber(plhs[0],0,7 , mxCreateDoubleScalar(vidSigStat.TotPixPerLine));
	mxSetFieldByNumber(plhs[0],0,8 , mxCreateDoubleScalar(vidSigStat.TotLinPerFrame));
	mxSetFieldByNumber(plhs[0],0,9 , mxCreateDoubleScalar(vidSigStat.ActvPixPerLine));
	mxSetFieldByNumber(plhs[0],0,10, mxCreateDoubleScalar(vidSigStat.ActvLinePerFrame));
	mxSetFieldByNumber(plhs[0],0,11, mxCreateDoubleScalar(vidSigStat.FirstActvPix));
	mxSetFieldByNumber(plhs[0],0,12, mxCreateDoubleScalar(vidSigStat.FirstActvLine));
	mxSetFieldByNumber(plhs[0],0,13, mxCreateDoubleScalar(vidSigStat.PixClock));
}