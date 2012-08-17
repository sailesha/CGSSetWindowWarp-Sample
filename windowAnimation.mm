// This app demonstrates how to use CGSSetWindowWarp,
// CGSSetWindowAlpha, CGSSetWindowTransform to implement
// a custom sheet animation.

#import <Cocoa/Cocoa.h>

extern "C" {
typedef int CGSWindow;
typedef int CGSConnection;

extern CGSConnection _CGSDefaultConnection();

extern CGError CGSSetWindowTransform(
    const CGSConnection cid,
    const CGSWindow wid,
    CGAffineTransform transform); 

typedef struct {
  float x;
  float y;
} MeshPoint;

typedef struct {
    MeshPoint local;
    MeshPoint global;
} CGPointWarp;

extern CGError CGSSetWindowWarp(
    const CGSConnection cid,
    const CGSWindow wid,
    int w,
    int h,
    CGPointWarp* mesh);

extern CGError CGSSetWindowAlpha(
    const CGSConnection cid,
    const CGSWindow wid,
    float alpha);
}

NSPoint GetWindowScreenOrigin(NSWindow* window) {
  NSRect window_frame = [window frame];
  NSRect screen_frame = [[window screen] frame];
  return NSMakePoint(NSMinX(window_frame),
                     NSHeight(screen_frame) - NSMaxY(window_frame));
}

void SetWindowAlpha(NSWindow* window, float alpha) {
  CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowAlpha(cid, [window windowNumber], alpha);
}

void SetWindowScale(NSWindow* window, float scale) {
  CGAffineTransform transform = CGAffineTransformIdentity;

  CGFloat scale_delta = 1.0 - scale;
  CGFloat cur_scale = 1.0 + scale_delta;
  transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(cur_scale, cur_scale));

  NSSize window_size = [window frame].size;
  CGFloat scale_offset_x = window_size.width * (1 - cur_scale) / 2.0;
  CGFloat scale_offset_y = window_size.height * (1 - cur_scale) / 2.0;

  NSPoint origin = GetWindowScreenOrigin(window);
  CGFloat new_x = -origin.x + scale_offset_x;
  CGFloat new_y = -origin.y + scale_offset_y;
  transform = CGAffineTransformTranslate(transform, new_x, new_y);

	CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowTransform(cid, [window windowNumber], transform);
}

void ClearWindowWarp(NSWindow* window) {
	CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowWarp(cid, [window windowNumber], 0, 0, NULL);
}

void SetWindowWarp(NSWindow* window, float y_offset, float scale, float perspective_offset) {
  const int W = 2;
  const int H = 2;

  NSPoint origin = GetWindowScreenOrigin(window);
  CGFloat x = origin.x;
  CGFloat y = origin.y - y_offset;
  CGFloat width = [window frame].size.width;
  CGFloat height = [window frame].size.height;
  CGFloat dst_width = width * scale;
  CGFloat dst_height = height * scale;

  CGFloat delta_x = (width - dst_width) / 2.0;
  CGFloat delta_y = (height - dst_height) / 2.0;
  x += delta_x;
  y += delta_y;

  CGFloat px1 = perspective_offset;
  CGFloat px2 = perspective_offset;

	CGPointWarp mesh[H][W] = {
		{ {{0,  0},   {0 + x + px1,  0 + y}  },     {{width,  0},    {dst_width+ x - px1,  0 + y}}    },
		{ {{0,height},{0 + x - px2,dst_height+ y}}, {{width,height}, {dst_width+ x + px2, dst_height + y}} },
	};

	CGSConnection cid = _CGSDefaultConnection();
  CGSSetWindowWarp(cid, [window windowNumber], W, H, &(mesh[0][0]));
}

@interface WindowAnimation : NSAnimation {
 @private
  NSWindow* window_;
}
@property(nonatomic,retain) NSWindow* window;
@end
@implementation WindowAnimation

@synthesize window = window_;

- (void)setCurrentProgress:(NSAnimationProgress)progress {
  [super setCurrentProgress:progress];

  if (progress >= 1.0) {
    ClearWindowWarp(window_);
    return;
  }

  float value = [self currentValue];
  float inverse_value = 1.0 - value;

  SetWindowAlpha(window_, value);
  CGFloat y_offset = 20 * inverse_value;
  CGFloat scale = 1.0 - 0.01 * inverse_value;
  CGFloat perspective_offset = ([window_ frame].size.width * 0.04) * inverse_value;

  SetWindowWarp(window_, y_offset, scale, perspective_offset);
}

@end

@interface WindowShakeAnimation : NSAnimation {
 @private
  NSWindow* window_;
}
@property(nonatomic,retain) NSWindow* window;
@end
@implementation WindowShakeAnimation

@synthesize window = window_;

- (void)setCurrentProgress:(NSAnimationProgress)progress {
  [super setCurrentProgress:progress];
  float value = [self currentValue];

  struct KeyFrame {
    float progress;
    float scale;
  };
  KeyFrame frames[] = {
    {0.00, 1.0},
    {0.40, 1.02},
    {0.60, 1.02},
    {1.00, 1.0},
  };

  CGFloat scale = 1;
  for (int i = 0; i < 3; ++i) {
    if (value >= frames[i].progress) {
      CGFloat keyframe_length = frames[i+1].progress - frames[i].progress;
      CGFloat keyframe_percent = (value - frames[i].progress) / keyframe_length;
      CGFloat scale_length = frames[i+1].scale - frames[i].scale;
      scale = frames[i].scale + scale_length * keyframe_percent;
    }
  }

  SetWindowScale(window_, scale);
}

@end

int main() {
  NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
  [NSApplication sharedApplication];

  NSRect rect = NSMakeRect(0, 0, 500, 175);
  NSWindow* window = [[NSWindow alloc]
                       initWithContentRect:rect
                       styleMask:NSBorderlessWindowMask
                       backing:NSBackingStoreBuffered
                       defer:NO];
  [window setOpaque:YES];
  [window setHasShadow:YES];

  [window center];
  SetWindowAlpha(window, 0);
  [window makeKeyAndOrderFront:nil];

  WindowAnimation* animation = [[WindowAnimation alloc]
      initWithDuration:0.18
      animationCurve:NSAnimationEaseInOut];
  [animation setWindow:window];
  [animation startAnimation];

  WindowShakeAnimation* shake_animation = [[WindowShakeAnimation alloc]
      initWithDuration:0.18
      animationCurve:NSAnimationEaseInOut];
  [shake_animation setWindow:window];
  [shake_animation performSelector:@selector(startAnimation) withObject:nil afterDelay:1.5];
  [shake_animation performSelector:@selector(startAnimation) withObject:nil afterDelay:3.0];

  [[NSRunLoop currentRunLoop] run];

  [pool drain];
}
