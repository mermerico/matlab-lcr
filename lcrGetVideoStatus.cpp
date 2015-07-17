#include "lcr.h"
#include <string>
#include <array>

#define NUMFIELDS 14

using namespace std;

void mexFunction(int nlhs, mxArray *plhs[], int nrhs, const mxArray *prhs[])
{
    if (nrhs > 0)
    {
        mexErrMsgIdAndTxt("lcr:usage", "Usage: [table, enable] = lcrGetGammaCorrection()");
        return;
    }
	
    unsigned char signalDetectionStatus, HSYNCPolarity, VSYNCPolarity;
	unsigned short horizontalResolution, verticalResolution, horizontalFrequency, verticalFrequency, totalPixelsPerLine, totalPixelsPerFrame, activePixelsPerLine, activePixelsPerFrame, firstPixel, firstLine;
	unsigned int pixelClock;
					
    int result = LCR_GetVideoStatus(&signalDetectionStatus, &horizontalResolution, &verticalResolution, &HSYNCPolarity, &VSYNCPolarity, &pixelClock, &horizontalFrequency, &verticalFrequency, &totalPixelsPerLine, &totalPixelsPerFrame, &activePixelsPerLine, &activePixelsPerFrame, &firstPixel, &firstLine);
    if (result < 0)
    {
        mexErrMsgIdAndTxt("lcr:failedToGetVideoStatus", "Failed to get video status");
        return;
    }
	const char *fieldnames[] = {"signalDetectionStatus", "HSYNCPolarity", "VSYNCPolarity","horizontalResolution", "verticalResolution", "horizontalFrequency", "verticalFrequency", "totalPixelsPerLine", "totalPixelsPerFrame", "activePixelsPerLine", "activePixelsPerFrame", "firstPixel", "firstLine", "pixelClock"};

	plhs[0] = mxCreateStructMatrix(1,1,NUMFIELDS,fieldnames);
	
	string detectionString;
	switch(signalDetectionStatus)
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
	mxSetFieldByNumber(plhs[0],0,1 , mxCreateDoubleScalar(HSYNCPolarity));
	mxSetFieldByNumber(plhs[0],0,2 , mxCreateDoubleScalar(VSYNCPolarity));
	mxSetFieldByNumber(plhs[0],0,3 , mxCreateDoubleScalar(horizontalResolution));
	mxSetFieldByNumber(plhs[0],0,4 , mxCreateDoubleScalar(verticalResolution));
	mxSetFieldByNumber(plhs[0],0,5 , mxCreateDoubleScalar(horizontalFrequency));
	mxSetFieldByNumber(plhs[0],0,6 , mxCreateDoubleScalar(verticalFrequency));
	mxSetFieldByNumber(plhs[0],0,7 , mxCreateDoubleScalar(totalPixelsPerLine));
	mxSetFieldByNumber(plhs[0],0,8 , mxCreateDoubleScalar(totalPixelsPerFrame));
	mxSetFieldByNumber(plhs[0],0,9 , mxCreateDoubleScalar(activePixelsPerLine));
	mxSetFieldByNumber(plhs[0],0,10, mxCreateDoubleScalar(activePixelsPerFrame));
	mxSetFieldByNumber(plhs[0],0,11, mxCreateDoubleScalar(firstPixel));
	mxSetFieldByNumber(plhs[0],0,12, mxCreateDoubleScalar(firstLine));
	mxSetFieldByNumber(plhs[0],0,13, mxCreateDoubleScalar(pixelClock));
}