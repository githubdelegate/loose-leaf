#import "CaptureSessionManager.h"
#import <AssetsLibrary/AssetsLibrary.h>


@implementation CaptureSessionManager{
    AVCaptureVideoPreviewLayer *previewLayer;
    AVCaptureSession *captureSession;
    AVCaptureStillImageOutput* stillImageOutput;
    AVCaptureDevice* currDevice;
}

@synthesize captureSession;
@synthesize previewLayer;

#pragma mark Capture Session Configuration

- (id)init {
	if ((self = [super init])) {
		captureSession = [[AVCaptureSession alloc] init];
        captureSession.sessionPreset = AVCaptureSessionPresetMedium;
        
        [self addVideoInput];
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:[self captureSession]];
        [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
        
        stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
        if ([captureSession canAddOutput:stillImageOutput])
        {
            NSLog(@"adding picture file output");
            [stillImageOutput setOutputSettings:@{AVVideoCodecKey : AVVideoCodecJPEG}];
            [captureSession addOutput:stillImageOutput];
        }

	}
	return self;
}

#pragma mark - Public Interface

-(void) changeCamera{
    NSArray* currentInputs = [[self captureSession] inputs];
    AVCaptureDeviceInput* currInput = [currentInputs firstObject];
    if([currentInputs count]){
        // remove if we have one
        [[self captureSession] removeInput:currInput];
    }
    AVCaptureDevice* nextDevice = [self oppositeDeviceFrom:currDevice];
    AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:nextDevice error:nil];
    if ([[self captureSession] canAddInput:videoIn]){
        currDevice = nextDevice;
        [[self captureSession] addInput:videoIn];
    }else{
        currDevice = nil;
    }
}

-(void) addPreviewLayerTo:(CALayer*)layer{
    CGRect layerRect = [layer bounds];
	[[self previewLayer] setBounds:layerRect];
	[[self previewLayer] setPosition:CGPointMake(CGRectGetMidX(layerRect),CGRectGetMidY(layerRect))];
	[layer addSublayer:[self previewLayer]];
}

-(void) snapPicture{
//	dispatch_async([self sessionQueue], ^{
		// Update the orientation on the still image output video connection before capturing.
		[[stillImageOutput connectionWithMediaType:AVMediaTypeVideo] setVideoOrientation:[[(AVCaptureVideoPreviewLayer *)[self previewLayer] connection] videoOrientation]];
		
		// Flash set to Auto for Still Capture
		[CaptureSessionManager setFlashMode:AVCaptureFlashModeAuto forDevice:currDevice];
		
		// Capture a still image.
		[stillImageOutput captureStillImageAsynchronouslyFromConnection:[stillImageOutput connectionWithMediaType:AVMediaTypeVideo] completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
			
			if (imageDataSampleBuffer)
			{
				NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
				UIImage *image = [[UIImage alloc] initWithData:imageData];
                
                NSLog(@"gotcha %p", image);
                
//                [delegate didTakePicture:image];
                
				[[[ALAssetsLibrary alloc] init] writeImageToSavedPhotosAlbum:[image CGImage] orientation:(ALAssetOrientation)[image imageOrientation] completionBlock:nil];
			}
		}];
//	});
}

#pragma mark - Private

-(AVCaptureDevice*) oppositeDeviceFrom:(AVCaptureDevice*)currentDevice{
    AVCaptureDevicePosition preferredPosition = AVCaptureDevicePositionBack;
    switch (currentDevice.position)
    {
        case AVCaptureDevicePositionUnspecified:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
        case AVCaptureDevicePositionBack:
            preferredPosition = AVCaptureDevicePositionFront;
            break;
        case AVCaptureDevicePositionFront:
            preferredPosition = AVCaptureDevicePositionBack;
            break;
    }
    
    return [CaptureSessionManager deviceWithMediaType:AVMediaTypeVideo preferringPosition:preferredPosition];
}

+ (AVCaptureDevice *)deviceWithMediaType:(NSString *)mediaType preferringPosition:(AVCaptureDevicePosition)position
{
	NSArray *devices = [AVCaptureDevice devicesWithMediaType:mediaType];
	AVCaptureDevice *captureDevice = [devices firstObject];
	
	for (AVCaptureDevice *device in devices)
	{
		if ([device position] == position)
		{
			captureDevice = device;
			break;
		}
	}
	
	return captureDevice;
}

+ (void)setFlashMode:(AVCaptureFlashMode)flashMode forDevice:(AVCaptureDevice *)device
{
	if ([device hasFlash] && [device isFlashModeSupported:flashMode])
	{
		NSError *error = nil;
		if ([device lockForConfiguration:&error])
		{
			[device setFlashMode:flashMode];
			[device unlockForConfiguration];
		}
		else
		{
			NSLog(@"%@", error);
		}
	}
}

- (void)addVideoInput {
	AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];	
	if (videoDevice) {
		NSError *error;
		AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		if (!error) {
			if ([[self captureSession] canAddInput:videoIn]){
				[[self captureSession] addInput:videoIn];
                currDevice = videoDevice;
            }
			else
				NSLog(@"Couldn't add video input");		
		}
		else
			NSLog(@"Couldn't create video input");
	}
	else
		NSLog(@"Couldn't create video capture device");
}

- (void)dealloc {
	[[self captureSession] stopRunning];
}

@end