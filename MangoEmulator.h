//
//  MangoEmulator.h
//  Mango
//
//  Created by Jarrod Norwell on 4/8/2025.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, SNESRomType) {
    SNESRomTypePAL = 0,
    SNESRomTypeNTSC = 1
};

@interface MangoEmulator : NSObject
@property (nonatomic, strong, nullable) void (^fb) (uint8_t*);

+(MangoEmulator *) sharedInstance NS_SWIFT_NAME(shared());

-(void) insertCartridge:(NSURL *)url NS_SWIFT_NAME(insert(_:));

-(void) start;
-(void) stop;
-(BOOL) isPaused;
-(void) pause:(BOOL)pause;

-(SNESRomType) type;

-(NSString *) regionForCartridge:(NSURL *)url NS_SWIFT_NAME(region(from:));
-(NSString *) titleForCartridge:(NSURL *)url NS_SWIFT_NAME(title(from:));

-(void) button:(int)button player:(int)player pressed:(BOOL)pressed;
@end

NS_ASSUME_NONNULL_END
