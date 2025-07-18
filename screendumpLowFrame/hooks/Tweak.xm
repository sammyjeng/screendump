#include <errno.h>
#include <substrate.h>
#include <rfb/rfb.h>
#import <notify.h>
#import <UIKit/UIKit.h>
#import <rootless.h>

#define NSLog(args...) NSLog(@"[ScreenDump] " args)

extern "C" UIImage* _UICreateScreenUIImage();

static BOOL isEnabled;
static BOOL isBlackScreen;

@interface CapturerScreen : NSObject
- (void)start;
@end

@implementation CapturerScreen
- (id)init
{
	self = [super init];
	
	return self;
}
- (unsigned char *)pixelBRGABytesFromImageRef:(CGImageRef)imageRef
{
    
    NSUInteger iWidth = CGImageGetWidth(imageRef);
    NSUInteger iHeight = CGImageGetHeight(imageRef);
    NSUInteger iBytesPerPixel = 4;
    NSUInteger iBytesPerRow = iBytesPerPixel * iWidth;
    NSUInteger iBitsPerComponent = 8;
    unsigned char *imageBytes = (unsigned char *)malloc(iWidth * iHeight * iBytesPerPixel);
    
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef context = CGBitmapContextCreate(imageBytes,
                                                 iWidth,
                                                 iHeight,
                                                 iBitsPerComponent,
                                                 iBytesPerRow,
                                                 colorspace,
                                                 kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    
    CGRect rect = CGRectMake(0 , 0 , iWidth, iHeight);
    CGContextDrawImage(context , rect ,imageRef);
    CGColorSpaceRelease(colorspace);
    CGContextRelease(context);
    CGImageRelease(imageRef);
    
    return imageBytes;
}
- (unsigned char *)pixelBRGABytesFromImage:(UIImage *)image
{
    return [self pixelBRGABytesFromImageRef:image.CGImage];
}
- (void)start
{
	NSLog(@"Starting screen capture with 0.4s interval");
	dispatch_async(dispatch_get_main_queue(), ^(void){
		[NSTimer scheduledTimerWithTimeInterval:0.4f target:self selector:@selector(capture) userInfo:nil repeats:YES];
	});
}
- (UIImage *)imageWithImage:(UIImage *)image scaledToSize:(CGSize)newSize
{
    //UIGraphicsBeginImageContext(newSize);
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0.0f);
    [image drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();    
    UIGraphicsEndImageContext();
	[image release];
    return newImage;
}
- (void)capture
{
	@autoreleasepool {
		
		if(isBlackScreen) {
			NSLog(@"Skipping capture - screen is black");
			return;
		}
		
		if(!isEnabled) {
			NSLog(@"Skipping capture - screendump is disabled");
			return;
		}
		
		NSLog(@"Starting screen capture...");
		UIImage* image = _UICreateScreenUIImage();
		if (!image) {
			NSLog(@"Failed to create screen image");
			return;
		}
		
		CGSize newS = CGSizeMake(image.size.width, image.size.height);
		
		image = [[self imageWithImage:image scaledToSize:newS] copy];
		
		CGImageRef imageRef = image.CGImage;
		
		NSUInteger iWidth = CGImageGetWidth(imageRef);
		NSUInteger iHeight = CGImageGetHeight(imageRef);
		NSUInteger iBytesPerPixel = 4;
		
		size_t size = iWidth * iHeight * iBytesPerPixel;
		
		NSLog(@"Screen dimensions: %lux%lu, size: %zu bytes", (unsigned long)iWidth, (unsigned long)iHeight, size);
		
		unsigned char * bytes = [self pixelBRGABytesFromImageRef:imageRef];
		
		dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			@autoreleasepool {
				NSData *imageData = [NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:YES];
				BOOL success1 = [imageData writeToFile:@"/tmp/screendump_Buff.tmp" atomically:YES];
				BOOL success2 = [@{@"width":@(iWidth), @"height":@(iHeight), @"size":@(size),} writeToFile:@"/tmp/screendump_Info.tmp" atomically:YES];
				
				NSLog(@"File write success - Buffer: %@, Info: %@", success1 ? @"YES" : @"NO", success2 ? @"YES" : @"NO");
				
				notify_post("com.julioverne.screendump/frameChanged");
				NSLog(@"Posted frameChanged notification");
			}
		});
	}
}
@end

%hook SpringBoard
- (void)applicationDidFinishLaunching:(id)application
{
	%orig;
	NSLog(@"SpringBoard finished launching - initializing CapturerScreen");
	CapturerScreen* cap = [[CapturerScreen alloc] init];
	[cap start];
}
%end

%hook UIApplication
- (void)sendEvent:(UIEvent *)event
{
	%orig;
	if (event.type == UIEventTypeTouches) {
		NSSet *touches = [event allTouches];
		for (UITouch *touch in touches) {
			CGPoint location = [touch locationInView:nil];
			NSString *phase = @"Unknown";
			switch (touch.phase) {
				case UITouchPhaseBegan:
					phase = @"Began";
					break;
				case UITouchPhaseMoved:
					phase = @"Moved";
					break;
				case UITouchPhaseEnded:
					phase = @"Ended";
					break;
				case UITouchPhaseCancelled:
					phase = @"Cancelled";
					break;
				default:
					break;
			}
			NSLog(@"Touch %@ at (%.1f, %.1f)", phase, location.x, location.y);
		}
	}
}
%end


static void screenDisplayStatus(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
    uint64_t state;
    int token;
    notify_register_check("com.apple.iokit.hid.displayStatus", &token);
    notify_get_state(token, &state);
    notify_cancel(token);
    if(!state) {
		isBlackScreen = YES;
		NSLog(@"Screen status changed: BLACK");
    } else {
		isBlackScreen = NO;
		NSLog(@"Screen status changed: ON");
	}
}

static void loadPrefs(CFNotificationCenterRef center, void* observer, CFStringRef name, const void* object, CFDictionaryRef userInfo)
{
	@autoreleasepool {
		NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.cosmosgenius.screendump"];
		BOOL newEnabled = [[defaults objectForKey:@"CCSisEnabled"]?:@NO boolValue];
		if (newEnabled != isEnabled) {
			isEnabled = newEnabled;
			NSLog(@"Preferences changed: isEnabled = %@", isEnabled ? @"YES" : @"NO");
		}
	}
}

%ctor
{
	NSLog(@"ScreenDump tweak loading...");
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, screenDisplayStatus, CFSTR("com.apple.iokit.hid.displayStatus"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, loadPrefs, CFSTR("com.cosmosgenius.screendump/preferences.changed"), NULL, CFNotificationSuspensionBehaviorDeliverImmediately);
	
	loadPrefs(NULL, NULL, NULL, NULL, NULL);
	NSLog(@"ScreenDump tweak loaded - isEnabled: %@, isBlackScreen: %@", isEnabled ? @"YES" : @"NO", isBlackScreen ? @"YES" : @"NO");
}