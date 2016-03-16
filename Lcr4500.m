classdef Lcr4500 < handle
    
    properties (Constant)
        NATIVE_RESOLUTION = [912, 1140];
        MIN_PATTERN_BIT_DEPTH = 1
        MAX_PATTERN_BIT_DEPTH = 8
    end
    
    properties (Constant, Access = private)
        LED_NAMES  = {'none', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white'};
        LED_VALUES = {   0  ,   1  ,    2   ,     3   ,    4  ,     5    ,   6   ,    7   };
        MIN_EXPOSURE_PERIODS = [235, 700, 1570, 1700, 2000, 2500, 4500, 8333] % increasing bit depth order, us
        NUM_BIT_PLANES = 24
    end
    
    properties (Access = private)
        LEDS;
    end
    
    methods
        
        function obj = Lcr4500()
            obj.LEDS = containers.Map(obj.LED_NAMES,obj.LED_VALUES);
        end
        
        function delete(obj)
            obj.disconnect();
        end
        
        function connect(obj) %#ok<MANU>
            nRetry = 5;
            for i = 1:nRetry
                try
                    lcrOpen();
                    break;
                catch x
                    lcrClose();
                    if i == nRetry
                        rethrow(x);
                    end
                end
            end
        end
        
        function disconnect(obj) %#ok<MANU>
            lcrClose();
        end
        
        function status = getStatus(obj)
            [hwstat,sysstat,mainstat] = lcrGetStatus();
            status.InternalInitializationError = ~bitget(hwstat,1);
            status.DMDResetControllerError = bitget(hwstat,2);
            status.ForcedSwapError = bitget(hwstat,3);
            status.SequencerAbort = bitget(hwstat,7);
            status.SequencerError = bitget(hwstat,8);
            
            status.InternalMemoryTestError = ~bitget(sysstat,1);
            
            status.DMDParked = bitget(mainstat,1);
            status.SequencerRunning = bitget(mainstat,2);
            status.FrameBufferFrozen = bitget(mainstat,3);
            status.GammaCorrectionEnabled = bitget(mainstat,4);
        end
                
        function status = getVideoStatus(obj)
            status = lcrGetVideoStatus();
            status.horizontalFrequency = status.horizontalFrequency*1000;
            status.verticalFrequency = status.verticalFrequency/100;
            status.pixelClock = status.pixelClock*1000;
        end
        
        function mode = getMode(obj) %#ok<MANU>
            m = LcrMode(lcrGetMode());
            if m
                mode = 'pattern';
            else
                mode = 'video';
            end
        end
        
        function setMode(obj, mode) %#ok<INUSL>
            if strcmpi(mode, 'video')
                m = false;
            elseif strcmpi(mode, 'pattern')
                m = true;
            else
                error('Mode must be ''video'' or ''pattern''');
            end
            lcrSetMode(logical(m));
            for i = 1:10
                pause(0.5);
                currentMode = obj.getMode();
                if strcmpi(currentMode,mode)
                    break
                end
            end
            if ~strcmpi(currentMode,mode)
                error(['Failed to set mode to ' mode]);
            end
        end
        
        function [auto, red, green, blue] = getLedEnables(obj) %#ok<MANU>
            [auto, red, green, blue] = lcrGetLedEnables();
        end
        
        function setLedEnables(obj, auto, red, green, blue) %#ok<INUSL>
            lcrSetLedEnables(auto, red, green, blue);
        end
        
        function [red, green, blue] = getLedCurrents(obj) %#ok<MANU>
            [red, green, blue] = lcrGetLedCurrents();
            red = 255 - red;
            green = 255 - green;
            blue = 255 - blue;
        end
        
        function setLedCurrents(obj, red, green, blue) %#ok<INUSL>
            if red < 0 || red > 255 || green < 0 || green > 255 || blue < 0 || blue > 255
                error('Current must be between 0 and 255');
            end
            
            lcrSetLedCurrents(255 - red, 255 - green, 255 - blue);
        end
        
        function setImageOrientation(obj, northSouthFlipped, eastWestFlipped) %#ok<INUSL>
            lcrSetShortAxisImageFlip(northSouthFlipped);
            lcrSetLongAxisImageFlip(eastWestFlipped);
        end
        
        function r = currentPatternRate(obj)
            [~, ~, numPatterns] = obj.getPatternAttributes();
            videoStatus = obj.getVideoStatus();
            verticalFrequency = videoStatus.verticalFrequency;
            r = numPatterns * verticalFrequency;
        end
        
        function n = maxNumPatternsForBitDepth(obj, bitDepth)
            videoStatus = obj.getVideoStatus();
            verticalFrequency = videoStatus.verticalFrequency;
            n = floor(min(obj.NUM_BIT_PLANES / bitDepth, 1/verticalFrequency/(obj.MIN_EXPOSURE_PERIODS(bitDepth) * 1e-6)));
        end
        
        function setPatternAttributes(obj, bitDepth, color, numPatterns)
            maxNumPatterns = obj.maxNumPatternsForBitDepth(bitDepth);
            
            if nargin < 4 || isempty(numPatterns)
                numPatterns = maxNumPatterns;
            end
            
            if numPatterns > maxNumPatterns
                error(['The number of patterns must be less than or equal to ' num2str(maxNumPatterns)]);
            end
            
            if obj.getMode() ~= LcrMode.PATTERN
                error('Must be in pattern mode to set pattern attributes');
            end
            
            if bitDepth < obj.MIN_PATTERN_BIT_DEPTH || bitDepth > obj.MAX_PATTERN_BIT_DEPTH
                error(['Bit depth must be between ' num2str(obj.MIN_PATTERN_BIT_DEPTH) ' and ' num2str(obj.MAX_PATTERN_BIT_DEPTH)]);
            end
            
            if strncmpi(color,'full',length(color))
                if mod(numPatterns,3)
                    error(['Number of patterns (' num2str(numPatterns)...
                           ') is not divisible by 3. Full color display not possible.']);
                end
                ledSelect = [obj.LEDS('green') obj.LEDS('red') obj.LEDS('blue')];
                ledSelect = repmat(ledSelect,[1 numPatterns/3]);
            else
                ledSelect = repmat(obj.LEDS(color),[1 numPatterns]);
            end
            
            % Stop the current pattern sequence.
            lcrPatternDisplay(0);
            
            % Clear locally stored pattern LUT.
            lcrClearPatLut();
            
            % Create new pattern LUT.
            for i = 1:numPatterns
                if i == 1
                    trigType = 1; % external positive
                    bufSwap = true;
                else
                    trigType = 3; % no trigger
                    bufSwap = false;
                end
                
                patNum = i - 1;
                invertPat = false;
                insertBlack = false;
                trigOutPrev = false;
                
                lcrAddToPatLut(trigType, patNum, bitDepth, ledSelect(i), invertPat, insertBlack, bufSwap, trigOutPrev);
            end
            
            % Set pattern display data to stream through 24-bit RGB external interface.
            lcrSetPatternDisplayMode(true);
            
            % Set the sequence to repeat.
            lcrSetPatternConfig(numPatterns, true, numPatterns, 0);
            
            % Calculate and set the necessary pattern exposure period.
            videoStatus = obj.getVideoStatus();
            verticalFrequency = videoStatus.verticalFrequency;
            vsyncPeriod = 1 / verticalFrequency* 1e6; % us
            exposurePeriod = vsyncPeriod / numPatterns;
            lcrSetExposureFramePeriod(exposurePeriod, exposurePeriod);
            
            % Set the pattern sequence to trigger on vsync.
            lcrSetPatternTriggerMode(false);
            
            % Send pattern LUT to device.
            lcrSendPatLut();
            
            % Validate the pattern LUT.
            status = lcrValidatePatLutData();
            if status == 1 || status == 3
                error('Error validating pattern sequence');
            end
            
            pause(0.05);
            % Start the pattern sequence.
            lcrPatternDisplay(2);
        end
        
        function [bitDepth, colors, numPatterns] = getPatternAttributes(obj)
            if obj.getMode() ~= LcrMode.PATTERN
                error('Must be in pattern mode to get pattern attributes');
            end
            
            % Check all patterns for a consistent bit depth and color.
            numPatterns = lcrGetPatternConfig();
            for i = 1:numPatterns
                [~, ~, bitDepth(i), ledSelect] = lcrGetPatLutItem(i - 1);
                % LED selection to color.
                colors{i} = obj.LED_NAMES{ledSelect + 1};
            end
        end
        
        function standby(obj)
            for i = 1:5
                lcrSetMode(logical(LcrMode.PATTERN));
                pause(0.1)
                lcrPatternDisplay(0);
                pause(0.1);
                obj.setLedEnables(0,0,0,0);
                pause(0.1);
                lcrSetPowerMode(1);
                pause(0.1);
                status = obj.getStatus();
                if status.DMDParked
                    break
                end
            end
            if ~status.DMDParked
                error('Error setting Lightcrafter to standby');
            end
        end
        
        function wakeup(obj)
            for i = 1:50
                lcrSetPowerMode(0);
                pause(0.1);
                lcrSetMode(logical(LcrMode.VIDEO));
                pause(0.1);
                try
                    status = obj.getStatus();
                    obj.getMode();
                catch
                    status.DMDParked = 1;
                    status.InternalInitializationError = 0;
                    status.SequencerRunning = 0;
                end
                if ~status.DMDParked && status.SequencerRunning
                    break
                end
                if status.InternalInitializationError
                    lcrSetPowerMode(1);
                    break
                end
            end
            if status.DMDParked
                error('Error waking up Lightcrafter: DMD still parked');
            end
            
            if ~status.SequencerRunning
                error('Error waking up Lightcrafter: sequencer not running');
            end
            
            if status.InternalInitializationError
                error('Error waking up Lightcrafter: Initialization error');
            end
            obj.setLedEnables(1,1,1,1);
            pause(0.1);
        end
        
    end
    
end 